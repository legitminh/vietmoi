#!/bin/bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$PROJECT_ROOT/build/module-cache"
xcrun swiftc -swift-version 5 -parse-as-library -module-cache-path "$PROJECT_ROOT/build/module-cache" \
  "$PROJECT_ROOT"/Sources/Core/*.swift \
  "$PROJECT_ROOT/Sources/Mobile/MobileSettingsStore.swift" \
  "$PROJECT_ROOT/Sources/Mobile/MobileKeyboardSettings.swift" \
  "$PROJECT_ROOT/Sources/Mobile/MobileModifierState.swift" \
  "$PROJECT_ROOT/Sources/Mobile/MobileInputSession.swift" \
  "$PROJECT_ROOT/Tests/Mobile/main.swift" -o "$PROJECT_ROOT/build/mobile-tests"
"$PROJECT_ROOT/build/mobile-tests"
