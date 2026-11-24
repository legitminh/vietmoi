#!/usr/bin/env python3
"""Build/test the shared package and call its actual dynamic library from C/C++."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]


def run(command, environment, **kwargs):
    return subprocess.run(command, cwd=ROOT, env=environment, check=True, **kwargs)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--bridge-only", action="store_true", help="Skip Swift test execution")
    parser.add_argument("--configuration", choices=["debug", "release"], default="debug")
    parser.add_argument("--jobs", type=int, default=2, help="Maximum concurrent compiler jobs")
    args = parser.parse_args()
    if args.jobs < 1:
        parser.error("--jobs must be positive")
    swift = shutil.which("swift")
    cc = os.environ.get("SIEUVIET_CC") or shutil.which("clang")
    cxx = os.environ.get("SIEUVIET_CXX") or shutil.which("clang++")
    if not swift or not cc or not cxx:
        parser.error("Swift 6.3+ and Clang/Clang++ must be installed and on PATH")
    environment = os.environ.copy()
    environment["CLANG_MODULE_CACHE_PATH"] = str(ROOT / "build/package-module-cache")
    environment["SWIFTPM_MODULECACHE_OVERRIDE"] = environment["CLANG_MODULE_CACHE_PATH"]
    options = ["--disable-sandbox", "--configuration", args.configuration, "--jobs", str(args.jobs),
               "--scratch-path", "build/package", "--cache-path", "build/package-cache",
               "--config-path", "build/package-config", "--security-path", "build/package-security"]
    run([swift, "build", *options, "--product", "SieuvietEngine"], environment)
    if not args.bridge_only:
        run([swift, "test", *options], environment)
    binary = Path(run([swift, "build", *options, "--show-bin-path"], environment,
                      capture_output=True, text=True).stdout.strip())
    environment["PATH"] = str(binary) + os.pathsep + environment.get("PATH", "")
    if sys.platform == "win32":
        imports = [binary / "SieuvietEngine.lib", binary / "libSieuvietEngine.lib"]
        library = next((path for path in imports if path.exists()), None)
        if library is None:
            parser.error(f"No Windows import library found in {binary}; verify Swift DLL exports")
        link = [str(library)]
    else:
        link = ["-L", str(binary), "-lSieuvietEngine", f"-Wl,-rpath,{binary}"]
    # Both compilers consume the checked-in C header, independently of Swift imports.
    for language, compiler, standard in [("c", cc, "c11"), ("c++", cxx, "c++17")]:
        executable = ROOT / "build" / ("bridge-test-" + ("c" if language == "c" else "cpp") +
                                      (".exe" if os.name == "nt" else ""))
        command = [compiler, "-x", language, f"-std={standard}", "-Wall", "-Wextra", "-Werror",
                   "-I", str(ROOT / "Sources/CABI/include"), str(ROOT / "Tests/CBridge/main.c"),
                   *link, "-o", str(executable)]
        run(command, environment)
        print(f"Testing dynamic library from {language}", flush=True)
        run([str(executable)], environment)


if __name__ == "__main__":
    try:
        main()
    except subprocess.CalledProcessError as error:
        sys.exit(error.returncode)
