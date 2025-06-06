#!/bin/bash
set -eo pipefail

if [ $# -eq 0 ]; then
  echo "[ERROR] No filename provided. Usage: $0 <filename>"
  exit 1
fi

FILENAME="$1"
echo "[INFO] Validating artifact: $FILENAME" >&2

handle_error() {
  echo "[FAIL] $1"
  exit 1
}

echo "[INFO] Downloading artifact..."
buildkite-agent artifact download "**/$FILENAME" . || handle_error "No artifact found matching $FILENAME"

FOUND_FILES=$(find . -name "$FILENAME")

if [ -z "$FOUND_FILES" ]; then
  handle_error "Could not find $FILENAME after downloading" >&2
fi

for FILE in $FOUND_FILES; do
  echo "[INFO] Output for $FILE below:"
  cat "$FILE" || handle_error "Could not read $FILE"
done

echo "" >&2 # Adding empty line to line break from cat output

echo "[SUCCESS] Artifact '$FILENAME' found and validated" >&2
exit 0