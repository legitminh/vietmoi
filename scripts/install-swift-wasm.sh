#!/bin/sh
# Install the Swift toolchain and Embedded WebAssembly SDK that scripts/build-wasm.py needs (Ubuntu 24.04, x86_64).
# Usage: scripts/install-swift-wasm.sh [prefix]   (default prefix: $HOME/.swift-wasm)
set -eu
VERSION=6.4.2
SDK_CHECKSUM=83baca83553f8c443cda7b84800912e6e709c3acd2e7ebf277794ca5836c0da5
PREFIX=${1:-$HOME/.swift-wasm}
BASE=https://download.swift.org/swift-$VERSION-release
if [ ! -x "$PREFIX/usr/bin/swift" ]; then
    mkdir -p "$PREFIX"
    curl -fsSL "$BASE/ubuntu2404/swift-$VERSION-RELEASE/swift-$VERSION-RELEASE-ubuntu24.04.tar.gz" \
        | tar -xz -C "$PREFIX" --strip-components=1
fi
export PATH="$PREFIX/usr/bin:$PATH"
if ! swift sdk list | grep -q "swift-$VERSION-RELEASE_wasm-embedded"; then
    swift sdk install "$BASE/wasm-sdk/swift-$VERSION-RELEASE/swift-$VERSION-RELEASE_wasm.artifactbundle.tar.gz" \
        --checksum "$SDK_CHECKSUM"
fi
if [ -n "${GITHUB_PATH:-}" ]; then echo "$PREFIX/usr/bin" >> "$GITHUB_PATH"; fi
swift --version
