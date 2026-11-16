#!/usr/bin/python3
"""Native settings using the shared brand/content catalogs. No typing is stored."""
import json
import os
from pathlib import Path
import tempfile
import gi
gi.require_version('Gtk','3.0')
from gi.repository import Gtk, Gdk

catalog=json.loads((Path(__file__).resolve().parent.parent/'share/sieuviet/design.json').read_text())
path=Path(os.environ.get('SIEUVIET_CONFIG_FILE',Path(os.environ.get('XDG_CONFIG_HOME',Path.home()/'.config'))/'sieuviet/settings.conf'))
values=dict(line.split('=',1) for line in path.read_text().splitlines() if '=' in line) if path.exists() else {}
language=values.get('language','vi')
def text(key): return catalog['copy'][key]['en' if language=='en' else 'vi']
window=Gtk.Window(title=catalog['brand']['name']);window.set_icon_from_file(str(Path(__file__).resolve().parent.parent/'share/icons/hicolor/scalable/apps/sieuviet.svg'));window.set_default_size(480,400);window.set_border_width(24)
css=Gtk.CssProvider();css.load_from_data(b'* { font-family: monospace; }')
Gtk.StyleContext.add_provider_for_screen(Gdk.Screen.get_default(),css,Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)
column=Gtk.Box(orientation=Gtk.Orientation.VERTICAL,spacing=12);window.add(column)
column.pack_start(Gtk.Label(label=catalog['brand']['name'],xalign=0),False,False,0)
selectors={};labels={}
for name,key,options in [('input','inputLabel',['ASCII+','Grid']),('output','outputLabel',[catalog['brand']['name'],'Quốc ngữ']),('language','language',['Tiếng Việt','English'])]:
    label=Gtk.Label(label=text(key),xalign=0);labels[key]=label;column.pack_start(label,False,False,0)
    selector=Gtk.ComboBoxText()
    for option in options: selector.append_text(option)
    selector.set_active(int(values.get(name)=='en') if name=='language' else int(values.get(name)=='1'))
    column.pack_start(selector,False,False,0);selectors[name]=selector
help_label=Gtk.Label(label=text('settingsHelp'),xalign=0);help_label.set_line_wrap(True);column.pack_start(help_label,False,False,8)
def save(*_):
    global language,values
    candidate={'version':'1','input':str(selectors['input'].get_active()),'output':str(selectors['output'].get_active()),'language':'en' if selectors['language'].get_active()==1 else 'vi'}
    temporary=None
    try:
        path.parent.mkdir(parents=True,exist_ok=True)
        with tempfile.NamedTemporaryFile(mode='w',dir=path.parent,delete=False) as file:
            temporary=file.name;file.write(''.join(f'{key}={value}\n' for key,value in candidate.items()))
        os.replace(temporary,path)
        values=candidate;language=candidate['language']
        for key,label in labels.items(): label.set_text(text(key))
        help_label.set_text(text('settingsHelp'))
    except OSError:
        if temporary: Path(temporary).unlink(missing_ok=True)
        dialog=Gtk.MessageDialog(transient_for=window,modal=True,message_type=Gtk.MessageType.ERROR,buttons=Gtk.ButtonsType.OK,text=text('saveError'))
        dialog.format_secondary_text(text('saveErrorHelp'));dialog.run();dialog.destroy()
for selector in selectors.values(): selector.connect('changed',save)
window.connect('destroy',Gtk.main_quit);window.show_all();Gtk.main()
