#!/usr/bin/env python3
"""Print the fingerprint of inputs that affect the installed Mac app."""
import hashlib
from pathlib import Path
root = Path(__file__).resolve().parents[1]
paths = [p for folder in ['Sources/Core','Sources/Presentation','Sources/AppShell','Sources/macOS','Resources','Design']
         for p in (root / folder).rglob('*') if p.is_file()]
paths += [root / 'scripts' / name for name in ['build.sh','make-icons.swift','generate-design.py','mac-fingerprint.py']]
hash = hashlib.sha256()
for path in sorted(paths):
    hash.update(str(path.relative_to(root)).encode())
    hash.update(b'\0')
    hash.update(path.read_bytes())
    hash.update(b'\0')
print(hash.hexdigest())
