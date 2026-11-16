#pragma once
#include "sieuviet.h"
#include <filesystem>
#include <stdexcept>
#include <string>
#include <vector>
#ifdef _WIN32
#include <windows.h>
#else
#include <dlfcn.h>
#endif

namespace sv {
// Process-lifetime library: unloading a Swift runtime from an IME host is unsafe.
// Each engine/session still releases its own state deterministically.
class Core {
public:
    decltype(&sv_engine_create) create{};
    decltype(&sv_engine_destroy) destroy{};
    decltype(&sv_engine_dispatch) dispatch{};
    decltype(&sv_engine_dispatch_key) dispatchKey{};
    decltype(&sv_engine_wants_key) wantsKey{};
    decltype(&sv_engine_phase) phase{};
    decltype(&sv_engine_ascii) ascii{};
    decltype(&sv_engine_copy_text) copyText{};
    decltype(&sv_engine_copy_preview) copyPreview{};
    decltype(&sv_engine_copy_guide) copyGuide{};
    decltype(&sv_engine_observe_key) observe{};
    explicit Core(const std::filesystem::path &path) {
#ifdef _WIN32
        auto module = LoadLibraryExW(path.c_str(), nullptr, LOAD_LIBRARY_SEARCH_DLL_LOAD_DIR | LOAD_LIBRARY_SEARCH_DEFAULT_DIRS);
        if (!module) throw std::runtime_error("Cannot load the packaged SieuvietEngine.dll and Swift runtime");
        auto find = [module](const char *name) { return reinterpret_cast<void *>(GetProcAddress(module, name)); };
#else
        auto module = dlopen(path.c_str(), RTLD_NOW | RTLD_LOCAL);
        if (!module) throw std::runtime_error(dlerror());
        auto find = [module](const char *name) { return dlsym(module, name); };
#endif
#define SV_LOAD(member, symbol) member = reinterpret_cast<decltype(member)>(find(#symbol)); if (!member) throw std::runtime_error("Missing " #symbol)
        auto version = reinterpret_cast<decltype(&sv_engine_abi_version)>(find("sv_engine_abi_version"));
        if (!version || version() != 1) throw std::runtime_error("Unsupported Sieuviet C ABI");
        SV_LOAD(create, sv_engine_create); SV_LOAD(destroy, sv_engine_destroy); SV_LOAD(dispatch, sv_engine_dispatch);
        SV_LOAD(dispatchKey, sv_engine_dispatch_key); SV_LOAD(wantsKey, sv_engine_wants_key);
        SV_LOAD(phase, sv_engine_phase); SV_LOAD(ascii, sv_engine_ascii);
        SV_LOAD(copyText, sv_engine_copy_text); SV_LOAD(copyPreview, sv_engine_copy_preview);
        SV_LOAD(copyGuide, sv_engine_copy_guide); SV_LOAD(observe, sv_engine_observe_key);
#undef SV_LOAD
    }
    template<class Reader, class... Arguments>
    static std::string read(Reader reader, Arguments... arguments) {
        const auto size = reader(arguments..., nullptr, 0);
        if (size < 1 || size > 65536) throw std::runtime_error("Invalid engine buffer size");
        std::vector<char> buffer(static_cast<size_t>(size));
        if (reader(arguments..., buffer.data(), buffer.size()) != size) throw std::runtime_error("Engine buffer changed");
        return std::string(buffer.data(), buffer.size() - 1);
    }
};
}
