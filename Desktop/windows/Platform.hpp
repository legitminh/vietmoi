#pragma once
#include "Settings.hpp"
#include <shlobj.h>
#include <fstream>

namespace sv {
inline std::filesystem::path modulePath(HMODULE module) {
    std::wstring value(32768, L'\0');
    const auto count = GetModuleFileNameW(module, value.data(), static_cast<DWORD>(value.size()));
    if (!count || count >= value.size()) throw std::runtime_error("Cannot resolve Sieuviet module path");
    value.resize(count); return value;
}
inline std::filesystem::path windowsSettingsPath() {
    PWSTR path = nullptr;
    if (FAILED(SHGetKnownFolderPath(FOLDERID_RoamingAppData, 0, nullptr, &path))) throw std::runtime_error("Cannot resolve AppData");
    std::filesystem::path result = std::filesystem::path(path) / L"Sieuviet/settings.conf";
    CoTaskMemFree(path); return result;
}
inline std::wstring wide(const std::string &text) {
    if (text.empty()) return {};
    int count = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, text.data(), static_cast<int>(text.size()), nullptr, 0);
    if (!count) throw std::runtime_error("Invalid UTF-8 engine text");
    std::wstring result(count, 0);
    MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, text.data(), static_cast<int>(text.size()), result.data(), count); return result;
}
template<class T> class Com {
    T *value_ = nullptr;
public:
    Com() = default;
    explicit Com(T *value) : value_(value) { if (value_) value_->AddRef(); }
    Com(const Com &) = delete;
    Com &operator=(const Com &) = delete;
    ~Com() { reset(); }
    void reset() { if (value_) value_->Release(); value_ = nullptr; }
    T **put() { reset(); return &value_; }
    T *get() const { return value_; }
    T *operator->() const { return value_; }
    explicit operator bool() const { return value_ != nullptr; }
    void attach(T *value) { reset(); value_ = value; }
};
}
