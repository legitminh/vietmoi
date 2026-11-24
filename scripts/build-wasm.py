#!/usr/bin/env python3
"""Build the shared core for the web demo as WebAssembly (Embedded Swift).

Web/Sources/SieuvietWeb links the very Core and Mobile sources the apps compile, so
the web demo types exactly like the native keyboards. The output directory receives:

  sieuviet.wasm     the core and the iOS input session (MobileInputSession)
  pinyin_simp.txt   the Chinese dictionary, fetched by the page only for Chinese keyboards
  SOURCE            the vietmoi revision and a hash of every compiled source

Requires Swift 6.4+ and its matching WebAssembly SDK (`swift sdk list` shows
swift-<version>-RELEASE_wasm-embedded). The default output is the sibling
sieuviet.site checkout's static/core; pass --output or set SIEUVIET_SITE.
With --if-changed, nothing is rebuilt when SOURCE already matches the sources.
"""
import argparse
import hashlib
import os
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
PACKAGE = ROOT / "Web"
SOURCES = PACKAGE / "Sources" / "SieuvietWeb"
DICTIONARY = ROOT / "Resources" / "Chinese" / "pinyin_simp.dict.yaml"


def sources():
    files = sorted(SOURCES.rglob("*.swift")) + [PACKAGE / "Package.swift", DICTIONARY]
    for path in files:
        if path.is_symlink() and not path.exists():
            raise SystemExit(f"broken link: {path.relative_to(ROOT)}")
    return files


def fingerprint():
    digest = hashlib.sha256()
    for path in sources():
        digest.update(str(path.relative_to(ROOT)).encode())
        digest.update(path.resolve().read_bytes())
    return digest.hexdigest()


def swift_sdk(swift):
    listed = subprocess.run([swift, "sdk", "list"], capture_output=True, text=True, check=True).stdout.split()
    embedded = [name for name in listed if name.endswith("_wasm-embedded")]
    if not embedded:
        raise SystemExit("No Embedded Swift WebAssembly SDK installed. See https://www.swift.org/documentation/articles/wasm-getting-started.html")
    return sorted(embedded)[-1]


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    site = Path(os.environ.get("SIEUVIET_SITE", ROOT.parent / "sieuviet.site"))
    parser.add_argument("--output", type=Path, default=site / "static" / "core")
    parser.add_argument("--if-changed", action="store_true", help="skip the build when the output is current")
    parser.add_argument("--swift-sdk", help="Swift SDK name (default: the newest *_wasm-embedded SDK)")
    args = parser.parse_args()
    output = args.output.resolve()
    stamp = fingerprint()
    if args.if_changed and (output / "SOURCE").exists() and stamp in (output / "SOURCE").read_text() \
            and (output / "sieuviet.wasm").exists():
        print(f"core is current in {output}")
        return
    swift = shutil.which("swift")
    if not swift:
        raise SystemExit("Swift is not installed (https://www.swift.org/install)")
    sdk = args.swift_sdk or swift_sdk(swift)
    subprocess.run([swift, "build", "--package-path", str(PACKAGE), "--swift-sdk", sdk, "-c", "release",
                    "-Xlinker", "--strip-all", "-Xlinker", "--gc-sections"], check=True)
    binary = Path(subprocess.run([swift, "build", "--package-path", str(PACKAGE), "--swift-sdk", sdk, "-c", "release",
                                  "--show-bin-path"], capture_output=True, text=True, check=True).stdout.strip())
    output.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(binary / "SieuvietWeb.wasm", output / "sieuviet.wasm")
    # The dictionary text is served as-is; the page builds the index in idle time.
    shutil.copyfile(DICTIONARY, output / "pinyin_simp.txt")
    for notice in ("LICENSE", "NOTICE"):
        shutil.copyfile(DICTIONARY.parent / notice, output / f"pinyin_simp.{notice}")
    revision = subprocess.run(["git", "rev-parse", "HEAD"], cwd=ROOT, capture_output=True, text=True).stdout.strip()
    (output / "SOURCE").write_text(f"vietmoi {revision or 'unknown'}\nsources {stamp}\n")
    size = (output / "sieuviet.wasm").stat().st_size
    print(f"core built for the web: {output / 'sieuviet.wasm'} ({size // 1024} KB)")


if __name__ == "__main__":
    main()
