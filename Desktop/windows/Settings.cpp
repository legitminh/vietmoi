#include "Platform.hpp"
#include "Design.hpp"

namespace {
HWND inputBox, outputBox, languageBox, message, saveButton;
std::string language = "vi";
std::vector<std::pair<HWND,std::string>> labels;
HFONT font;
std::wstring text(const std::string &key) { return sv::wide(sv::design::text(key,language)); }
void translate() {
    for (auto &[label,key] : labels) SetWindowTextW(label,text(key).c_str());
    SetWindowTextW(message,text("settingsHelp").c_str());SetWindowTextW(saveButton,text("save").c_str());
}
LRESULT CALLBACK procedure(HWND window, UINT event, WPARAM w, LPARAM l) {
    if (event == WM_CREATE) {
        auto settings=sv::loadSettings(sv::windowsSettingsPath());language=settings.language;
        auto label=[window](const char *key,int y,int height=22) {
            auto control=CreateWindowW(L"STATIC",text(key).c_str(),WS_CHILD|WS_VISIBLE,20,y,510,height,window,nullptr,nullptr,nullptr);
            labels.emplace_back(control,key);
        };
        label("keyboardSettings",15);label("inputLabel",50);
        inputBox=CreateWindowW(L"COMBOBOX",L"",WS_CHILD|WS_VISIBLE|WS_TABSTOP|CBS_DROPDOWNLIST,20,75,510,180,window,nullptr,nullptr,nullptr);
        for (auto value:{L"ASCII+",L"Grid"}) SendMessageW(inputBox,CB_ADDSTRING,0,reinterpret_cast<LPARAM>(value));
        SendMessageW(inputBox,CB_SETCURSEL,settings.input,0);
        label("outputLabel",115);
        outputBox=CreateWindowW(L"COMBOBOX",L"",WS_CHILD|WS_VISIBLE|WS_TABSTOP|CBS_DROPDOWNLIST,20,140,510,180,window,nullptr,nullptr,nullptr);
        for (auto value:{L"siêu việt",L"Quốc ngữ"}) SendMessageW(outputBox,CB_ADDSTRING,0,reinterpret_cast<LPARAM>(value));
        SendMessageW(outputBox,CB_SETCURSEL,settings.output,0);
        label("language",180);
        languageBox=CreateWindowW(L"COMBOBOX",L"",WS_CHILD|WS_VISIBLE|WS_TABSTOP|CBS_DROPDOWNLIST,20,205,510,180,window,reinterpret_cast<HMENU>(2),nullptr,nullptr);
        for (auto value:{L"Tiếng Việt",L"English"}) SendMessageW(languageBox,CB_ADDSTRING,0,reinterpret_cast<LPARAM>(value));
        SendMessageW(languageBox,CB_SETCURSEL,language=="en",0);
        saveButton=CreateWindowW(L"BUTTON",text("save").c_str(),WS_CHILD|WS_VISIBLE|WS_TABSTOP|BS_DEFPUSHBUTTON,20,250,100,30,window,reinterpret_cast<HMENU>(1),nullptr,nullptr);
        message=CreateWindowW(L"STATIC",text("settingsHelp").c_str(),WS_CHILD|WS_VISIBLE,20,295,510,90,window,nullptr,nullptr,nullptr);
        label("windowsPracticeHelp",390,38);
        CreateWindowExW(WS_EX_CLIENTEDGE,L"EDIT",L"",WS_CHILD|WS_VISIBLE|WS_TABSTOP|ES_MULTILINE|ES_AUTOVSCROLL|WS_VSCROLL,20,435,510,120,window,nullptr,nullptr,nullptr);
        label("shiftLimitHelp",570,55);
        font=CreateFontW(-15,0,0,0,FW_NORMAL,FALSE,FALSE,FALSE,DEFAULT_CHARSET,OUT_DEFAULT_PRECIS,CLIP_DEFAULT_PRECIS,DEFAULT_QUALITY,FIXED_PITCH,L"Consolas");
        EnumChildWindows(window,[](HWND child,LPARAM)->BOOL { SendMessageW(child,WM_SETFONT,reinterpret_cast<WPARAM>(font),TRUE);return TRUE; },0);
        return 0;
    }
    if (event==WM_COMMAND && LOWORD(w)==2 && HIWORD(w)==CBN_SELCHANGE) { language=SendMessageW(languageBox,CB_GETCURSEL,0,0)==1?"en":"vi";translate();return 0; }
    if (event==WM_COMMAND && LOWORD(w)==1) {
        try {
            auto path=sv::windowsSettingsPath();std::filesystem::create_directories(path.parent_path());
            auto temporary=path;temporary+=L".tmp";
            std::ofstream file(temporary,std::ios::trunc);
            file<<"version=1\ninput="<<(SendMessageW(inputBox,CB_GETCURSEL,0,0)==1?1:0)
                <<"\noutput="<<(SendMessageW(outputBox,CB_GETCURSEL,0,0)==1?1:0)<<"\nlanguage="<<language<<'\n';
            file.close();if (!file || !MoveFileExW(temporary.c_str(),path.c_str(),MOVEFILE_REPLACE_EXISTING|MOVEFILE_WRITE_THROUGH)) throw std::runtime_error("Save failed");
            SetWindowTextW(message,text("saved").c_str());
        } catch (...) { SetWindowTextW(message,text("saveError").c_str()); }
        return 0;
    }
    if (event==WM_DESTROY) { if (font) DeleteObject(font);PostQuitMessage(0);return 0; }
    return DefWindowProcW(window,event,w,l);
}
}
int WINAPI wWinMain(HINSTANCE instance,HINSTANCE,PWSTR,int) {
    CoInitializeEx(nullptr,COINIT_APARTMENTTHREADED);
    WNDCLASSW klass{};klass.lpfnWndProc=procedure;klass.hInstance=instance;klass.lpszClassName=L"SieuvietSettings";
    klass.hCursor=LoadCursorW(nullptr,IDC_ARROW);klass.hbrBackground=reinterpret_cast<HBRUSH>(COLOR_WINDOW+1);RegisterClassW(&klass);
    auto window=CreateWindowW(klass.lpszClassName,L"siêu việt",WS_OVERLAPPEDWINDOW,CW_USEDEFAULT,CW_USEDEFAULT,570,680,nullptr,nullptr,instance,nullptr);
    if (!window) return 1;
    ShowWindow(window,SW_SHOW);MSG event;
    while (GetMessageW(&event,nullptr,0,0)>0) { if (!IsDialogMessageW(window,&event)) { TranslateMessage(&event);DispatchMessageW(&event); } }
    CoUninitialize();return 0;
}
