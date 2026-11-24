#!/usr/bin/env python3
"""Launch both native settings languages; capture and verify persisted choices."""
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
ROOT=Path(__file__).resolve().parents[1]
if '--inside' not in sys.argv:
    subprocess.run(['xvfb-run','-a','dbus-run-session','--',sys.executable,__file__,'--inside'],check=True);sys.exit(0)
import gi
gi.require_version('Gdk','3.0')
from gi.repository import Gdk
with tempfile.TemporaryDirectory(dir=ROOT/'build') as directory:
    path=Path(directory)/'settings.conf';environment=os.environ.copy();environment['SIEUVIET_CONFIG_FILE']=str(path)
    for language in ['vi','en']:
        contents=f'version=1\ninput=1\noutput=1\nlanguage={language}\n';path.write_text(contents)
        process=subprocess.Popen([ROOT/'build/linux-stage/bin/sieuviet-settings'],env=environment)
        try:
            for _ in range(100):
                if process.poll() is not None: raise AssertionError('Settings exited before showing its window')
                result=subprocess.run(['xdotool','search','--name','^siêu việt$'],capture_output=True,text=True)
                if result.returncode==0: break
                time.sleep(.05)
            else: raise AssertionError('Settings window did not appear')
            time.sleep(.3)
            window=Gdk.get_default_root_window();width,height=window.get_width(),window.get_height()
            Gdk.pixbuf_get_from_window(window,0,0,width,height).savev(str(ROOT/f'build/settings-{language}.png'),'png',[],[])
            if path.read_text()!=contents: raise AssertionError('Opening settings changed layout/output/language')
        finally:
            process.terminate();process.wait(timeout=3)
print('PASS native settings: Vietnamese/English launch, persisted input/output unchanged; screenshots captured.')
