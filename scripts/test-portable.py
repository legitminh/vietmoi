#!/usr/bin/env python3
"""Run the existing, unmodified Swift regression suites on macOS/Linux/Windows."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
SUITES = {"engine": "Tests/main.swift", "ascii-plus": "Tests/ASCIIPlus/main.swift",
          "standard": "Tests/Standard/main.swift", "profiles": "Tests/Profiles/main.swift",
          "shift": "Tests/Shift/main.swift"}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--suite", choices=list(SUITES), action="append")
    args = parser.parse_args()
    compiler = os.environ.get("SIEUVIET_SWIFTC") or shutil.which("swiftc")
    if not compiler:
        parser.error("Install Swift and put swiftc on PATH, or set SIEUVIET_SWIFTC")
    build = ROOT / "build" / "portable"
    cache = build / "module-cache"
    cache.mkdir(parents=True, exist_ok=True)
    sources = sorted((ROOT / "Sources" / "Core").glob("*.swift"))
    for suite in args.suite or SUITES:
        executable = build / (suite + (".exe" if os.name == "nt" else ""))
        command = [compiler, "-swift-version", "5", "-module-cache-path", str(cache)]
        if suite in ("ascii-plus", "standard"):
            command.append("-O")
        command += [str(path) for path in sources]
        command += [str(ROOT / SUITES[suite]), "-o", str(executable)]
        print(f"Running {suite} with {compiler}", flush=True)
        subprocess.run(command, cwd=ROOT, check=True)
        subprocess.run([str(executable)], cwd=ROOT, check=True)


if __name__ == "__main__":
    try:
        main()
    except subprocess.CalledProcessError as error:
        sys.exit(error.returncode)
