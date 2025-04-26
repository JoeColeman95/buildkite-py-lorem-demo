#!/bin/bash
set -eo pipefail

# Get the build type selection from the block step, defaulting to "push"
BUILD_TYPE=$(buildkite-agent meta-data get "build-type" 2>/dev/null || echo "push")
echo "[INFO] Selected build type: ${BUILD_TYPE}"

# Skip everything if the user selected "skip"
if [[ "${BUILD_TYPE}" == "skip" ]]; then
  echo "[INFO] Skipping Docker operations as requested"
  exit 0
fi

IMAGE_NAME="${1:-hello-world}"
REGISTRY="${2:-packages.buildkite.com/no-org-2/challengebuild}"
DOCKERFILE_PATH="${3:-.buildkite/assets/docker/Dockerfile}"

echo "=========================================="
echo "Docker Build and Push Script (${BUILD_TYPE} mode)"
echo "=========================================="

# Find repository root (directory containing .buildkite)
# Limited to 5 directories up from the script location
find_repo_root() {
  local current_dir="$1"
  local depth=0
  local max_depth=5

  while [[ "$current_dir" != "/" && $depth -lt $max_depth ]]; do
    if [[ -d "$current_dir/.buildkite" ]]; then
      echo "$current_dir"
      return 0
    fi
    current_dir="$(dirname "$current_dir")"
    ((depth++))
  done

  echo "[ERROR] Could not find repository root within $max_depth directories up" >&2
  return 1
}

# Find repository root and change to it
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
REPO_ROOT=$(find_repo_root "$SCRIPT_DIR") || { echo "[ERROR] Failed to locate repository root"; exit 1; }
cd "$REPO_ROOT" || { echo "[ERROR] Failed to change to repository root"; exit 1; }
echo "[INFO] Running from repository root: $(pwd)"

# Resolve Dockerfile path relative to repository root
FULL_DOCKERFILE_PATH="${REPO_ROOT}/${DOCKERFILE_PATH}"
echo "[INFO] Looking for Dockerfile at ${FULL_DOCKERFILE_PATH}"

if [[ ! -f "${FULL_DOCKERFILE_PATH}" ]]; then
  echo "[ERROR] Dockerfile not found at ${FULL_DOCKERFILE_PATH}"
  exit 1
fi

# Build the Docker image (happens for both "build" and "push" options)
echo "[INFO] Building Docker image..."
docker build -t "${IMAGE_NAME}" -f "${FULL_DOCKERFILE_PATH}" "$(dirname "${FULL_DOCKERFILE_PATH}")" || { echo "[ERROR] Docker build failed"; exit 1; }
echo "[INFO] Docker image built successfully"

# Only tag and push if we're in "push" mode
if [[ "${BUILD_TYPE}" == "push" ]]; then
  # Get version bump type for pushing
  VERSION_BUMP=$(buildkite-agent meta-data get "version-bump" 2>/dev/null || echo "minor")
  echo "[INFO] Version bump type: ${VERSION_BUMP}"

  # Authenticate with registry
  if [[ -z "${BUILDKITE_CHALLENGEBUILD_REGISTRY_TOKEN}" ]]; then
    echo "[ERROR] Missing required environment variable: BUILDKITE_CHALLENGEBUILD_REGISTRY_TOKEN"
    exit 1
  fi

  echo "[INFO] Authenticating with Docker registry..."
  echo "${BUILDKITE_CHALLENGEBUILD_REGISTRY_TOKEN}" | docker login packages.buildkite.com/no-org-2/challengebuild -u buildkite --password-stdin || { echo "[ERROR] Docker login failed"; exit 1; }
  echo "[INFO] Authentication successful"

  # Query registry for existing versions
  echo "[INFO] Checking for existing versions in registry..."
  # Convert registry URL to API endpoint
  API_ENDPOINT="https://$(echo $REGISTRY | cut -d/ -f1)/v2/$(echo $REGISTRY | cut -d/ -f2-)"

  VERSIONS=$(curl -s -H "Authorization: Bearer ${BUILDKITE_CHALLENGEBUILD_REGISTRY_TOKEN}" \
    "${API_ENDPOINT}/${IMAGE_NAME}/tags/list" | \
    jq -r '.tags[]' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' || echo "")

  if [[ -z "$VERSIONS" ]]; then
    # No existing versions, start at 1.0.0
    NEW_VERSION="1.0.0"
    echo "[INFO] No existing versions found. Starting with ${NEW_VERSION}"
  else
    # Get latest version
    LATEST_VERSION=$(echo "$VERSIONS" | sort -t. -k1,1n -k2,2n -k3,3n | tail -n1)

    # Split into major.minor.patch
    MAJOR=$(echo $LATEST_VERSION | cut -d. -f1)
    MINOR=$(echo $LATEST_VERSION | cut -d. -f2)
    PATCH=$(echo $LATEST_VERSION | cut -d. -f3)

    # Apply version bump based on selection
    case "${VERSION_BUMP}" in
      "major")
        NEW_MAJOR=$((MAJOR + 1))
        NEW_VERSION="${NEW_MAJOR}.0.0"
        ;;
      "minor")
        NEW_MINOR=$((MINOR + 1))
        NEW_VERSION="${MAJOR}.${NEW_MINOR}.0"
        ;;
      "patch")
        NEW_PATCH=$((PATCH + 1))
        NEW_VERSION="${MAJOR}.${MINOR}.${NEW_PATCH}"
        ;;
      *)
        echo "[WARN] Unknown version bump type '${VERSION_BUMP}', defaulting to minor"
        NEW_MINOR=$((MINOR + 1))
        NEW_VERSION="${MAJOR}.${NEW_MINOR}.0"
        ;;
    esac

    echo "[INFO] Found latest version ${LATEST_VERSION}, ${VERSION_BUMP} bump to ${NEW_VERSION}"
  fi

  # Tag with new version
  VERSION_TAGGED_IMAGE="${REGISTRY}/${IMAGE_NAME}:${NEW_VERSION}"
  docker tag "${IMAGE_NAME}" "${VERSION_TAGGED_IMAGE}" || { echo "[ERROR] Failed to tag versioned image"; exit 1; }
  echo "[INFO] Image tagged as ${VERSION_TAGGED_IMAGE}"

  # Also tag as latest
  LATEST_TAGGED_IMAGE="${REGISTRY}/${IMAGE_NAME}:latest"
  docker tag "${IMAGE_NAME}" "${LATEST_TAGGED_IMAGE}" || { echo "[ERROR] Failed to tag latest image"; exit 1; }
  echo "[INFO] Image tagged as ${LATEST_TAGGED_IMAGE}"

  # Push both tags
  echo "[INFO] Pushing versioned image to registry..."
  docker push "${VERSION_TAGGED_IMAGE}" || { echo "[ERROR] Failed to push versioned image"; exit 1; }
  echo "[INFO] Pushing latest image to registry..."
  docker push "${LATEST_TAGGED_IMAGE}" || { echo "[ERROR] Failed to push latest image"; exit 1; }
  echo "[SUCCESS] Image pushed successfully"
else
  echo "[INFO] Skipping image push as only 'build' was selected..."
fi

exit 0