#!/usr/bin/env python3
"""Build the Android keyboard and optional instrumentation APK using the pinned wrapper."""
import argparse
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tests", action="store_true")
    parser.add_argument("--abis", default="arm64-v8a,x86_64")
    args = parser.parse_args()
    subprocess.run([sys.executable, str(ROOT / "scripts/generate-design.py"), "--check"], check=True)
    environment = os.environ.copy()
    environment.setdefault("ANDROID_HOME", str(Path.home() / "Library/Android/sdk"))
    environment["GRADLE_USER_HOME"] = str(ROOT / "build/gradle-android")
    environment["SIEUVIET_ANDROID_ABIS"] = args.abis
    tasks = [":app:assembleDebug"] + ([":app:assembleDebugAndroidTest"] if args.tests else [])
    subprocess.run([str(ROOT / "Android/gradlew"), "--no-daemon", *tasks], cwd=ROOT / "Android", env=environment, check=True)
    print(ROOT / "Android/app/build/outputs/apk/debug/app-debug.apk")


if __name__ == "__main__":
    try:
        main()
    except subprocess.CalledProcessError as error:
        sys.exit(error.returncode)
