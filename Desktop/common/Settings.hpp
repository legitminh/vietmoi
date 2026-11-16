#pragma once
#include "Session.hpp"
#include <cstdlib>
#include <fstream>
#include <sstream>

namespace sv {
inline Settings loadSettings(const std::filesystem::path &path) {
    std::ifstream file(path); Settings result; std::string line;
    while (std::getline(file, line)) {
        if (line == "input=1") result.input = 1;
        else if (line == "output=1") result.output = 1;
        else if (line == "language=en") result.language = "en";
    }
    return result;
}
// Some toolkit plugins reuse an input context when moving between text fields.
// Reload changed snapshots at an idle key boundary as well as on focus, while
// never changing layout/output halfway through a word.
class SettingsFile {
    std::filesystem::path path_; Settings value_;
    std::filesystem::file_time_type modified_{}; bool loaded_ = false;
public:
    explicit SettingsFile(std::filesystem::path path) : path_(std::move(path)) {}
    Settings current() {
        std::error_code error;
        auto modified = std::filesystem::last_write_time(path_, error);
        if (!loaded_ || modified != modified_) { value_ = loadSettings(path_); modified_ = modified; loaded_ = true; }
        return value_;
    }
};
inline std::filesystem::path linuxSettingsPath() {
    if (const char *path = std::getenv("SIEUVIET_CONFIG_FILE")) return path;
    if (const char *path = std::getenv("XDG_CONFIG_HOME")) return std::filesystem::path(path) / "sieuviet/settings.conf";
    const char *home = std::getenv("HOME");
    return std::filesystem::path(home ? home : "/tmp") / ".config/sieuviet/settings.conf";
}
inline std::string linuxCorePath() {
    if (const char *path = std::getenv("SIEUVIET_ENGINE_PATH")) return path;
#ifdef SIEUVIET_ENGINE_PATH
    return SIEUVIET_ENGINE_PATH;
#else
    return "libSieuvietEngine.so";
#endif
}
}
