#!/bin/bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$PROJECT_ROOT/build/module-cache"
xcrun swiftc -swift-version 5 -module-cache-path "$PROJECT_ROOT/build/module-cache" \
  -framework AppKit -framework Carbon \
  "$PROJECT_ROOT/Tests/LiveHost/main.swift" -o "$PROJECT_ROOT/build/live-host-test"
"$PROJECT_ROOT/build/live-host-test"
