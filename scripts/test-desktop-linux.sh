#!/bin/bash
# Actual Linux keyboard adapters and GTK/Qt hosts, isolated from your desktop.
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DOCKER_COMMAND=(docker)
if [[ -n "${SIEUVIET_DOCKER_CONTEXT:-}" ]]; then DOCKER_COMMAND+=(--context "$SIEUVIET_DOCKER_CONTEXT"); fi
case "$(uname -m)" in arm64|aarch64) DEFAULT_PLATFORM=linux/arm64 ;; *) DEFAULT_PLATFORM=linux/amd64 ;; esac
PLATFORM="${SIEUVIET_LINUX_PLATFORM:-$DEFAULT_PLATFORM}"
ARCHITECTURE="${PLATFORM##*/}"
IMAGE="sieuviet-linux-dev:$(cat "$PROJECT_ROOT/.swift-version")-$ARCHITECTURE"
OUTPUT="$PROJECT_ROOT/build/linux-desktop-$ARCHITECTURE"
mkdir -p "$OUTPUT"
"${DOCKER_COMMAND[@]}" build --platform "$PLATFORM" -t "$IMAGE" -f "$PROJECT_ROOT/Desktop/linux/Dockerfile" "$PROJECT_ROOT"
"${DOCKER_COMMAND[@]}" run --rm --platform "$PLATFORM" --network none \
  --mount "type=bind,source=$PROJECT_ROOT,target=/workspace,readonly" \
  --mount "type=bind,source=$OUTPUT,target=/workspace/build" \
  "$IMAGE" sh -ec 'python3 scripts/build-linux.py
python3 scripts/test-package.py --configuration release
python3 scripts/test-linux-desktop.py
python3 scripts/test-linux-settings.py'
