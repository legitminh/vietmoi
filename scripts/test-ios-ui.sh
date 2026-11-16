#!/bin/bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SIMULATOR_ID="${1:?Usage: bash scripts/test-ios-ui.sh booted-simulator-id}"
KEYBOARD_ID='com.minh.sieuviet.ios.keyboard'
bash "$PROJECT_ROOT/scripts/build-ios.sh" simulator
xcrun simctl install "$SIMULATOR_ID" "$PROJECT_ROOT/build/iOS-simulator/Build/Products/Debug-iphonesimulator/VietMobile.app"
# Simulator-only test setup. Preserve every existing keyboard; select viet so
# recent-language cycling and iOS's first-use globe tutorial cannot hide it.
if ! xcrun simctl spawn "$SIMULATOR_ID" defaults read .GlobalPreferences AppleKeyboards | /usr/bin/grep -Fq "$KEYBOARD_ID"; then
  xcrun simctl spawn "$SIMULATOR_ID" defaults write .GlobalPreferences AppleKeyboards -array-add "$KEYBOARD_ID"
fi
xcrun simctl spawn "$SIMULATOR_ID" defaults write com.apple.keyboard.preferences KeyboardLastUsed -string "$KEYBOARD_ID"
xcrun simctl spawn "$SIMULATOR_ID" defaults write com.apple.keyboard.preferences KeyboardLastUsedForLanguage -dict-add ASCIICapable "$KEYBOARD_ID" vi "$KEYBOARD_ID"
xcrun simctl spawn "$SIMULATOR_ID" defaults write com.apple.keyboard.preferences KeyboardsCurrentAndNext -array "$KEYBOARD_ID" "$KEYBOARD_ID" 'en_US@sw=QWERTY;hw=Automatic'
xcodebuild -project "$PROJECT_ROOT/iOS/VietMobile.xcodeproj" -scheme VietMobile -configuration Debug \
  -destination "platform=iOS Simulator,id=$SIMULATOR_ID" -derivedDataPath "$PROJECT_ROOT/build/iOS-simulator" \
  -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test
