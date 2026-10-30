#!/bin/bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [ "${1:-}" != "--no-build" ]; then bash "$PROJECT_ROOT/scripts/build.sh"; fi
SOURCE="$PROJECT_ROOT/build/VietMoi.app"
DESTINATION="$HOME/Library/Input Methods/VietMoi.app"
if [ ! -x "$SOURCE/Contents/MacOS/VietMoi" ]; then echo "Build the app first." >&2; exit 1; fi
mkdir -p "$PROJECT_ROOT/build/module-cache"
xcrun swiftc -module-cache-path "$PROJECT_ROOT/build/module-cache" -framework Carbon \
  "$PROJECT_ROOT/scripts/input-source.swift" -o "$PROJECT_ROOT/build/input-source"
# Disconnect the old process before replacing it; macOS may otherwise retain a stale session.
"$PROJECT_ROOT/build/input-source" prepare-update
mkdir -p "$HOME/Library/Input Methods"
# Stop only this input method during an update; never restart system services.
/usr/bin/pkill -x VietMoi 2>/dev/null || true
/usr/bin/ditto "$SOURCE" "$DESTINATION"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$DESTINATION"
"$PROJECT_ROOT/build/input-source" register "$DESTINATION"
mkdir -p "$HOME/Applications"
LAUNCHER="$HOME/Applications/viet.app"
if [ ! -e "$LAUNCHER" ] && [ ! -L "$LAUNCHER" ]; then
  ln -s "$DESTINATION" "$LAUNCHER"
elif [ -L "$LAUNCHER" ] && [ "$(readlink "$LAUNCHER")" = "$DESTINATION" ]; then
  :
else
  echo "Existing $LAUNCHER was preserved; launch $DESTINATION directly."
fi
echo "Installed: $DESTINATION"
echo "Launch: $LAUNCHER"
echo "Add viet in System Settings → Keyboard → Text Input → Edit → + (Vietnamese or search viet)."
echo "If it is not listed yet, log out and back in; macOS may cache input methods."
