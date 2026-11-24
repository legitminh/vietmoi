#!/usr/bin/env python3
"""Create/start the isolated Sieuviet Android 16 emulator. Existing AVDs are untouched."""
import argparse
import os
from pathlib import Path
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
NAME = "Sieuviet_API_36"
SERIAL = "emulator-5556"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--headless", action="store_true")
    parser.add_argument("--prepare-only", action="store_true")
    parser.add_argument("--restart", action="store_true", help="Restart only the dedicated Sieuviet AVD")
    args = parser.parse_args()
    sdk = Path(os.environ.get("ANDROID_HOME", Path.home() / "Library/Android/sdk"))
    image = sdk / "system-images/android-36/google_apis_playstore/arm64-v8a"
    if not image.is_dir():
        parser.error(f"Install the Android 36 Google Play ARM64 system image in {sdk}")
    avds = ROOT / "build/android-avd"
    avd = avds / (NAME + ".avd")
    avd.mkdir(parents=True, exist_ok=True)
    (avds / (NAME + ".ini")).write_text(f"avd.ini.encoding=UTF-8\npath={avd}\ntarget=android-36\n")
    config = avd / "config.ini"
    if not config.exists():
        config.write_text("\n".join([
            f"AvdId={NAME}", "avd.ini.encoding=UTF-8", "avd.ini.displayname=Sieuviet Android 16",
            "PlayStore.enabled=true", "abi.type=arm64-v8a", "hw.cpu.arch=arm64", "hw.cpu.ncore=4",
            "hw.device.manufacturer=Google", "hw.device.name=pixel_6", "hw.keyboard=yes",
            "hw.lcd.width=1080", "hw.lcd.height=2400", "hw.lcd.density=420", "hw.ramSize=2048",
            "hw.gpu.enabled=yes", "hw.gpu.mode=auto", "hw.mainKeys=no", "hw.battery=yes",
            "hw.audioInput=no", "hw.camera.back=none", "hw.camera.front=none", "hw.gps=yes",
            "hw.sensors.orientation=yes", "hw.initialOrientation=portrait", "showDeviceFrame=no",
            "disk.dataPartition.size=4G", "vm.heapSize=256", "skin.dynamic=yes", "skin.name=1080x2400",
            "tag.id=google_apis_playstore", "tag.display=Google Play", "image.sysdir.1=" + str(image), ""]))
    if args.prepare_only:
        print(avd)
        return
    adb = [str(sdk / "platform-tools/adb"), "-s", SERIAL]
    existing = subprocess.run([*adb, "emu", "avd", "name"], capture_output=True, text=True, timeout=8)
    if existing.returncode == 0:
        active = existing.stdout.splitlines()[0].strip()
        if active != NAME:
            raise SystemExit(f"{SERIAL} belongs to {active}; refusing to replace another device")
        if not args.restart:
            print(f"{NAME} is already running. Use --restart to change headless/windowed mode.")
            return
        subprocess.run([*adb, "emu", "kill"], check=True, capture_output=True, timeout=8)
        deadline = time.monotonic() + 20
        while time.monotonic() < deadline:
            connected = subprocess.run([*adb, "get-state"], capture_output=True, timeout=5)
            if connected.returncode != 0:
                break
            time.sleep(0.25)
        else:
            raise SystemExit("The dedicated emulator has not stopped; see build/android-emulator.log")
        time.sleep(1)
    environment = os.environ.copy()
    environment.update(ANDROID_HOME=str(sdk), ANDROID_SDK_ROOT=str(sdk), ANDROID_AVD_HOME=str(avds),
                       ANDROID_EMULATOR_HOME=str(ROOT / "build/android-emulator"))
    Path(environment["ANDROID_EMULATOR_HOME"]).mkdir(parents=True, exist_ok=True)
    command = [str(sdk / "emulator/emulator"), "-avd", NAME, "-port", "5556", "-no-snapshot", "-no-audio", "-no-metrics"]
    if args.headless:
        command += ["-no-window"]
    # Keep the emulator alive after this helper exits; all output goes to a local log.
    with (ROOT / "build/android-emulator.log").open("ab") as log:
        process = subprocess.Popen(command, env=environment, stdout=log, stderr=subprocess.STDOUT,
                                   start_new_session=True)
    print(f"Started {NAME} ({SERIAL}), PID {process.pid}. Log: build/android-emulator.log")


if __name__ == "__main__":
    main()
