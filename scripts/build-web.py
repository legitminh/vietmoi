#!/usr/bin/env python3
"""Build the shared settings/testing UI (sieuviet.site) and copy it into Resources/WebApp.

Every app hosts this same UI: the intro, the keyboard list and the testing ground.
Set SIEUVIET_SITE to the sieuviet.site checkout; the default is a sibling directory.
The copied output is committed so app builds need neither Node nor that checkout.
"""
import os, shutil, subprocess
from pathlib import Path

root = Path(__file__).resolve().parents[1]
site = Path(os.environ.get('SIEUVIET_SITE', root.parent / 'sieuviet.site')).resolve()
target = root / 'Resources' / 'WebApp'
if not (site / 'package.json').exists():
    raise SystemExit(f'sieuviet.site checkout not found at {site}; set SIEUVIET_SITE')
subprocess.run(['pnpm', 'install', '--frozen-lockfile'], cwd=site, check=True)
subprocess.run(['pnpm', 'build'], cwd=site, check=True, env={**os.environ, 'BASE_PATH': '/'})
shutil.rmtree(target, ignore_errors=True)
shutil.copytree(site / 'build', target)
revision = subprocess.run(['git', 'rev-parse', 'HEAD'], cwd=site, capture_output=True, text=True).stdout.strip()
(target / 'SOURCE').write_text(f'sieuviet.site {revision}\n')
print(f'Shared UI copied to {target}')
