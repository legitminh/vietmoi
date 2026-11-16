#!/usr/bin/env python3
"""Real IBus/Fcitx -> GTK typing tests in an isolated X11/DBus session."""
import argparse
import os
from pathlib import Path
import subprocess
import sys
import sysconfig
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--inside', choices=['ibus','fcitx'])
parser.add_argument('--toolkit',choices=['gtk','qt'],default='gtk')
args = parser.parse_args()
if not args.inside:
    for framework in ['ibus','fcitx']:
        for toolkit in ['gtk','qt']:
            subprocess.run(['xvfb-run','-a','dbus-run-session','--',sys.executable,__file__,'--inside',framework,'--toolkit',toolkit],check=True)
    sys.exit(0)

framework = args.inside
processes=[]
with tempfile.TemporaryDirectory(prefix=f'{framework}-',dir=ROOT/'build') as temporary:
    temporary=Path(temporary)
    os.environ.update(HOME=str(temporary),XDG_CONFIG_HOME=str(temporary/'config'),XDG_CACHE_HOME=str(temporary/'cache'),
                      XDG_DATA_HOME=str(temporary/'data'),XDG_RUNTIME_DIR=str(temporary/'runtime'),
                      XDG_DATA_DIRS=f'{ROOT}/build/linux-stage/share:/usr/local/share:/usr/share',
                      SIEUVIET_ENGINE_PATH=f'{ROOT}/build/linux-stage/lib/sieuviet/libSieuvietEngine.so',
                      SIEUVIET_CONFIG_FILE=str(temporary/'settings.conf'), GTK_IM_MODULE='ibus' if framework=='ibus' else 'fcitx',
                      XMODIFIERS='@im=ibus' if framework=='ibus' else '@im=fcitx',
                      QT_IM_MODULE='ibus' if framework=='ibus' else 'fcitx')
    (temporary/'runtime').mkdir(mode=0o700)
    config=temporary/'settings.conf'; config.write_text('version=1\ninput=0\noutput=0\n')
    def start(command):
        log=open(ROOT/f'build/{framework}-{len(processes)}.log','w')
        process=subprocess.Popen([str(x) for x in command],stdout=log,stderr=log)
        processes.append((process,log)); return process
    def run(command):
        return subprocess.run([str(x) for x in command],check=True,capture_output=True,text=True,timeout=12).stdout.strip()
    def wait(test, description):
        deadline=time.monotonic()+8
        while time.monotonic()<deadline:
            try:
                if test(): return
            except (subprocess.CalledProcessError,FileNotFoundError): pass
            time.sleep(.05)
        raise AssertionError(description)
    def key(value): run(['xdotool','key','--clearmodifiers',value]); time.sleep(.1)
    def type(value): run(['xdotool','type','--clearmodifiers','--delay','55',value]); time.sleep(.2)
    output=temporary/'host.txt'
    def expect(value,description):
        try: wait(lambda:output.read_text()==value,description)
        except AssertionError:
            raise AssertionError(f'{framework}: {description}: expected {value!r}, actual {output.read_text() if output.exists() else None!r}')
    def clear(): key('ctrl+a'); key('BackSpace'); expect('','native selection deletion')
    try:
        start(['openbox','--sm-disable'])
        if framework=='ibus':
            start(['ibus-daemon','--xim','--single','--panel=disable','--config=disable'])
            wait(lambda:'xkb:' in run(['ibus','list-engine']),'IBus started')
            start([ROOT/'build/linux-stage/libexec/sieuviet/ibus-engine-sieuviet'])
            wait(lambda:run(['ibus','engine','sieuviet'])=='','IBus selected Sieuviet')
        else:
            os.environ['FCITX_ADDON_DIRS']=f"{ROOT}/build/linux-stage/lib/fcitx5:/usr/lib/{sysconfig.get_config_var('MULTIARCH')}/fcitx5"
            profile=temporary/'config/fcitx5/profile';profile.parent.mkdir(parents=True)
            profile.write_text('[Groups/0]\nName=Default\nDefault Layout=us\nDefaultIM=sieuviet\n\n[Groups/0/Items/0]\nName=sieuviet\nLayout=\n\n[GroupOrder]\n0=Default\n')
            start(['fcitx5','-D','--disable=notifications,clipboard,spell,unicode,quickphrase,wayland,waylandim'])
            wait(lambda:'true' in run(['gdbus','call','--session','--dest','org.freedesktop.DBus','--object-path','/org/freedesktop/DBus','--method','org.freedesktop.DBus.NameHasOwner','org.fcitx.Fcitx5']),'Fcitx started')
        host=start([ROOT/('build/linux-native/linux/linux-host-test' if args.toolkit=='gtk' else 'build/linux-native/linux/linux-qt-host-test'),output])
        wait(lambda:run(['xdotool','search','--name','^Sieuviet host test$'])!='','GTK host window')
        window=run(['xdotool','search','--name','^Sieuviet host test$']).splitlines()[0]
        run(['xdotool','windowactivate','--sync',window]);time.sleep(.4)
        if framework=='fcitx': run(['fcitx5-remote','-o']);run(['fcitx5-remote','-s','sieuviet']);time.sleep(.4)
        for mode in [0,1]:
            config.write_text(f'version=1\ninput=0\noutput={mode}\n')
            key('Tab');key('shift+Tab')
            type('msedfrejrwosimojxaqsmlnd')
            expected='má fở răo khwỉo xoong muốn ' if mode==0 else 'má phở rau khuỷu xoong muốn '
            expect(expected,'reviewed words, output '+str(mode));clear()
        type('ms');key('BackSpace');type('sed');expect('má ','round undo');clear()
        type('ms');key('Escape');type('frej');expect('phở ','cancel own preedit');
        key('Delete');expect('','verified cycle deletion')
        key('Shift_L');type('hello ');expect('hello ','literal ASCII')
        key('Shift_L');type('msed');expect('hello má ','return to Vietnamese');clear()
        type('msed');key('ctrl+a');type('frej');expect('phở ','selection replacement');clear()
        type('ms');key('Tab')
        prefix=output.read_text()
        if prefix not in ['', 'ma']: raise AssertionError('Unexpected focus boundary output: '+repr(prefix))
        second=Path(str(output)+'.second')
        if second.exists() and second.read_text(): raise AssertionError('Preedit leaked into second field')
        key('shift+Tab');key('End');type('frej');expect(prefix+'phở ','focus reset does not leak old preedit');clear()
        config.write_text('version=1\ninput=1\noutput=1\n');key('Tab');key('shift+Tab')
        type('r312');expect('má ','grid uses shared routing');clear()
        type('rz312');expect('má ','unavailable grid position does not advance')
        print(f'PASS {framework}/{args.toolkit}: actual daemon → native field, both outputs, grid, undo, cancel, safe deletion, selection, focus, Shift mode.',flush=True)
    finally:
        for process,log in reversed(processes):
            process.terminate()
            try: process.wait(timeout=3)
            except subprocess.TimeoutExpired: process.kill();process.wait()
            log.close()
