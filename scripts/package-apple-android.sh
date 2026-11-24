#!/bin/bash
# Run on the development Mac after the regression checks.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
VERSION="$(python3 -c 'import json; print(json.load(open("Design/brand.json"))["version"])')"
OUTPUT="$ROOT/build/releases"
mkdir -p "$OUTPUT" "$ROOT/build/release-macos" "$ROOT/build/release-ios/Payload"
SIEUVIET_MAC_ARCHS="arm64 x86_64" bash scripts/build.sh
ARCHITECTURES="$(xcrun lipo -archs build/VietMoi.app/Contents/MacOS/VietMoi)"
[[ " $ARCHITECTURES " == *" arm64 "* && " $ARCHITECTURES " == *" x86_64 "* ]]
codesign --verify --deep --strict build/VietMoi.app
ditto build/VietMoi.app build/release-macos/VietMoi.app
python3 scripts/copy-guides.py build/release-macos
ditto ThirdPartyNotices build/release-macos/ThirdPartyNotices
ditto -c -k --keepParent build/release-macos "$OUTPUT/sieuviet-$VERSION-macos-universal.zip"
xcodebuild -project iOS/VietMobile.xcodeproj -scheme VietMobile -configuration Release \
  -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath build/iOS-release \
  CODE_SIGNING_ALLOWED=NO build
ditto build/iOS-release/Build/Products/Release-iphoneos/VietMobile.app build/release-ios/Payload/VietMobile.app
# Do not distribute stale development profiles from a previous signed build.
find build/release-ios/Payload -name embedded.mobileprovision -delete
(cd build/release-ios && /usr/bin/zip -qry "$OUTPUT/sieuviet-$VERSION-ios-unsigned.ipa" Payload)
python3 scripts/build-android.py --tests
cp Android/app/build/outputs/apk/debug/app-debug.apk "$OUTPUT/sieuviet-$VERSION-android-universal-debug.apk"
python3 scripts/copy-guides.py "$OUTPUT" INSTALL.md INSTALL.en.md
ditto ThirdPartyNotices "$OUTPUT/ThirdPartyNotices"
echo "Packaged Apple and Android builds in $OUTPUT"
