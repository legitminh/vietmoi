#!/usr/bin/env python3
"""Cross-compile the original Swift engine and its thin JNI bridge for Android."""
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
TOOLS = ROOT / "build/android-tools"
VERSION = (ROOT / ".swift-version").read_text().strip()
ABIS = {"arm64-v8a": ("aarch64", "aarch64-linux-android"), "x86_64": ("x86_64", "x86_64-linux-android")}
SYSTEM_LIBS = {"libc.so", "libm.so", "libdl.so", "liblog.so", "libandroid.so", "libz.so"}


def run(command, environment, **kwargs):
    return subprocess.run([str(x) for x in command], cwd=ROOT, env=environment, check=True, **kwargs)


def configure_sdk(sdk, ndk):
    """Same links as the official setup script, with correct handling of spaces."""
    prebuilt = next((ndk / "toolchains/llvm/prebuilt").iterdir())
    sysroot = sdk / "ndk-sysroot"
    include = sysroot / "usr/include"
    include.parent.mkdir(parents=True, exist_ok=True)
    if not include.exists():
        include.symlink_to(prebuilt / "sysroot/usr/include", target_is_directory=True)
    libraries = sysroot / "usr/lib"
    libraries.mkdir(exist_ok=True)
    for folder in (prebuilt / "sysroot/usr/lib").iterdir():
        target = libraries / folder.name
        if not target.exists():
            target.symlink_to(folder, target_is_directory=True)
    resources = sdk / "swift-resources/usr/lib"
    clang = resources / "swift/clang"
    if clang.is_symlink() and not clang.exists():
        clang.unlink()
    if not clang.exists():
        clang.parent.mkdir(exist_ok=True)
        clang.symlink_to(next((prebuilt / "lib/clang").iterdir()), target_is_directory=True)
    for folder in ("swift", "swift_static"):
        for source in resources.glob(folder + "-*/android/*/swiftrt.o"):
            target = libraries / folder / "android" / source.parent.name / "swiftrt.o"
            target.parent.mkdir(parents=True, exist_ok=True)
            if not target.exists():
                target.symlink_to(source)
    return prebuilt


def main():
    ndk = Path(os.environ.get("ANDROID_NDK_HOME", TOOLS / "android-ndk-r30"))
    sdks = Path(os.environ.get("SIEUVIET_SWIFT_SDKS", TOOLS / "swift-sdks"))
    sdk = sdks / f"swift-{VERSION}-RELEASE_android.artifactbundle/swift-android"
    toolchain = Path(os.environ.get("SIEUVIET_SWIFT_TOOLCHAIN", TOOLS / "swift-toolchain-extracted" /
                                  f"swift-{VERSION}-RELEASE-osx-package.pkg/Payload"))
    swift = toolchain / "usr/bin/swift"
    if not swift.exists() or not (sdk / "swift-sdk.json").exists() or not ndk.exists():
        raise SystemExit("Android native tools are missing. See Android/README.md for setup and environment overrides.")
    environment = os.environ.copy()
    environment["ANDROID_NDK_HOME"] = str(ndk)
    environment["CLANG_MODULE_CACHE_PATH"] = str(ROOT / "build/android-module-cache")
    environment["SWIFTPM_MODULECACHE_OVERRIDE"] = environment["CLANG_MODULE_CACHE_PATH"]
    prebuilt = configure_sdk(sdk, ndk)
    abis = os.environ.get("SIEUVIET_ANDROID_ABIS", "arm64-v8a,x86_64").split(",")
    for abi in abis:
        if abi not in ABIS:
            raise SystemExit(f"Unsupported Android ABI: {abi}")
        arch, ndk_triple = ABIS[abi]
        triple = arch + "-unknown-linux-android29"
        output = ROOT / "build/android-native" / abi
        output.mkdir(parents=True, exist_ok=True)
        options = ["--disable-sandbox", "--configuration", "release", "--jobs", "2",
                   "--swift-sdks-path", sdks, "--swift-sdk", f"swift-{VERSION}-RELEASE_android",
                   "--triple", triple, "--scratch-path", ROOT / "build/android-swift" / abi,
                   "--cache-path", ROOT / "build/android-swift-cache", "--config-path", ROOT / "build/android-swift-config",
                   "--security-path", ROOT / "build/android-swift-security"]
        run([swift, "build", *options, "--product", "SieuvietEngine"], environment)
        binary = Path(run([swift, "build", *options, "--show-bin-path"], environment,
                          capture_output=True, text=True).stdout.strip())
        library = binary / "libSieuvietEngine.so"
        shutil.copy2(library, output / library.name)
        compiler = prebuilt / "bin" / (ndk_triple + "29-clang++")
        run([compiler, "-std=c++17", "-shared", "-fPIC", "-O2", "-Wall", "-Wextra", "-Werror",
             "-Wl,-z,max-page-size=16384", "-Wl,-soname,libsieuviet_jni.so",
             "-I", ROOT / "Sources/CABI/include", ROOT / "Android/app/src/main/cpp/engine_jni.cpp",
             "-L", binary, "-lSieuvietEngine", "-o", output / "libsieuviet_jni.so"], environment)
        # Bundle only transitive non-system runtime dependencies for this ABI.
        candidates = [sdk / f"swift-resources/usr/lib/swift-{arch}/android",
                      prebuilt / "sysroot/usr/lib" / ndk_triple, binary]
        index = {}
        for directory in candidates:
            for candidate in directory.rglob("*.so"):
                index.setdefault(candidate.name, candidate)
        reader = prebuilt / "bin/llvm-readelf"
        pending = [output / "libSieuvietEngine.so", output / "libsieuviet_jni.so"]
        checked = set()
        while pending:
            current = pending.pop()
            if current.name in checked:
                continue
            checked.add(current.name)
            dynamic = run([reader, "-d", current], environment, capture_output=True, text=True).stdout
            for dependency in re.findall(r"\(NEEDED\).*?\[(.*?)\]", dynamic):
                if dependency in SYSTEM_LIBS or dependency in checked:
                    continue
                if dependency not in index:
                    raise SystemExit(f"Cannot package {dependency} needed by {current.name}")
                target = output / dependency
                if index[dependency].resolve() != target.resolve():
                    shutil.copy2(index[dependency], target)
                pending.append(target)
        stripper = prebuilt / "bin/llvm-strip"
        for library in output.glob("*.so"):
            run([stripper, "--strip-unneeded", library], environment)
        (output / "engine-build.json").write_text(json.dumps({"swift": VERSION, "triple": triple,
                                                            "libraries": sorted(checked)}, indent=2))
        print(f"Packaged shared Swift engine and JNI for {abi}", flush=True)


if __name__ == "__main__":
    try:
        main()
    except subprocess.CalledProcessError as error:
        sys.exit(error.returncode)
