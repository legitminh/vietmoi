#!/bin/bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
python3 "$PROJECT_ROOT/scripts/generate-design.py" --check
mkdir -p "$PROJECT_ROOT/build/module-cache"
xcrun swift -module-cache-path "$PROJECT_ROOT/build/module-cache" "$PROJECT_ROOT/scripts/make-icons.swift" "$PROJECT_ROOT"
PLATFORM="${1:-simulator}"
TEAM_ID="${2:-}"
DEVICE_ID="${3:-}"
ARGS=(-project "$PROJECT_ROOT/iOS/VietMobile.xcodeproj" -scheme VietMobile -configuration Debug)
case "$PLATFORM" in
  simulator)
    ARGS+=(-sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath "$PROJECT_ROOT/build/iOS-simulator" CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=-) ;;
  device)
    ARGS+=(-sdk iphoneos -destination "${DEVICE_ID:+id=}${DEVICE_ID:-generic/platform=iOS}" -derivedDataPath "$PROJECT_ROOT/build/iOS-device")
    if [ -n "$TEAM_ID" ]; then ARGS+=(-allowProvisioningUpdates -allowProvisioningDeviceRegistration "DEVELOPMENT_TEAM=$TEAM_ID"); else ARGS+=(CODE_SIGNING_ALLOWED=NO); fi ;;
  *) echo 'Usage: bash scripts/build-ios.sh [simulator|device] [development-team-id] [device-id]' >&2; exit 2 ;;
esac
xcodebuild "${ARGS[@]}" build
