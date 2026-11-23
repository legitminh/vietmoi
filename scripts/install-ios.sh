#!/bin/bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
message() { python3 "$PROJECT_ROOT/scripts/message.py" "$@"; }
if [ -z "${1:-}" ]; then message installIOSUsage >&2; exit 2; fi
DEVICE_ID="$1"
TEAM_ID="${2:-}"
if [ "$TEAM_ID" != '--no-build' ]; then
  if [ -z "$TEAM_ID" ]; then message installIOSTeam >&2; exit 2; fi
  bash "$PROJECT_ROOT/scripts/build-ios.sh" device "$TEAM_ID" "$DEVICE_ID"
fi
APP="$PROJECT_ROOT/build/iOS-device/Build/Products/Debug-iphoneos/VietMobile.app"
/usr/bin/codesign --verify --deep --strict "$APP"
if [ ! -f "$APP/embedded.mobileprovision" ]; then message installIOSUnsigned >&2; exit 1; fi
xcrun devicectl device install app --device "$DEVICE_ID" "$APP"
xcrun devicectl device process launch --device "$DEVICE_ID" com.minh.sieuviet.ios
