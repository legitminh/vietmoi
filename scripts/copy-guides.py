#!/usr/bin/env python3
"""Copy the two release guides with working local language links."""
from pathlib import Path
import sys

root = Path(__file__).resolve().parents[1]
destination = Path(sys.argv[1])
destination.mkdir(parents=True, exist_ok=True)
vi_name = sys.argv[2] if len(sys.argv) > 2 else 'README.md'
en_name = sys.argv[3] if len(sys.argv) > 3 else 'README.en.md'
vi = (root / 'RELEASING.md').read_text(encoding='utf-8')
en = (root / 'RELEASING.en.md').read_text(encoding='utf-8')
for name, body in [(vi_name, vi), (en_name, en)]:
    body = body.replace('(RELEASING.en.md)', f'({en_name})').replace('(RELEASING.md)', f'({vi_name})')
    (destination / name).write_text(body, encoding='utf-8')
