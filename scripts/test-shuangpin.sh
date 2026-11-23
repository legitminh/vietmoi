#!/bin/bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$PROJECT_ROOT/build/module-cache"
xcrun swiftc -swift-version 5 -module-cache-path "$PROJECT_ROOT/build/module-cache" \
  "$PROJECT_ROOT"/Sources/Core/*.swift \
  "$PROJECT_ROOT/Tests/Shuangpin/main.swift" -o "$PROJECT_ROOT/build/shuangpin-tests"
"$PROJECT_ROOT/build/shuangpin-tests" "$PROJECT_ROOT/Resources/Chinese/pinyin_simp.dict.yaml"
