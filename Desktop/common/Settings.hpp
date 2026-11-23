#pragma once
#include "Session.hpp"
#include <cstdlib>
#include <fstream>
#include <sstream>

namespace sv {
// settings.conf, version 2: one `keyboard=` line per managed keyboard, in Shift
// order, with the same values as every other siêu việt app:
//   keyboard=<id>,<vi|en>,<ascii+|grid4x8|qwerty>,<sieuviet|quốc ngữ|literal>,<name>
//   active=<id>
// Version 1 snapshots (input=, output=) load as [that keyboard, English].
inline Keyboard parseKeyboard(const std::string &value) {
    Keyboard result; std::string fields[4]; size_t start = 0;
    for (auto &field : fields) {
        const auto comma = value.find(',', start);
        if (comma == std::string::npos) return {};
        field = value.substr(start, comma - start); start = comma + 1;
    }
    result.id = fields[0]; result.name = value.substr(start);
    result.language = fields[1] == "en" ? "en" : "vi";
    result.input = !result.literal() && fields[2] == "grid4x8" ? 1 : 0;
    result.output = !result.literal() && fields[3] == "quốc ngữ" ? 1 : 0;
    return result;
}
inline std::string formatKeyboard(const Keyboard &keyboard) {
    if (keyboard.literal()) return keyboard.id + ",en,qwerty,literal," + keyboard.name;
    return keyboard.id + ",vi," + (keyboard.input == 1 ? "grid4x8" : "ascii+") + "," +
           (keyboard.output == 1 ? "quốc ngữ" : "sieuviet") + "," + keyboard.name;
}
inline Settings parseSettings(std::istream &file) {
    Settings result; std::string line;
    while (std::getline(file, line)) {
        if (!line.empty() && line.back() == '\r') line.pop_back();
        if (line == "input=1") result.input = 1;
        else if (line == "output=1") result.output = 1;
        else if (line == "language=en") result.language = "en";
        else if (line.rfind("active=", 0) == 0) result.active = line.substr(7);
        else if (line.rfind("shiftTapSeconds=", 0) == 0) result.shiftTapSeconds = line.substr(16);
        else if (line.rfind("keyboard=", 0) == 0) {
            auto keyboard = parseKeyboard(line.substr(9));
            if (!keyboard.id.empty()) result.keyboards.push_back(keyboard);
        }
    }
    return result;
}
inline Settings loadSettings(const std::filesystem::path &path) { std::ifstream file(path); return parseSettings(file); }
inline std::string formatSettings(const Settings &settings) {
    std::string result = "version=2\nlanguage=" + settings.language + "\n";
    const auto list = keyboardList(settings);
    result += "active=" + (settings.active.empty() ? list.front().id : settings.active) + "\n";
    if (!settings.shiftTapSeconds.empty()) result += "shiftTapSeconds=" + settings.shiftTapSeconds + "\n";
    for (const auto &keyboard : list) result += "keyboard=" + formatKeyboard(keyboard) + "\n";
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
