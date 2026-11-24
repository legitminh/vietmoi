#!/usr/bin/python3
"""siêu việt for Linux: hosts the shared app UI (intro, keyboard list, testing
ground) and keeps settings.conf, which the IBus and Fcitx engines read, in step
with it. No typing is stored."""
import json
import os
from pathlib import Path
import tempfile
import uuid
import gi
gi.require_version('Gtk', '3.0')
try:
    gi.require_version('WebKit2', '4.1')
except ValueError:
    gi.require_version('WebKit2', '4.0')
from gi.repository import Gio, GLib, Gtk, WebKit2

share = Path(__file__).resolve().parent.parent / 'share'
catalog = json.loads((share / 'sieuviet/design.json').read_text())
web_root = Path(os.environ.get('SIEUVIET_WEB_ROOT', share / 'sieuviet/WebApp')).resolve()
path = Path(os.environ.get('SIEUVIET_CONFIG_FILE', Path(os.environ.get('XDG_CONFIG_HOME', Path.home() / '.config')) / 'sieuviet/settings.conf'))
inputs = {'vi': ['ascii+', 'grid4x8'], 'en': ['qwerty']}
outputs = {'vi': ['sieuviet', 'quốc ngữ'], 'en': ['literal']}


def interface_language(value):
    # Interface languages: Vietnamese (default), English and Chinese.
    return value if value in ('vi', 'en', 'zh') else 'vi'

def profile(identifier, name, language, input_type, output_type):
    language = 'en' if language == 'en' else 'vi'
    return {'id': identifier or str(uuid.uuid4()).upper(), 'name': name, 'language': language,
            'inputType': input_type if input_type in inputs[language] else inputs[language][0],
            'outputType': output_type if output_type in outputs[language] else outputs[language][0],
            'showVirtualKeyboard': True}


def load():
    """Read settings.conf (version 2, or version 1 as [that keyboard, English])."""
    lines = path.read_text().splitlines() if path.exists() else []
    values, profiles = {}, []
    for line in lines:
        key, _, value = line.partition('=')
        if key == 'keyboard':
            fields = value.split(',', 4)
            if len(fields) == 5:
                profiles.append(profile(*[fields[0], fields[4], fields[1], fields[2], fields[3]]))
        elif key:
            values[key] = value
    if not profiles:
        profiles = [profile(None, 'Default keyboard', 'vi', 'grid4x8' if values.get('input') == '1' else 'ascii+',
                            'quốc ngữ' if values.get('output') == '1' else 'sieuviet'),
                    profile(None, 'English', 'en', 'qwerty', 'literal')]
    active = values.get('active')
    try:
        seconds = float(values.get('shiftTapSeconds', '0.2'))
    except ValueError:
        seconds = 0.2
    return {'profiles': profiles,
            'activeID': active if any(item['id'] == active for item in profiles) else profiles[0]['id'],
            'interfaceLanguage': interface_language(values.get('language')), 'shiftTapSeconds': seconds}


def save(state):
    profiles = [profile(str(item.get('id') or ''), str(item.get('name', '')).replace('\n', ' '), item.get('language'),
                        item.get('inputType'), item.get('outputType')) for item in state.get('profiles', [])]
    if not profiles:
        return
    active = state.get('activeID') if any(item['id'] == state.get('activeID') for item in profiles) else profiles[0]['id']
    text = f"version=2\nlanguage={interface_language(state.get('interfaceLanguage'))}\nactive={active}\n"
    text += f"shiftTapSeconds={float(state.get('shiftTapSeconds', 0.2))}\n"
    text += ''.join(f"keyboard={item['id']},{item['language']},{item['inputType']},{item['outputType']},{item['name']}\n" for item in profiles)
    temporary = None
    try:
        path.parent.mkdir(parents=True, exist_ok=True)
        with tempfile.NamedTemporaryFile(mode='w', dir=path.parent, delete=False, encoding='utf-8') as file:
            temporary = file.name
            file.write(text)
        os.replace(temporary, path)
    except OSError:
        if temporary:
            Path(temporary).unlink(missing_ok=True)
        language = interface_language(state.get('interfaceLanguage'))
        dialog = Gtk.MessageDialog(transient_for=window, modal=True, message_type=Gtk.MessageType.ERROR,
                                   buttons=Gtk.ButtonsType.OK, text=catalog['copy']['saveError'].get(language, catalog['copy']['saveError']['en']))
        dialog.format_secondary_text(catalog['copy']['saveErrorHelp'].get(language, catalog['copy']['saveErrorHelp']['en']))
        dialog.run()
        dialog.destroy()


types = {'.html': 'text/html', '.js': 'text/javascript', '.css': 'text/css', '.json': 'application/json',
         '.svg': 'image/svg+xml', '.png': 'image/png', '.woff2': 'font/woff2',
         '.wasm': 'application/wasm', '.txt': 'text/plain; charset=utf-8'}


def serve(request):
    """Serve the bundled UI on sieuviet://app/ so its ES modules load."""
    relative = request.get_path().lstrip('/') or 'index.html'
    file = (web_root / relative).resolve()
    if web_root not in file.parents or not file.is_file():
        request.finish_error(GLib.Error.new_literal(Gio.io_error_quark(), 'Not found', Gio.IOErrorEnum.NOT_FOUND))
        return
    data = file.read_bytes()
    request.finish(Gio.MemoryInputStream.new_from_bytes(GLib.Bytes.new(data)), len(data), types.get(file.suffix, 'application/octet-stream'))


def received(_manager, result):
    value = result.get_js_value() if hasattr(result, 'get_js_value') else result
    try:
        message = json.loads(value.to_json(0))
    except (TypeError, ValueError):
        return
    if isinstance(message, dict) and message.get('type') == 'state' and isinstance(message.get('state'), dict):
        save(message['state'])


window = Gtk.Window(title=catalog['brand']['name'])
window.set_icon_from_file(str(share / 'icons/hicolor/scalable/apps/sieuviet.svg'))
window.set_default_size(900, 720)
context = WebKit2.WebContext.get_default()
context.get_security_manager().register_uri_scheme_as_secure('sieuviet')
context.register_uri_scheme('sieuviet', serve)
manager = WebKit2.UserContentManager()
manager.register_script_message_handler('sieuviet')
manager.connect('script-message-received::sieuviet', received)
manager.add_script(WebKit2.UserScript.new(
    'window.__SIEUVIET_NATIVE__ = ' + json.dumps({'platform': 'linux', 'state': load()}) + ';',
    WebKit2.UserContentInjectedFrames.TOP_FRAME, WebKit2.UserScriptInjectionTime.START, None, None))
view = WebKit2.WebView.new_with_user_content_manager(manager)
window.add(view)
view.load_uri('sieuviet://app/index.html#keyboards')
window.connect('destroy', Gtk.main_quit)
window.show_all()
Gtk.main()
