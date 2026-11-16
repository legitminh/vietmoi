#!/bin/bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEVICE_ID="${1:?Usage: bash scripts/install-ios.sh device-id [development-team-id | --no-build]}"
TEAM_ID="${2:-}"
if [ "$TEAM_ID" != '--no-build' ]; then
  if [ -z "$TEAM_ID" ]; then echo 'Supply your development team ID to sign the device build.' >&2; exit 2; fi
  bash "$PROJECT_ROOT/scripts/build-ios.sh" device "$TEAM_ID" "$DEVICE_ID"
fi
APP="$PROJECT_ROOT/build/iOS-device/Build/Products/Debug-iphoneos/VietMobile.app"
/usr/bin/codesign --verify --deep --strict "$APP"
if [ ! -f "$APP/embedded.mobileprovision" ]; then echo 'A signed device build is required; simulator/unsigned builds cannot be installed.' >&2; exit 1; fi
xcrun devicectl device install app --device "$DEVICE_ID" "$APP"
xcrun devicectl device process launch --device "$DEVICE_ID" com.minh.sieuviet.ios
