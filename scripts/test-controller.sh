#!/bin/bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$PROJECT_ROOT/build/module-cache"
xcrun swiftc -swift-version 5 -module-cache-path "$PROJECT_ROOT/build/module-cache" \
  -framework AppKit -framework InputMethodKit -framework Carbon \
  "$PROJECT_ROOT/Sources/Core/KeyboardEngine.swift" \
  "$PROJECT_ROOT/Sources/Core/StandardVietnamese.swift" \
  "$PROJECT_ROOT/Sources/Core/KeyboardProfiles.swift" \
  "$PROJECT_ROOT/Sources/Core/KeyboardPreferences.swift" \
  "$PROJECT_ROOT/Sources/Core/ASCIIKeyboardLayout.swift" \
  "$PROJECT_ROOT/Sources/Core/ASCIIPlusMapping.swift" \
  "$PROJECT_ROOT/Sources/macOS/KeyboardPanel.swift" \
  "$PROJECT_ROOT/Sources/macOS/ASCIIKeyboardView.swift" \
  "$PROJECT_ROOT/Sources/macOS/SettingsWindow.swift" \
  "$PROJECT_ROOT/Sources/macOS/InputController.swift" \
  "$PROJECT_ROOT/Tests/Controller/main.swift" -o "$PROJECT_ROOT/build/controller-tests"
"$PROJECT_ROOT/build/controller-tests"
