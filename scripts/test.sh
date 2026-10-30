#!/bin/bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$PROJECT_ROOT/build/module-cache"
xcrun swiftc -swift-version 5 -module-cache-path "$PROJECT_ROOT/build/module-cache" \
  "$PROJECT_ROOT/Sources/Core/KeyboardEngine.swift" \
  "$PROJECT_ROOT/Sources/Core/KeyboardProfiles.swift" \
  "$PROJECT_ROOT/Sources/Core/StandardVietnamese.swift" \
  "$PROJECT_ROOT/Tests/main.swift" \
  -o "$PROJECT_ROOT/build/engine-tests"
"$PROJECT_ROOT/build/engine-tests"
