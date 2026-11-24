#include "Platform.hpp"
#include "Design.hpp"
#include "TsfCompat.hpp"
// InputScope GUIDs are not supplied by every Windows SDK's uuid.lib.
// Instantiate the SDK definitions here for both MSVC and LLVM-MinGW.
#include <initguid.h>
#include <inputscope.h>
#include <functional>
#include <atomic>
#include <chrono>

namespace {
const CLSID ServiceID = {0x622e30dd,0x8af7,0x46f0,{0x99,0x7e,0x50,0xae,0x66,0x7a,0x8e,0x41}};
const GUID ProfileID = {0xa1b9d742,0x4176,0x45b0,{0xb7,0x73,0x19,0x0d,0xe6,0xca,0xba,0x96}};
constexpr LANGID Language = 0x042a;
HMODULE moduleHandle;
std::atomic<long> objects{0}, locks{0};
sv::Core &core() { static sv::Core value(sv::modulePath(moduleHandle).parent_path() / L"SieuvietEngine.dll"); return value; }

class Edit : public ITfEditSession {
    std::atomic<ULONG> references_{1}; std::function<HRESULT(TfEditCookie)> action_;
public:
    explicit Edit(std::function<HRESULT(TfEditCookie)> action) : action_(std::move(action)) { ++objects; }
    ~Edit() { --objects; }
    HRESULT STDMETHODCALLTYPE QueryInterface(REFIID iid, void **out) override {
        if (!out) return E_POINTER; *out = nullptr;
        if (iid == IID_IUnknown || iid == IID_ITfEditSession) *out = static_cast<ITfEditSession *>(this);
        if (!*out) return E_NOINTERFACE; AddRef(); return S_OK;
    }
    ULONG STDMETHODCALLTYPE AddRef() override { return ++references_; }
    ULONG STDMETHODCALLTYPE Release() override { auto result = --references_; if (!result) delete this; return result; }
    HRESULT STDMETHODCALLTYPE DoEditSession(TfEditCookie cookie) override { try { return action_(cookie); } catch (...) { return E_FAIL; } }
};

// The document owns only its TSF composition/range. Every mutation runs under a
// granted TSF edit cookie; no backspace injection, clipboard or global hook.
class Document : public sv::Document {
public:
    sv::Com<ITfContext> context; sv::Com<ITfComposition> composition;
    sv::Com<ITfRange> committed; ITfCompositionSink *sink = nullptr;
    TfClientId client = TF_CLIENTID_NULL; TfEditCookie cookie = 0;
    std::wstring original, displayed, committedText;
    bool selection(sv::Com<ITfRange> &range) {
        TF_SELECTION selected{}; ULONG fetched = 0;
        if (!context || FAILED(context->GetSelection(cookie, TF_DEFAULT_SELECTION, 1, &selected, &fetched)) || fetched != 1) return false;
        range.attach(selected.range); return true;
    }
    bool text(ITfRange *range, std::wstring &result) {
        wchar_t buffer[65536]; ULONG count = 0;
        if (FAILED(range->GetText(cookie, 0, buffer, 65536, &count)) || count >= 65536) return false;
        result.assign(buffer, count); return true;
    }
    bool caretAtEnd(ITfRange *range) {
        sv::Com<ITfRange> caret; if (!selection(caret)) return false;
        BOOL empty = FALSE, same = FALSE;
        return SUCCEEDED(caret->IsEmpty(cookie, &empty)) && empty && SUCCEEDED(caret->IsEqualStart(cookie, range, TF_ANCHOR_END, &same)) && same;
    }
    bool caretToEnd(ITfRange *range) {
        sv::Com<ITfRange> caret; if (FAILED(range->Clone(caret.put()))) return false;
        if (FAILED(caret->Collapse(cookie, TF_ANCHOR_END))) return false;
        TF_SELECTION selected{caret.get(), {TF_AE_NONE, FALSE}}; return SUCCEEDED(context->SetSelection(cookie, 1, &selected));
    }
    void end() {
        // Release our reference before EndComposition calls the sink back.
        if (composition) { auto *value = composition.get(); value->AddRef(); composition.reset(); value->EndComposition(cookie); value->Release(); }
        original.clear(); displayed.clear();
    }
    bool preedit(const std::string &value) override {
        auto replacement = sv::wide(value); sv::Com<ITfRange> range;
        if (!composition) {
            if (!selection(range) || !text(range.get(), original)) return false;
            sv::Com<ITfContextComposition> owner;
            if (FAILED(context->QueryInterface(IID_ITfContextComposition, reinterpret_cast<void **>(owner.put()))) ||
                FAILED(owner->StartComposition(cookie, range.get(), sink, composition.put())) || !composition) return false;
        }
        if (FAILED(composition->GetRange(range.put())) || FAILED(range->SetText(cookie, 0, replacement.data(), static_cast<LONG>(replacement.size())))) return false;
        committed.reset(); committedText.clear(); displayed = replacement; return caretToEnd(range.get());
    }
    bool commit(const std::string &value) override {
        auto replacement = sv::wide(value); sv::Com<ITfRange> range;
        if (composition) { if (FAILED(composition->GetRange(range.put()))) return false; }
        else if (!selection(range)) return false;
        if (FAILED(range->SetText(cookie, 0, replacement.data(), static_cast<LONG>(replacement.size())))) return false;
        const bool moved = caretToEnd(range.get());
        range->Clone(committed.put()); committedText = replacement; end(); return moved;
    }
    bool cancel() override {
        if (!composition) return true;
        sv::Com<ITfRange> range;
        if (FAILED(composition->GetRange(range.put())) || FAILED(range->SetText(cookie, 0, original.data(), static_cast<LONG>(original.size())))) return false;
        caretToEnd(range.get()); end(); committed.reset(); committedText.clear(); return true;
    }
    bool clearVerified(const std::string &value) override {
        if (!committed || committedText != sv::wide(value) || !caretAtEnd(committed.get())) return false;
        std::wstring actual;
        if (!text(committed.get(), actual) || actual != committedText) return false;
        if (FAILED(committed->SetText(cookie, 0, L"", 0))) return false;
        caretToEnd(committed.get()); committed.reset(); committedText.clear(); return true;
    }
    bool unchanged() {
        sv::Com<ITfRange> range; std::wstring actual;
        if (composition) return SUCCEEDED(composition->GetRange(range.put())) && caretAtEnd(range.get()) && text(range.get(), actual) && actual == displayed;
        if (committed) return caretAtEnd(committed.get()) && text(committed.get(), actual) && actual == committedText;
        return true;
    }
    void detach() {
        // A focus/caret change must never replay a pending word at the new caret.
        // End the old composition asynchronously while preserving its visible text.
        if (composition && context) {
            auto *old = composition.get(); old->AddRef();
            auto keep = std::shared_ptr<ITfComposition>(old, [](ITfComposition *p) { p->Release(); });
            auto *edit = new Edit([keep](TfEditCookie cookie) { return keep->EndComposition(cookie); });
            composition.reset(); HRESULT outcome = E_FAIL;
            context->RequestEditSession(client, edit, TF_ES_ASYNC | TF_ES_READWRITE, &outcome); edit->Release();
        }
        committed.reset(); original.clear(); displayed.clear(); committedText.clear(); context.reset();
    }
};

class Service : public ITfTextInputProcessorEx, public ITfKeyEventSink,
                public ITfThreadMgrEventSink, public ITfTextEditSink, public ITfCompositionSink {
    std::atomic<ULONG> references_{1}; sv::Com<ITfThreadMgr> manager_;
    sv::Com<ITfKeystrokeMgr> keys_; DWORD threadSink_ = TF_INVALID_COOKIE, editSink_ = TF_INVALID_COOKIE;
    TfClientId client_ = TF_CLIENTID_NULL; Document document_; std::unique_ptr<sv::Session> session_;
    bool editing_ = false; std::string keyboard_; HWND guide_ = nullptr; HFONT font_ = nullptr;
    bool disabled() {
        sv::Com<ITfCompartmentMgr> manager;
        if (FAILED(document_.context->QueryInterface(IID_ITfCompartmentMgr, reinterpret_cast<void **>(manager.put())))) return false;
        for (const auto *id : {&GUID_COMPARTMENT_KEYBOARD_DISABLED, &GUID_COMPARTMENT_EMPTYCONTEXT}) {
            sv::Com<ITfCompartment> compartment; VARIANT value; VariantInit(&value);
            bool blocked = SUCCEEDED(manager->GetCompartment(*id, compartment.put())) &&
                SUCCEEDED(compartment->GetValue(&value)) && value.vt == VT_I4 && value.lVal != 0;
            VariantClear(&value); if (blocked) return true;
        }
        sv::Com<ITfRange> range; sv::Com<ITfProperty> property;
        if (document_.selection(range) && SUCCEEDED(document_.context->GetProperty(GUID_PROP_INPUTSCOPE, property.put()))) {
            VARIANT value; VariantInit(&value);
            if (SUCCEEDED(property->GetValue(document_.cookie, range.get(), &value)) && value.vt == VT_UNKNOWN && value.punkVal) {
                sv::Com<ITfInputScope> scope;
                if (SUCCEEDED(value.punkVal->QueryInterface(IID_ITfInputScope, reinterpret_cast<void **>(scope.put())))) {
                    InputScope *scopes = nullptr; UINT count = 0;
                    if (SUCCEEDED(scope->GetInputScopes(&scopes, &count))) {
                        bool blocked = false; for (UINT i = 0; i < count; ++i) blocked |= scopes[i] == IS_PASSWORD;
                        CoTaskMemFree(scopes); if (blocked) { VariantClear(&value); return true; }
                    }
                }
            }
            VariantClear(&value);
        }
        return false;
    }
    void hide() { if (guide_) ShowWindow(guide_, SW_HIDE); }
    void guide() {
        if (!session_ || session_->ascii() || !document_.context) { hide(); return; }
        if (!guide_) {
            guide_ = CreateWindowExW(WS_EX_NOACTIVATE | WS_EX_TOOLWINDOW | WS_EX_TOPMOST, L"STATIC", L"", WS_POPUP | WS_BORDER | SS_LEFT | SS_NOPREFIX,
                                    0, 0, 920, 240, nullptr, nullptr, moduleHandle, nullptr);
            if (!guide_) return;
            font_ = CreateFontW(-16,0,0,0,FW_NORMAL,FALSE,FALSE,FALSE,DEFAULT_CHARSET,OUT_DEFAULT_PRECIS,CLIP_DEFAULT_PRECIS,DEFAULT_QUALITY,FIXED_PITCH,L"Consolas");
            SendMessageW(guide_, WM_SETFONT, reinterpret_cast<WPARAM>(font_), TRUE);
        }
        sv::Com<ITfContextView> view; sv::Com<ITfRange> range; RECT rect{}; BOOL clipped = FALSE;
        if (!document_.selection(range) || FAILED(document_.context->GetActiveView(view.put())) ||
            FAILED(view->GetTextExt(document_.cookie, range.get(), &rect, &clipped))) { hide(); return; }
        auto text = sv::wide(session_->guide()); SetWindowTextW(guide_, text.c_str());
        RECT work{}; SystemParametersInfoW(SPI_GETWORKAREA, 0, &work, 0);
        HDC dc = GetDC(guide_); auto previous = SelectObject(dc,font_); RECT bounds{};
        DrawTextW(dc,text.c_str(),static_cast<int>(text.size()),&bounds,DT_CALCRECT | DT_NOPREFIX);
        SelectObject(dc,previous); ReleaseDC(guide_,dc);
        int width = std::min(bounds.right + 16, work.right - work.left), height = std::min(bounds.bottom + 8, work.bottom - work.top);
        int x = std::max(work.left, std::min(rect.left, work.right - width));
        int y = rect.bottom + height <= work.bottom ? rect.bottom : std::max(work.top, rect.top - height);
        SetWindowPos(guide_, HWND_TOPMOST, x, y, width, height, SWP_NOACTIVATE | SWP_SHOWWINDOW);
    }
    void detach() {
        hide(); if (session_) { keyboard_ = session_->keyboard().id; session_->invalidate(); session_.reset(); }
        if (document_.context && editSink_ != TF_INVALID_COOKIE) {
            sv::Com<ITfSource> source;
            if (SUCCEEDED(document_.context->QueryInterface(IID_ITfSource, reinterpret_cast<void **>(source.put())))) source->UnadviseSink(editSink_);
        }
        editSink_ = TF_INVALID_COOKIE; document_.detach();
    }
    void focus(ITfDocumentMgr *document) {
        detach(); if (!document) return;
        if (FAILED(document->GetTop(document_.context.put())) || !document_.context) return;
        document_.client = client_; document_.sink = this;
        try { session_ = std::make_unique<sv::Session>(core(), document_, sv::loadSettings(sv::windowsSettingsPath()), keyboard_); }
        catch (...) { detach(); return; }
        sv::Com<ITfSource> source;
        if (SUCCEEDED(document_.context->QueryInterface(IID_ITfSource, reinterpret_cast<void **>(source.put()))))
            source->AdviseSink(IID_ITfTextEditSink, static_cast<ITfTextEditSink *>(this), &editSink_);
    }
    HRESULT key(ITfContext *context, WPARAM vk, LPARAM flags, bool down, BOOL *eaten) {
        if (!eaten) return E_POINTER; *eaten = FALSE;
        if (!session_ || context != document_.context.get()) return S_OK;
        auto scan = static_cast<unsigned>((flags >> 16) & 0xff);
        if (!scan) scan = MapVirtualKeyW(static_cast<UINT>(vk), MAPVK_VK_TO_VSC);
        auto usage = sv::evdevUsage(scan);
        if (flags & (1L << 24)) {
            if (scan == 0x1d) usage = 0xe4; else if (scan == 0x38) usage = 0xe6;
            else if (scan == 0x53) usage = 0x4c; else usage = static_cast<uint16_t>(0x2000 + scan);
        }
        if (vk == VK_LWIN) usage = 0xe3; if (vk == VK_RWIN) usage = 0xe7;
        const bool shift = (GetKeyState(VK_SHIFT) & 0x8000) != 0;
        const bool shortcut = ((GetKeyState(VK_CONTROL) | GetKeyState(VK_MENU) | GetKeyState(VK_LWIN) | GetKeyState(VK_RWIN)) & 0x8000) != 0;
        sv::Key input{usage, down, down && !!(flags & (1L << 30)), shift, shortcut, false,
            std::chrono::duration<double>(std::chrono::steady_clock::now().time_since_epoch()).count()};
        auto *edit = new Edit([this,input,eaten](TfEditCookie cookie) mutable {
            document_.cookie = cookie; editing_ = true;
            if (disabled()) { session_->invalidate(); document_.cancel(); hide(); editing_ = false; return S_OK; }
            sv::Com<ITfRange> selected; BOOL empty = TRUE;
            if (document_.selection(selected)) selected->IsEmpty(cookie, &empty);
            input.selection = !empty;
            try { *eaten = session_->key(input); guide(); }
            catch (...) { session_->invalidate(); document_.cancel(); hide(); }
            editing_ = false; return S_OK;
        });
        HRESULT outcome = E_FAIL;
        context->RequestEditSession(client_, edit, TF_ES_SYNC | TF_ES_READWRITE, &outcome);
        edit->Release(); return S_OK;
    }
public:
    Service() { ++objects; }
    ~Service() { Deactivate(); if (guide_) DestroyWindow(guide_); if (font_) DeleteObject(font_); --objects; }
    HRESULT STDMETHODCALLTYPE QueryInterface(REFIID iid, void **out) override {
        if (!out) return E_POINTER; *out = nullptr;
        if (iid == IID_IUnknown || iid == IID_ITfTextInputProcessor || iid == IID_ITfTextInputProcessorEx) *out = static_cast<ITfTextInputProcessorEx *>(this);
        else if (iid == IID_ITfKeyEventSink) *out = static_cast<ITfKeyEventSink *>(this);
        else if (iid == IID_ITfThreadMgrEventSink) *out = static_cast<ITfThreadMgrEventSink *>(this);
        else if (iid == IID_ITfTextEditSink) *out = static_cast<ITfTextEditSink *>(this);
        else if (iid == IID_ITfCompositionSink) *out = static_cast<ITfCompositionSink *>(this);
        if (!*out) return E_NOINTERFACE; AddRef(); return S_OK;
    }
    ULONG STDMETHODCALLTYPE AddRef() override { return ++references_; }
    ULONG STDMETHODCALLTYPE Release() override { auto result = --references_; if (!result) delete this; return result; }
    HRESULT STDMETHODCALLTYPE Activate(ITfThreadMgr *manager, TfClientId client) override { return ActivateEx(manager, client, 0); }
    HRESULT STDMETHODCALLTYPE ActivateEx(ITfThreadMgr *manager, TfClientId client, DWORD) override {
        if (!manager) return E_INVALIDARG;
        try { (void)core(); } catch (const std::exception &error) { OutputDebugStringA(error.what()); return E_FAIL; }
        Deactivate(); manager_.attach(manager); manager->AddRef(); client_ = client;
        if (FAILED(manager->QueryInterface(IID_ITfKeystrokeMgr, reinterpret_cast<void **>(keys_.put()))) ||
            FAILED(keys_->AdviseKeyEventSink(client, this, TRUE))) { Deactivate(); return E_FAIL; }
        sv::Com<ITfSource> source;
        if (FAILED(manager->QueryInterface(IID_ITfSource, reinterpret_cast<void **>(source.put()))) ||
            FAILED(source->AdviseSink(IID_ITfThreadMgrEventSink, static_cast<ITfThreadMgrEventSink *>(this), &threadSink_))) { Deactivate(); return E_FAIL; }
        sv::Com<ITfDocumentMgr> document; manager->GetFocus(document.put()); focus(document.get()); return S_OK;
    }
    HRESULT STDMETHODCALLTYPE Deactivate() override {
        detach();
        if (keys_) keys_->UnadviseKeyEventSink(client_); keys_.reset();
        if (manager_ && threadSink_ != TF_INVALID_COOKIE) {
            sv::Com<ITfSource> source;
            if (SUCCEEDED(manager_->QueryInterface(IID_ITfSource, reinterpret_cast<void **>(source.put())))) source->UnadviseSink(threadSink_);
        }
        threadSink_ = TF_INVALID_COOKIE; manager_.reset(); client_ = TF_CLIENTID_NULL; return S_OK;
    }
    HRESULT STDMETHODCALLTYPE OnSetFocus(BOOL foreground) override { if (!foreground) hide(); return S_OK; }
    HRESULT STDMETHODCALLTYPE OnTestKeyDown(ITfContext *context, WPARAM, LPARAM, BOOL *eaten) override { if (!eaten) return E_POINTER; *eaten = session_ && context == document_.context.get(); return S_OK; }
    HRESULT STDMETHODCALLTYPE OnTestKeyUp(ITfContext *context, WPARAM key, LPARAM flags, BOOL *eaten) override { return OnTestKeyDown(context,key,flags,eaten); }
    HRESULT STDMETHODCALLTYPE OnKeyDown(ITfContext *context, WPARAM keycode, LPARAM flags, BOOL *eaten) override { return key(context,keycode,flags,true,eaten); }
    HRESULT STDMETHODCALLTYPE OnKeyUp(ITfContext *context, WPARAM keycode, LPARAM flags, BOOL *eaten) override { return key(context,keycode,flags,false,eaten); }
    HRESULT STDMETHODCALLTYPE OnPreservedKey(ITfContext *, REFGUID, BOOL *eaten) override { if (eaten) *eaten = FALSE; return S_OK; }
    HRESULT STDMETHODCALLTYPE OnInitDocumentMgr(ITfDocumentMgr *) override { return S_OK; }
    HRESULT STDMETHODCALLTYPE OnUninitDocumentMgr(ITfDocumentMgr *) override { return S_OK; }
    HRESULT STDMETHODCALLTYPE OnSetFocus(ITfDocumentMgr *document, ITfDocumentMgr *) override { focus(document); return S_OK; }
    HRESULT STDMETHODCALLTYPE OnPushContext(ITfContext *) override { sv::Com<ITfDocumentMgr> document; if (manager_) manager_->GetFocus(document.put()); focus(document.get()); return S_OK; }
    HRESULT STDMETHODCALLTYPE OnPopContext(ITfContext *) override { return OnPushContext(nullptr); }
    HRESULT STDMETHODCALLTYPE OnEndEdit(ITfContext *context, TfEditCookie cookie, ITfEditRecord *) override {
        if (!editing_ && session_ && context == document_.context.get()) {
            document_.cookie = cookie;
            if (!document_.unchanged()) {
                session_->invalidate(); hide();
                // Close the old owned range; don't modify the user's new selection.
                sv::Com<ITfDocumentMgr> document; if (manager_) manager_->GetFocus(document.put()); focus(document.get());
            }
        }
        return S_OK;
    }
    HRESULT STDMETHODCALLTYPE OnCompositionTerminated(TfEditCookie, ITfComposition *composition) override {
        if (composition == document_.composition.get()) { document_.composition.reset(); if (session_) session_->invalidate(); hide(); }
        return S_OK;
    }
};

class Factory : public IClassFactory {
    std::atomic<ULONG> references_{1};
public:
    Factory() { ++objects; } ~Factory() { --objects; }
    HRESULT STDMETHODCALLTYPE QueryInterface(REFIID iid, void **out) override {
        if (!out) return E_POINTER; *out = nullptr;
        if (iid != IID_IUnknown && iid != IID_IClassFactory) return E_NOINTERFACE;
        *out = static_cast<IClassFactory *>(this); AddRef(); return S_OK;
    }
    ULONG STDMETHODCALLTYPE AddRef() override { return ++references_; }
    ULONG STDMETHODCALLTYPE Release() override { auto result = --references_; if (!result) delete this; return result; }
    HRESULT STDMETHODCALLTYPE CreateInstance(IUnknown *outer, REFIID iid, void **out) override {
        if (outer) return CLASS_E_NOAGGREGATION;
        auto *service = new Service; auto result = service->QueryInterface(iid,out); service->Release(); return result;
    }
    HRESULT STDMETHODCALLTYPE LockServer(BOOL lock) override { if (lock) ++locks; else --locks; return S_OK; }
};
std::wstring registryPath() { wchar_t id[64]; StringFromGUID2(ServiceID,id,64); return std::wstring(L"Software\\Classes\\CLSID\\") + id; }
HRESULT registration(bool add) {
    const HRESULT init = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
    sv::Com<ITfInputProcessorProfiles> profiles; sv::Com<ITfCategoryMgr> categories;
    HRESULT result = CoCreateInstance(CLSID_TF_InputProcessorProfiles,nullptr,CLSCTX_INPROC_SERVER,IID_ITfInputProcessorProfiles,reinterpret_cast<void **>(profiles.put()));
    if (SUCCEEDED(result)) result = CoCreateInstance(CLSID_TF_CategoryMgr,nullptr,CLSCTX_INPROC_SERVER,IID_ITfCategoryMgr,reinterpret_cast<void **>(categories.put()));
    if (SUCCEEDED(result) && add) {
        std::wstring path; try { path = sv::modulePath(moduleHandle).wstring(); } catch (...) { result = E_FAIL; }
        HKEY key = nullptr; auto registry = registryPath() + L"\\InprocServer32";
        if (SUCCEEDED(result)) result = HRESULT_FROM_WIN32(RegCreateKeyExW(HKEY_LOCAL_MACHINE,registry.c_str(),0,nullptr,0,KEY_WRITE,nullptr,&key,nullptr));
        if (SUCCEEDED(result)) {
            result = HRESULT_FROM_WIN32(RegSetValueExW(key,nullptr,0,REG_SZ,reinterpret_cast<const BYTE *>(path.c_str()),static_cast<DWORD>((path.size()+1)*sizeof(wchar_t))));
            if (SUCCEEDED(result)) result = HRESULT_FROM_WIN32(RegSetValueExW(key,L"ThreadingModel",0,REG_SZ,reinterpret_cast<const BYTE *>(L"Apartment"),sizeof(L"Apartment")));
            RegCloseKey(key);
        }
        if (SUCCEEDED(result)) result = profiles->Register(ServiceID);
        auto description = sv::wide(sv::design::name);
        if (SUCCEEDED(result)) result = profiles->AddLanguageProfile(ServiceID,Language,ProfileID,description.c_str(),static_cast<ULONG>(description.size()),path.c_str(),static_cast<ULONG>(path.size()),0);
        if (SUCCEEDED(result)) result = profiles->EnableLanguageProfile(ServiceID,Language,ProfileID,TRUE);
        if (SUCCEEDED(result)) result = categories->RegisterCategory(ServiceID,GUID_TFCAT_TIP_KEYBOARD,ServiceID);
        // No default profile or language preference is changed by installation.
        if (FAILED(result)) { categories->UnregisterCategory(ServiceID,GUID_TFCAT_TIP_KEYBOARD,ServiceID); profiles->Unregister(ServiceID); RegDeleteTreeW(HKEY_LOCAL_MACHINE,registryPath().c_str()); }
    } else if (SUCCEEDED(result)) {
        categories->UnregisterCategory(ServiceID,GUID_TFCAT_TIP_KEYBOARD,ServiceID);
        profiles->RemoveLanguageProfile(ServiceID,Language,ProfileID); profiles->Unregister(ServiceID);
        auto error = RegDeleteTreeW(HKEY_LOCAL_MACHINE,registryPath().c_str());
        if (error != ERROR_FILE_NOT_FOUND) result = HRESULT_FROM_WIN32(error);
    }
    profiles.reset(); categories.reset(); if (SUCCEEDED(init)) CoUninitialize(); return result;
}
}
extern "C" BOOL WINAPI DllMain(HINSTANCE module, DWORD reason, LPVOID) { if (reason == DLL_PROCESS_ATTACH) { moduleHandle = module; DisableThreadLibraryCalls(module); } return TRUE; }
extern "C" HRESULT WINAPI DllGetClassObject(REFCLSID clsid, REFIID iid, void **out) {
    if (clsid != ServiceID) return CLASS_E_CLASSNOTAVAILABLE;
    auto *factory = new Factory; auto result = factory->QueryInterface(iid,out); factory->Release(); return result;
}
extern "C" HRESULT WINAPI DllCanUnloadNow() { return objects == 0 && locks == 0 ? S_OK : S_FALSE; }
extern "C" HRESULT WINAPI DllRegisterServer() { return registration(true); }
extern "C" HRESULT WINAPI DllUnregisterServer() { return registration(false); }
