#!/bin/bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$PROJECT_ROOT/build/module-cache"
xcrun swiftc -swift-version 5 -O -module-cache-path "$PROJECT_ROOT/build/module-cache" \
  "$PROJECT_ROOT/Sources/Core/KeyboardEngine.swift" \
  "$PROJECT_ROOT/Sources/Core/StandardVietnamese.swift" \
  "$PROJECT_ROOT/Sources/Core/KeyboardProfiles.swift" \
  "$PROJECT_ROOT/Sources/Core/ASCIIKeyboardLayout.swift" \
  "$PROJECT_ROOT/Sources/Core/ASCIIPlusMapping.swift" \
  "$PROJECT_ROOT/Tests/ASCIIPlus/main.swift" -o "$PROJECT_ROOT/build/ascii-plus-tests"
"$PROJECT_ROOT/build/ascii-plus-tests"
