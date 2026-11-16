#!/usr/bin/env python3
"""Install and test the real Android IME. Default target is the dedicated Sieuviet AVD."""
import argparse
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
PACKAGE = "com.minh.sieuviet.android"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--serial", default="emulator-5556")
    parser.add_argument("--no-build", action="store_true")
    parser.add_argument("--class", dest="test_class", help="Optional JUnit class or Class#method filter")
    args = parser.parse_args()
    if not args.no_build:
        subprocess.run([sys.executable, str(ROOT / "scripts/build-android.py"), "--tests"], check=True)
    sdk = Path(os.environ.get("ANDROID_HOME", Path.home() / "Library/Android/sdk"))
    adb = [str(sdk / "platform-tools/adb"), "-s", args.serial]
    def call(*arguments, **kwargs):
        return subprocess.run([*adb, *arguments], cwd=ROOT, check=True, **kwargs)
    call("get-state", capture_output=True)
    call("install", "-r", str(ROOT / "Android/app/build/outputs/apk/debug/app-debug.apk"))
    call("install", "-r", str(ROOT / "Android/app/build/outputs/apk/androidTest/debug/app-debug-androidTest.apk"))
    command = ["shell", "am", "instrument", "-w", "-r"]
    if args.test_class:
        command += ["-e", "class", args.test_class]
    result = call(*command, PACKAGE + ".test/androidx.test.runner.AndroidJUnitRunner", capture_output=True, text=True)
    (ROOT / "build/android-instrumentation.log").write_text(result.stdout + result.stderr)
    print(result.stdout)
    # `am instrument` can return exit 0 even if JUnit tests fail.
    if "FAILURES!!!" in result.stdout or "OK (" not in result.stdout or "INSTRUMENTATION_FAILED" in result.stdout:
        screenshot = call("exec-out", "screencap", "-p", capture_output=True).stdout
        (ROOT / "build/android-test-failure.png").write_bytes(screenshot)
        raise SystemExit("Android instrumentation failed; see build/android-instrumentation.log")


if __name__ == "__main__":
    try:
        main()
    except subprocess.CalledProcessError as error:
        sys.exit(error.returncode)
