#!/bin/bash
# Linux build/engine checks; this does not test an IBus/Fcitx desktop session.
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SWIFT_VERSION="$(cat "$PROJECT_ROOT/.swift-version")"
DOCKER_COMMAND=(docker)
if [[ -n "${SIEUVIET_DOCKER_CONTEXT:-}" ]]; then
  DOCKER_COMMAND+=(--context "$SIEUVIET_DOCKER_CONTEXT")
fi
mkdir -p "$PROJECT_ROOT/build/linux"
# Sources are read-only; only generated build outputs are writable. The disposable
# test container has no network access. A missing image is downloaded by Docker.
"${DOCKER_COMMAND[@]}" run --rm --network none --read-only \
  --tmpfs /tmp --tmpfs /root \
  --mount "type=bind,source=$PROJECT_ROOT,target=/workspace,readonly" \
  --mount "type=bind,source=$PROJECT_ROOT/build/linux,target=/workspace/build" \
  --workdir /workspace "swift:$SWIFT_VERSION" \
  sh -ec 'python3 scripts/test-portable.py
python3 scripts/test-package.py'
"${DOCKER_COMMAND[@]}" image inspect "swift:$SWIFT_VERSION" --format '{{index .RepoDigests 0}}'
