#!/usr/bin/env python3
"""Prepare isolated Swift/NDK tools on macOS without changing Xcode or shell defaults."""
import hashlib
from pathlib import Path
import platform
import subprocess
import tarfile
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
TOOLS = ROOT / "build/android-tools"
VERSION = (ROOT / ".swift-version").read_text().strip()
SWIFT_ANDROID_SHA256 = "4d6ad63ea74becd58e123ff58b1b48c3be5ec0db0dff0ea5abe37ac007dd3233"


def download(url, name, checksum=None):
    folder = TOOLS / "downloads"
    folder.mkdir(parents=True, exist_ok=True)
    target = folder / name
    if not target.exists():
        partial = target.with_suffix(target.suffix + ".part")
        print("Downloading " + url, flush=True)
        with urllib.request.urlopen(url, timeout=60) as response, partial.open("wb") as output:
            while block := response.read(1024 * 1024):
                output.write(block)
        partial.rename(target)
    if checksum:
        with target.open("rb") as stream:
            actual = hashlib.file_digest(stream, "sha256").hexdigest()
        if actual != checksum:
            raise SystemExit(f"Checksum mismatch for {target}; remove that download before retrying")
    return target


def main():
    if platform.system() != "Darwin":
        raise SystemExit("This bootstrap targets macOS; use SIEUVIET_SWIFT_TOOLCHAIN, SIEUVIET_SWIFT_SDKS and ANDROID_NDK_HOME on another host")
    if VERSION != "6.4.2":
        raise SystemExit("Update the pinned Android SDK checksum before changing Swift versions")
    sdk = TOOLS / f"swift-sdks/swift-{VERSION}-RELEASE_android.artifactbundle"
    if not sdk.exists():
        archive = download(f"https://download.swift.org/swift-{VERSION}-release/android-sdk/swift-{VERSION}-RELEASE/swift-{VERSION}-RELEASE_android.artifactbundle.tar.gz", "swift-android.tar.gz", SWIFT_ANDROID_SHA256)
        sdk.parent.mkdir(parents=True, exist_ok=True)
        with tarfile.open(archive) as bundle:
            # The official SDK uses symlinks within its artifact bundle.
            bundle.extractall(sdk.parent, filter="tar")
    ndk = TOOLS / "android-ndk-r30"
    if not ndk.exists():
        archive = download("https://dl.google.com/android/repository/android-ndk-r30-darwin.zip", "ndk.zip")
        # ditto preserves the archive's executable modes and symlinks on macOS.
        subprocess.run(["ditto", "-x", "-k", str(archive), str(TOOLS)], check=True)
    extracted = TOOLS / "swift-toolchain-extracted"
    if not extracted.exists():
        package = download(f"https://download.swift.org/swift-{VERSION}-release/xcode/swift-{VERSION}-RELEASE/swift-{VERSION}-RELEASE-osx.pkg", "swift-toolchain.pkg")
        subprocess.run(["pkgutil", "--check-signature", str(package)], check=True)
        subprocess.run(["pkgutil", "--expand-full", str(package), str(extracted)], check=True)
    print("Native Android tools are ready in " + str(TOOLS))


if __name__ == "__main__":
    main()
