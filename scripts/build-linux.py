#!/usr/bin/env python3
"""Build/install the actual shared engine plus IBus and Fcitx adapters on Linux."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
def run(args, **kwargs):
    return subprocess.run([str(x) for x in args], cwd=ROOT, check=True, **kwargs)
def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--prefix", type=Path, default=ROOT / "build/linux-stage")
    parser.add_argument("--destdir", type=Path, help="Stage a system-prefix installation without modifying the host")
    args=parser.parse_args()
    if not sys.platform.startswith("linux"): parser.error("Run this helper on Linux or in the Linux development container")
    prefix=args.prefix.resolve()
    os.environ["CLANG_MODULE_CACHE_PATH"]=str(ROOT / "build/linux-module-cache")
    os.environ["SWIFTPM_MODULECACHE_OVERRIDE"]=os.environ["CLANG_MODULE_CACHE_PATH"]
    options=["--disable-sandbox","--configuration","release","--jobs","2","--scratch-path",ROOT/"build/linux-swift",
             "--cache-path",ROOT/"build/linux-swift-cache","--config-path",ROOT/"build/linux-swift-config","--security-path",ROOT/"build/linux-swift-security"]
    run(["swift","build",*options,"--product","SieuvietEngine"])
    binary=Path(run(["swift","build",*options,"--show-bin-path"],capture_output=True,text=True).stdout.strip())
    run(["python3","scripts/generate-design.py","--check"])
    run(["cmake","-S","Desktop","-B","build/linux-native","-G","Ninja",f"-DCMAKE_INSTALL_PREFIX={prefix}",
         "-DCMAKE_INSTALL_LIBDIR=lib",f"-DFCITX_INSTALL_USE_FCITX_SYS_PATHS={'ON' if str(prefix)=='/usr' else 'OFF'}",
         f"-DSIEUVIET_ENGINE_PATH={prefix}/lib/sieuviet/libSieuvietEngine.so","-DCMAKE_BUILD_TYPE=Release"])
    run(["cmake","--build","build/linux-native","--parallel","2"])
    install_environment=os.environ.copy()
    if args.destdir: install_environment["DESTDIR"]=str(args.destdir.resolve())
    run(["cmake","--install","build/linux-native"],env=install_environment)
    staged=args.destdir.resolve()/prefix.relative_to("/") if args.destdir else prefix
    library=staged/"lib/sieuviet";library.mkdir(parents=True,exist_ok=True)
    engine=binary/"libSieuvietEngine.so"
    dependencies=run(["ldd",engine],capture_output=True,text=True).stdout.splitlines()
    shutil.copy2(engine,library/engine.name)
    for line in dependencies:
        parts=line.split()
        if len(parts)>2 and parts[1]=="=>" and parts[2].startswith("/"):
            source=Path(parts[2])
            if any(name in source.name for name in ("swift","Foundation","BlocksRuntime","dispatch")):
                shutil.copy2(source,library/source.name)
    if shutil.which("patchelf"):
        for path in library.glob("*.so*"):
            run(["patchelf","--set-rpath","$ORIGIN",path])
            path.chmod(0o644)
    else:
        raise SystemExit("Install patchelf so packaged Swift dependencies load beside the core library")
    os.environ["SIEUVIET_ENGINE_PATH"]=str(library/engine.name)
    run(["ctest","--test-dir","build/linux-native","--output-on-failure"])
    print("Staged Sieuviet in "+str(staged))
if __name__=="__main__":
    try: main()
    except subprocess.CalledProcessError as error: sys.exit(error.returncode)
