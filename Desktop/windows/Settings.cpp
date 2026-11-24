#include "Platform.hpp"
#include "Design.hpp"
#include <random>

// The managed keyboard list, the same as every other siêu việt app: each keyboard
// has a language with its own inputs and outputs, and a left Shift tap moves to
// the next keyboard. Every change is saved at once.
namespace {
enum Control { List = 10, AddVietnamese, AddEnglish, Select, Remove, Language = 20, Input, Output, Interface, Mode };
HWND list, languageBox, inputBox, modeBox, outputBox, interfaceBox, message;
sv::Settings settings;
std::vector<std::pair<HWND,std::string>> labels;
std::vector<std::pair<HWND,std::string>> buttons;
HFONT font;
bool filling = false;
std::wstring text(const std::string &key) { return sv::wide(sv::design::text(key,settings.language)); }
std::string displayName(const sv::Keyboard &keyboard) {
    if (keyboard.name == "Default keyboard") return sv::design::text("defaultKeyboard",settings.language);
    if (keyboard.name == "English") return sv::design::text("englishKeyboard",settings.language);
    return keyboard.name;
}
std::string identifier() {
    std::random_device device; std::uniform_int_distribution<int> digit(0,15); const char *hex = "0123456789ABCDEF";
    std::string result;
    for (int index = 0; index < 32; ++index) {
        int value = digit(device);
        if (index == 12) value = 4; else if (index == 16) value = 8 | (value & 3);
        if (index == 8 || index == 12 || index == 16 || index == 20) result += '-';
        result += hex[value];
    }
    return result;
}
int selected() { auto index = static_cast<int>(SendMessageW(list,LB_GETCURSEL,0,0)); return index < 0 ? 0 : index; }
void combo(HWND box,std::initializer_list<std::wstring> values,int selection) {
    SendMessageW(box,CB_RESETCONTENT,0,0);
    for (auto &value:values) SendMessageW(box,CB_ADDSTRING,0,reinterpret_cast<LPARAM>(value.c_str()));
    SendMessageW(box,CB_SETCURSEL,selection,0);
}
// Show the list and the selected keyboard's language, input layout, input mode and output.
void fill(int selection) {
    filling = true;
    for (auto &[label,key] : labels) SetWindowTextW(label,text(key).c_str());
    for (auto &[button,key] : buttons) SetWindowTextW(button,text(key).c_str());
    SendMessageW(list,LB_RESETCONTENT,0,0);
    for (auto &keyboard : settings.keyboards) {
        auto row = displayName(keyboard) + (keyboard.id == settings.active ? "  ✓ " + sv::design::text("selected",settings.language) : "");
        row += keyboard.literal() ? "  · English" : std::string("  · ") + (keyboard.input ? "grid4x8" : "ASCII+") + " · " + (keyboard.mode ? "quốc ngữ" : "siêu việt") + " → " + (keyboard.output ? "quốc ngữ" : "siêu việt");
        SendMessageW(list,LB_ADDSTRING,0,reinterpret_cast<LPARAM>(sv::wide(row).c_str()));
    }
    selection = std::min<int>(selection,static_cast<int>(settings.keyboards.size()) - 1);
    SendMessageW(list,LB_SETCURSEL,selection,0);
    auto &keyboard = settings.keyboards[selection];
    combo(languageBox,{L"Tiếng Việt",L"English"},keyboard.literal());
    if (keyboard.literal()) { combo(inputBox,{L"QWERTY"},0); combo(modeBox,{L"siêu việt"},0); combo(outputBox,{text("literalOutput")},0); }
    else { combo(inputBox,{L"ASCII+",L"grid4x8"},keyboard.input); combo(modeBox,{L"siêu việt",L"quốc ngữ"},keyboard.mode);
           combo(outputBox,{L"siêu việt",L"quốc ngữ"},keyboard.output); }
    EnableWindow(inputBox,!keyboard.literal()); EnableWindow(modeBox,!keyboard.literal()); EnableWindow(outputBox,!keyboard.literal());
    combo(interfaceBox,{L"Tiếng Việt",L"English",L"中文"},settings.language == "en" ? 1 : settings.language == "zh" ? 2 : 0);
    SetWindowTextW(message,text("settingsHelp").c_str());
    filling = false;
}
void save() {
    try {
        auto path=sv::windowsSettingsPath();std::filesystem::create_directories(path.parent_path());
        auto temporary=path;temporary+=L".tmp";
        std::ofstream file(temporary,std::ios::trunc|std::ios::binary);
        file<<sv::formatSettings(settings);
        file.close();if (!file || !MoveFileExW(temporary.c_str(),path.c_str(),MOVEFILE_REPLACE_EXISTING|MOVEFILE_WRITE_THROUGH)) throw std::runtime_error("Save failed");
    } catch (...) { SetWindowTextW(message,(text("saveError") + L"\r\n" + text("saveErrorHelp")).c_str()); }
}
void add(const std::string &language) {
    sv::Keyboard keyboard{identifier(),"",language};
    if (language == "en") keyboard.name = "English";
    else {
        for (int number = 2;; ++number) {
            auto name = sv::design::text("keyboardNumber",settings.language);
            name.replace(name.find("{number}"),8,std::to_string(number));
            bool used = false;
            for (auto &other : settings.keyboards) used = used || other.name == name;
            if (!used) { keyboard.name = name; break; }
        }
    }
    settings.keyboards.push_back(keyboard); save(); fill(static_cast<int>(settings.keyboards.size()) - 1);
}
HWND control(HWND window,const wchar_t *type,DWORD style,int x,int y,int width,int height,int id=0) {
    return CreateWindowW(type,L"",WS_CHILD|WS_VISIBLE|style,x,y,width,height,window,reinterpret_cast<HMENU>(static_cast<INT_PTR>(id)),nullptr,nullptr);
}
LRESULT CALLBACK procedure(HWND window, UINT event, WPARAM w, LPARAM l) {
    if (event == WM_CREATE) {
        settings=sv::loadSettings(sv::windowsSettingsPath());
        if (settings.keyboards.empty()) {
            // Version 1 snapshot: keep its Vietnamese keyboard and add English.
            settings.keyboards={{identifier(),"Default keyboard","vi",settings.input,settings.output},{identifier(),"English","en"}};
        }
        bool found = false;
        for (auto &keyboard : settings.keyboards) found = found || keyboard.id == settings.active;
        if (!found) settings.active = settings.keyboards.front().id;
        auto label=[window](const char *key,int y,int height=22) { labels.emplace_back(control(window,L"STATIC",0,20,y,510,height),key); };
        auto button=[window](const char *key,int x,int y,int width,int id) { buttons.emplace_back(control(window,L"BUTTON",WS_TABSTOP,x,y,width,30,id),key); };
        label("keyboardsHeading",15);label("keyboardsHelp",38,40);
        list=CreateWindowExW(WS_EX_CLIENTEDGE,L"LISTBOX",L"",WS_CHILD|WS_VISIBLE|WS_TABSTOP|WS_VSCROLL|LBS_NOTIFY,20,80,510,120,window,reinterpret_cast<HMENU>(List),nullptr,nullptr);
        button("addKeyboard",20,208,150,AddVietnamese);button("englishKeyboard",176,208,110,AddEnglish);
        button("select",292,208,100,Select);button("removeKeyboard",398,208,132,Remove);
        label("keyboardLanguage",250);languageBox=control(window,L"COMBOBOX",WS_TABSTOP|CBS_DROPDOWNLIST,20,272,510,180,Language);
        label("inputLabel",310);inputBox=control(window,L"COMBOBOX",WS_TABSTOP|CBS_DROPDOWNLIST,20,332,510,180,Input);
        label("inputModeLabel",370);modeBox=control(window,L"COMBOBOX",WS_TABSTOP|CBS_DROPDOWNLIST,20,392,510,180,Mode);
        label("outputLabel",430);outputBox=control(window,L"COMBOBOX",WS_TABSTOP|CBS_DROPDOWNLIST,20,452,510,180,Output);
        label("language",490);interfaceBox=control(window,L"COMBOBOX",WS_TABSTOP|CBS_DROPDOWNLIST,20,512,510,180,Interface);
        message=control(window,L"STATIC",0,20,552,510,60);
        label("windowsPracticeHelp",620,38);
        CreateWindowExW(WS_EX_CLIENTEDGE,L"EDIT",L"",WS_CHILD|WS_VISIBLE|WS_TABSTOP|ES_MULTILINE|ES_AUTOVSCROLL|WS_VSCROLL,20,660,510,100,window,nullptr,nullptr,nullptr);
        label("shiftLimitHelp",770,40);
        font=CreateFontW(-15,0,0,0,FW_NORMAL,FALSE,FALSE,FALSE,DEFAULT_CHARSET,OUT_DEFAULT_PRECIS,CLIP_DEFAULT_PRECIS,DEFAULT_QUALITY,FIXED_PITCH,L"Consolas");
        EnumChildWindows(window,[](HWND child,LPARAM)->BOOL { SendMessageW(child,WM_SETFONT,reinterpret_cast<WPARAM>(font),TRUE);return TRUE; },0);
        int active = 0;
        for (size_t index = 0; index < settings.keyboards.size(); ++index) if (settings.keyboards[index].id == settings.active) active = static_cast<int>(index);
        fill(active);
        return 0;
    }
    if (event==WM_COMMAND && !filling) {
        const int id=LOWORD(w), code=HIWORD(w);
        auto &keyboard=settings.keyboards[selected()];
        if (id==List && code==LBN_SELCHANGE) { fill(selected()); return 0; }
        if (id==List && code==LBN_DBLCLK) { settings.active=keyboard.id; save(); fill(selected()); return 0; }
        if (id==AddVietnamese) { add("vi"); return 0; }
        if (id==AddEnglish) { add("en"); return 0; }
        if (id==Select) { settings.active=keyboard.id; save(); fill(selected()); return 0; }
        if (id==Remove) {
            if (settings.keyboards.size() <= 1) { SetWindowTextW(message,text("keepKeyboard").c_str()); return 0; }
            const int index=selected(); const bool active = keyboard.id == settings.active;
            settings.keyboards.erase(settings.keyboards.begin()+index);
            if (active) settings.active=settings.keyboards.front().id;
            save(); fill(index); return 0;
        }
        if (code==CBN_SELCHANGE) {
            const auto value=static_cast<int>(SendMessageW(reinterpret_cast<HWND>(l),CB_GETCURSEL,0,0));
            if (id==Language) { keyboard.language=value==1?"en":"vi"; if (keyboard.literal()) { keyboard.input=0; keyboard.mode=0; keyboard.output=0; } }
            else if (id==Input) keyboard.input=value==1;
            else if (id==Mode) keyboard.mode=value==1;
            else if (id==Output) keyboard.output=value==1;
            else if (id==Interface) settings.language=value==1?"en":value==2?"zh":"vi";
            save(); fill(selected()); return 0;
        }
    }
    if (event==WM_DESTROY) { if (font) DeleteObject(font);PostQuitMessage(0);return 0; }
    return DefWindowProcW(window,event,w,l);
}
}
int WINAPI wWinMain(HINSTANCE instance,HINSTANCE,PWSTR,int) {
    CoInitializeEx(nullptr,COINIT_APARTMENTTHREADED);
    WNDCLASSW klass{};klass.lpfnWndProc=procedure;klass.hInstance=instance;klass.lpszClassName=L"SieuvietSettings";
    klass.hCursor=LoadCursorW(nullptr,IDC_ARROW);klass.hbrBackground=reinterpret_cast<HBRUSH>(COLOR_WINDOW+1);RegisterClassW(&klass);
    auto window=CreateWindowW(klass.lpszClassName,L"siêu việt",WS_OVERLAPPEDWINDOW,CW_USEDEFAULT,CW_USEDEFAULT,570,860,nullptr,nullptr,instance,nullptr);
    if (!window) return 1;
    ShowWindow(window,SW_SHOW);MSG event;
    while (GetMessageW(&event,nullptr,0,0)>0) { if (!IsDialogMessageW(window,&event)) { TranslateMessage(&event);DispatchMessageW(&event); } }
    CoUninitialize();return 0;
}
