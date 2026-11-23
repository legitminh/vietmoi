#!/bin/bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$PROJECT_ROOT/build/module-cache"
xcrun swiftc -swift-version 5 -module-cache-path "$PROJECT_ROOT/build/module-cache" \
  -framework AppKit -framework InputMethodKit -framework Carbon \
  "$PROJECT_ROOT"/Sources/Core/*.swift \
  "$PROJECT_ROOT"/Sources/Presentation/*.swift \
  "$PROJECT_ROOT/Sources/macOS/KeyboardPanel.swift" \
  "$PROJECT_ROOT/Sources/macOS/ASCIIKeyboardView.swift" \
  "$PROJECT_ROOT/Sources/macOS/SettingsWindow.swift" \
  "$PROJECT_ROOT/Sources/macOS/InputController.swift" \
  "$PROJECT_ROOT/Tests/Controller/main.swift" -o "$PROJECT_ROOT/build/controller-tests"
"$PROJECT_ROOT/build/controller-tests" "$PROJECT_ROOT/Resources/Chinese/pinyin_simp.dict.yaml"
