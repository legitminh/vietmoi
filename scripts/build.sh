#!/bin/bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$PROJECT_ROOT/build"
APP="$BUILD_DIR/VietMoi.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$BUILD_DIR/module-cache"
cp "$PROJECT_ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
cp "$PROJECT_ROOT/Resources/UnitedStatesMode.svg" "$APP/Contents/Resources/UnitedStatesMode.svg"
xcrun swiftc -swift-version 5 -O -module-cache-path "$BUILD_DIR/module-cache" \
  -target "$(uname -m)-apple-macosx13.0" -module-name VietMoi \
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
  "$PROJECT_ROOT/Sources/macOS/main.swift" \
  -o "$APP/Contents/MacOS/VietMoi"
xcrun swift -module-cache-path "$BUILD_DIR/module-cache" "$PROJECT_ROOT/scripts/make-icon.swift" "$APP/Contents/Resources/MenuIcon.tiff"
/usr/bin/plutil -lint "$APP/Contents/Info.plist"
/usr/bin/codesign --force --sign - "$APP"
echo "Built: $APP"
