#!/bin/bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$PROJECT_ROOT/build/module-cache"
xcrun swiftc -swift-version 5 -module-cache-path "$PROJECT_ROOT/build/module-cache" \
  "$PROJECT_ROOT/Sources/Core/KeyboardPreferences.swift" \
  "$PROJECT_ROOT/Tests/Shift/main.swift" -o "$PROJECT_ROOT/build/shift-tests"
"$PROJECT_ROOT/build/shift-tests"
