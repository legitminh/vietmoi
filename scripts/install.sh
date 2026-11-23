#!/bin/bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
message() { python3 "$PROJECT_ROOT/scripts/message.py" "$@"; }
if [ "${1:-}" != "--no-build" ]; then bash "$PROJECT_ROOT/scripts/build.sh"; fi
SOURCE="$PROJECT_ROOT/build/VietMoi.app"
DESTINATION="$HOME/Library/Input Methods/VietMoi.app"
if [ ! -x "$SOURCE/Contents/MacOS/VietMoi" ]; then message installBuildFirst >&2; exit 1; fi
EXPECTED="$(python3 "$PROJECT_ROOT/scripts/mac-fingerprint.py")"
if [ ! -f "$SOURCE/Contents/Resources/BuildFingerprint.txt" ] || [ "$(cat "$SOURCE/Contents/Resources/BuildFingerprint.txt")" != "$EXPECTED" ]; then
  message installStale >&2
  exit 1
fi
mkdir -p "$PROJECT_ROOT/build/module-cache"
xcrun swiftc -module-cache-path "$PROJECT_ROOT/build/module-cache" -framework Carbon \
  "$PROJECT_ROOT/scripts/input-source.swift" -o "$PROJECT_ROOT/build/input-source"
WAS_ACTIVE=false
if "$PROJECT_ROOT/build/input-source" current | /usr/bin/grep -Fq "Current input source: com.minh.inputmethod.VietMoi"; then
  WAS_ACTIVE=true
fi
mkdir -p "$HOME/Library/Input Methods"
STAGING_ROOT="$(mktemp -d "$HOME/Library/Input Methods/.VietMoi-install.XXXXXX")"
trap 'rm -rf "$STAGING_ROOT"' EXIT
/usr/bin/ditto "$SOURCE" "$STAGING_ROOT/VietMoi.app"
/usr/bin/codesign --verify --strict "$STAGING_ROOT/VietMoi.app"
# Disconnect the old process before replacing it; macOS may otherwise retain a stale session.
"$PROJECT_ROOT/build/input-source" prepare-update > /dev/null
mkdir -p "$HOME/Library/Input Methods"
# Stop only this input method during an update; never restart system services.
/usr/bin/pkill -x VietMoi 2>/dev/null || true
if [ -e "$DESTINATION" ]; then mv "$DESTINATION" "$STAGING_ROOT/previous.app"; fi
if ! mv "$STAGING_ROOT/VietMoi.app" "$DESTINATION"; then
  if [ -e "$STAGING_ROOT/previous.app" ]; then mv "$STAGING_ROOT/previous.app" "$DESTINATION"; fi
  exit 1
fi
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$DESTINATION"
"$PROJECT_ROOT/build/input-source" register "$DESTINATION" > /dev/null
if [ "$WAS_ACTIVE" = true ]; then
  "$PROJECT_ROOT/build/input-source" select > /dev/null
fi
mkdir -p "$HOME/Applications"
LAUNCHER="$HOME/Applications/siêu việt.app"
LEGACY_LAUNCHER="$HOME/Applications/viet.app"
if [ -L "$LEGACY_LAUNCHER" ] && [ "$(readlink "$LEGACY_LAUNCHER")" = "$DESTINATION" ]; then
  rm "$LEGACY_LAUNCHER"
fi
if [ ! -e "$LAUNCHER" ] && [ ! -L "$LAUNCHER" ]; then
  ln -s "$DESTINATION" "$LAUNCHER"
elif [ -L "$LAUNCHER" ] && [ "$(readlink "$LAUNCHER")" = "$DESTINATION" ]; then
  :
else
  message installPreserved "path=$LAUNCHER" "destination=$DESTINATION"
fi
message installComplete "path=$DESTINATION"
message installLaunch "path=$LAUNCHER"
message installMacHelp
message installMacLogin

# A copied bundle is insufficient: restart and verify the process being used.
/usr/bin/codesign --verify --deep --strict "$DESTINATION"
/usr/bin/cmp "$SOURCE/Contents/MacOS/VietMoi" "$DESTINATION/Contents/MacOS/VietMoi"
/usr/bin/cmp "$SOURCE/Contents/Resources/BuildFingerprint.txt" "$DESTINATION/Contents/Resources/BuildFingerprint.txt"
/usr/bin/open "$DESTINATION"
RUNNING=false
for attempt in {1..30}; do
  for pid in $(/usr/bin/pgrep -x VietMoi || true); do
    command="$(/bin/ps -p "$pid" -o command=)"
    if [[ "$command" == "$DESTINATION/Contents/MacOS/VietMoi"* ]]; then
      RUNNING=true
      message installMacVerified "pid=$pid" "fingerprint=$EXPECTED"
      break
    fi
  done
  if [ "$RUNNING" = true ]; then break; fi
  sleep 0.1
done
if [ "$RUNNING" != true ]; then
  message installMacNotRunning >&2
  exit 1
fi
