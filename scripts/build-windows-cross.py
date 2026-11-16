#!/usr/bin/env python3
"""Cross-build the native Windows adapters, not the Windows Swift runtime."""
import argparse
import json
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--toolchain', type=Path, required=True, help='Extracted LLVM-MinGW directory')
args = parser.parse_args()
toolchain = args.toolchain.resolve()
for architecture, triple, machine in [('x64','x86_64','IMAGE_FILE_MACHINE_AMD64'), ('arm64','aarch64','IMAGE_FILE_MACHINE_ARM64')]:
    directory = ROOT / f'build/windows-{architecture}-cross'
    directory.mkdir(parents=True, exist_ok=True)
    config = directory / 'toolchain.cmake'
    config.write_text(f'''set(CMAKE_SYSTEM_NAME Windows)
set(CMAKE_SYSTEM_PROCESSOR {triple})
set(CMAKE_C_COMPILER "{toolchain}/bin/{triple}-w64-mingw32-clang")
set(CMAKE_CXX_COMPILER "{toolchain}/bin/{triple}-w64-mingw32-clang++")
set(CMAKE_RC_COMPILER "{toolchain}/bin/{triple}-w64-mingw32-windres")
''')
    def run(command, **kwargs):
        return subprocess.run([str(x) for x in command], cwd=ROOT, check=True, **kwargs)
    run(['cmake','-S','Desktop','-B',directory,'-G','Unix Makefiles',f'-DCMAKE_TOOLCHAIN_FILE={config}','-DCMAKE_BUILD_TYPE=Release'])
    run(['cmake','--build',directory,'--parallel','2'])
    products = [directory/'windows/SieuvietTSF.dll',directory/'windows/SieuvietSettings.exe',directory/'desktop-session-tests.exe']
    for product in products:
        headers = run([toolchain/'bin/llvm-readobj','--file-headers','--coff-imports',product],capture_output=True,text=True).stdout
        if machine not in headers: raise SystemExit(f'Unexpected PE architecture: {product}')
        if any(name in headers.lower() for name in ['name: libc++.dll','name: libunwind.dll']):
            raise SystemExit(f'Unpackaged C++ runtime dependency: {product}')
        (directory / (product.name + '.pe.txt')).write_text(headers)
    report = {'architecture':architecture,'nativeAdapterBuild':'passed','windowsSwiftEngineBuild':'not run',
              'interactiveTSFTest':'deferred by user','coreABI':1,
              'products':[str(x.relative_to(ROOT)) for x in products],
              'release':json.loads((ROOT/'Design/brand.json').read_text())['version']}
    (directory/'build-report.json').write_text(json.dumps(report,indent=2)+'\n')
print('Native x64 and ARM64 Windows products built. Build the Swift DLL on Windows before installation.')
