#!/bin/bash
set -eo pipefail

IMAGE_NAME="${1:-hello-world}"
REGISTRY="${2:-packages.buildkite.com/no-org-2/challengebuild}"
DOCKERFILE_PATH="${3:-.buildkite/assets/docker/Dockerfile}"

echo "=========================================="
echo "Docker Build and Push Script"
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

if [[ -z "${BUILDKITE_CHALLENGEBUILD_REGISTRY_TOKEN}" ]]; then
  echo "[ERROR] Missing required environment variable: BUILDKITE_CHALLENGEBUILD_REGISTRY_TOKEN"
  exit 1
fi

echo "[INFO] Authenticating with Docker registry..."
echo "${BUILDKITE_CHALLENGEBUILD_REGISTRY_TOKEN}" | docker login packages.buildkite.com/no-org-2/challengebuild -u buildkite --password-stdin || { echo "[ERROR] Docker login failed"; exit 1; }
echo "[INFO] Authentication successful"

# Resolve Dockerfile path relative to repository root
FULL_DOCKERFILE_PATH="${REPO_ROOT}/${DOCKERFILE_PATH}"
echo "[INFO] Looking for Dockerfile at ${FULL_DOCKERFILE_PATH}"

if [[ ! -f "${FULL_DOCKERFILE_PATH}" ]]; then
  echo "[ERROR] Dockerfile not found at ${FULL_DOCKERFILE_PATH}"
  exit 1
fi

# Build the Docker image
echo "[INFO] Building Docker image..."
docker build -t "${IMAGE_NAME}" -f "${FULL_DOCKERFILE_PATH}" "$(dirname "${FULL_DOCKERFILE_PATH}")" || { echo "[ERROR] Docker build failed"; exit 1; }
echo "[INFO] Docker image built successfully"

# Tag the image for the registry
echo "[INFO] Tagging image for registry..."
TAGGED_IMAGE="${REGISTRY}/${IMAGE_NAME}"
docker tag "${IMAGE_NAME}" "${TAGGED_IMAGE}" || { echo "[ERROR] Failed to tag image"; exit 1; }
echo "[INFO] Image tagged as ${TAGGED_IMAGE}"

# Push the image to the registry
echo "[INFO] Pushing image to registry..."
docker push "${TAGGED_IMAGE}" || { echo "[ERROR] Failed to push image to registry"; exit 1; }
echo "[SUCCESS] Image pushed successfully to ${TAGGED_IMAGE}"

exit 0