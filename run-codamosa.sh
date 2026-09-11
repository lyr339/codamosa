#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 lyr339
# SPDX-License-Identifier: MIT

set -euo pipefail

SCRIPT_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ $# -lt 2 || $# -gt 3 ]]; then
  echo "Usage: $0 TARGET_PROJECT MODULE_NAME [OUTPUT_DIRECTORY]" >&2
  exit 2
fi

TARGET_PROJECT="$(cd "$1" && pwd)"
MODULE_NAME="$2"
OUTPUT_DIRECTORY="${3:-$HOME/Downloads/codamosa-output/${MODULE_NAME//./_}-$(date +%Y%m%d-%H%M%S)}"
API_BASE_URL="${CODAMOSA_API_BASE_URL:-https://whh985.xyz}"
API_BASE_URL="${API_BASE_URL%/}"
if [[ -n "${CODAMOSA_API_PATH:-}" ]]; then
  API_RELATIVE_URL="$CODAMOSA_API_PATH"
elif [[ "$API_BASE_URL" == */v1 ]]; then
  API_RELATIVE_URL="/responses"
else
  API_RELATIVE_URL="/v1/responses"
fi
MODEL_NAME="${CODAMOSA_MODEL:-gpt-5.6-sol}"
MAX_SEARCH_TIME="${CODAMOSA_MAX_SEARCH_TIME:-120}"

# Prefer an explicitly supplied environment variable.  When it is absent, the
# script accepts the key copied from the API management page without persisting it.
if [[ -z "${CODAMOSA_API_KEY:-}" ]]; then
  CODAMOSA_API_KEY="$(pbpaste 2>/dev/null || true)"
fi
if [[ "$CODAMOSA_API_KEY" != sk-* ]]; then
  echo "Copy the API key first or export CODAMOSA_API_KEY." >&2
  exit 2
fi
export CODAMOSA_API_KEY

mkdir -p "$OUTPUT_DIRECTORY"
OUTPUT_DIRECTORY="$(cd "$OUTPUT_DIRECTORY" && pwd)"
PACKAGE_DIRECTORY="$(mktemp -d)"
trap 'find "$PACKAGE_DIRECTORY" -type f -delete; rmdir "$PACKAGE_DIRECTORY" 2>/dev/null || true' EXIT
if [[ -f "$TARGET_PROJECT/package.txt" ]]; then
  cp "$TARGET_PROJECT/package.txt" "$PACKAGE_DIRECTORY/package.txt"
elif [[ -f "$TARGET_PROJECT/requirements.txt" ]]; then
  cp "$TARGET_PROJECT/requirements.txt" "$PACKAGE_DIRECTORY/package.txt"
else
  : > "$PACKAGE_DIRECTORY/package.txt"
fi

if ! docker info >/dev/null 2>&1; then
  echo "Start Docker Engine or Docker Desktop, then run this command again." >&2
  exit 1
fi

if ! docker image inspect codamosa-runner:latest >/dev/null 2>&1; then
  docker build \
    -t codamosa-runner \
    -f "$SCRIPT_DIRECTORY/docker/Dockerfile" \
    "$SCRIPT_DIRECTORY"
fi

docker run --rm \
  -e CODAMOSA_API_KEY \
  -v "$TARGET_PROJECT":/input:ro \
  -v "$OUTPUT_DIRECTORY":/output \
  -v "$PACKAGE_DIRECTORY":/package:ro \
  codamosa-runner \
  --project-path /input \
  --module-name "$MODULE_NAME" \
  --output-path /output \
  --report-dir /output \
  --maximum-search-time "$MAX_SEARCH_TIME" \
  --algorithm CODAMOSA \
  --assertion-generation NONE \
  --model-name "$MODEL_NAME" \
  --model-base-url "$API_BASE_URL" \
  --model-relative-url "$API_RELATIVE_URL" \
  --max-plateau-len 5 \
  --num-seeds-to-inject 1 \
  --include-partially-parsable True \
  --allow-expandable-cluster True \
  --uninterpreted-statements ONLY \
  -v

echo "Generated files: $OUTPUT_DIRECTORY"
