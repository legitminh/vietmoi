#!/usr/bin/env python3
"""Installer messages, Vietnamese by default; SIEUVIET_LANGUAGE=en selects English."""
import json
import os
from pathlib import Path
import sys

catalog = json.loads((Path(__file__).resolve().parents[1] / 'Design/content.json').read_text(encoding='utf-8'))
language = 'en' if os.environ.get('SIEUVIET_LANGUAGE') == 'en' else 'vi'
message = catalog[sys.argv[1]][language]
for pair in sys.argv[2:]:
    key, value = pair.split('=', 1)
    message = message.replace('{' + key + '}', value)
print(message)
