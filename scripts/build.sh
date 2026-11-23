#!/bin/bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$PROJECT_ROOT/build"
APP="$BUILD_DIR/VietMoi.app"
python3 "$PROJECT_ROOT/scripts/generate-design.py" --check
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$BUILD_DIR/module-cache"
cp "$PROJECT_ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
cp "$PROJECT_ROOT/Resources/UnitedStatesMode.svg" "$APP/Contents/Resources/UnitedStatesMode.svg"
rm -rf "$APP/Contents/Resources/WebApp"
cp -R "$PROJECT_ROOT/Resources/WebApp" "$APP/Contents/Resources/WebApp"
ARCHITECTURES="${SIEUVIET_MAC_ARCHS:-$(uname -m)}"
BINARIES=()
for ARCHITECTURE in $ARCHITECTURES; do
  case "$ARCHITECTURE" in arm64|x86_64) ;; *) echo "Unsupported Mac architecture: $ARCHITECTURE" >&2; exit 2 ;; esac
  mkdir -p "$BUILD_DIR/macos-$ARCHITECTURE"
  BINARY="$BUILD_DIR/macos-$ARCHITECTURE/VietMoi"
xcrun swiftc -swift-version 5 -O -module-cache-path "$BUILD_DIR/module-cache" \
  -target "$ARCHITECTURE-apple-macosx13.0" -module-name VietMoi \
  -framework AppKit -framework InputMethodKit -framework Carbon -framework WebKit \
  "$PROJECT_ROOT"/Sources/Core/*.swift \
  "$PROJECT_ROOT"/Sources/Presentation/*.swift \
  "$PROJECT_ROOT"/Sources/AppShell/*.swift \
  "$PROJECT_ROOT/Sources/macOS/KeyboardPanel.swift" \
  "$PROJECT_ROOT/Sources/macOS/ASCIIKeyboardView.swift" \
  "$PROJECT_ROOT/Sources/macOS/SettingsWindow.swift" \
  "$PROJECT_ROOT/Sources/macOS/InputController.swift" \
  "$PROJECT_ROOT/Sources/macOS/main.swift" \
  -o "$BINARY"
  BINARIES+=("$BINARY")
done
xcrun lipo -create "${BINARIES[@]}" -output "$APP/Contents/MacOS/VietMoi"
xcrun swift -module-cache-path "$BUILD_DIR/module-cache" "$PROJECT_ROOT/scripts/make-icons.swift" "$PROJECT_ROOT"
xcrun iconutil -c icns "$BUILD_DIR/AppIcon.iconset" -o "$APP/Contents/Resources/AppIcon.icns"
cp "$BUILD_DIR/MenuIcon.tiff" "$APP/Contents/Resources/MenuIcon.tiff"
python3 "$PROJECT_ROOT/scripts/mac-fingerprint.py" > "$APP/Contents/Resources/BuildFingerprint.txt"
/usr/bin/plutil -lint "$APP/Contents/Info.plist"
/usr/bin/codesign --force --sign - "$APP"
echo "Built: $APP"
