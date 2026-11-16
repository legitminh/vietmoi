#pragma once
#include "Core.hpp"
#include <memory>
#include <set>

namespace sv {
struct Settings { int input = 0; int output = 0; std::string language = "vi"; };
struct Key { uint16_t usage = 0; bool down = true; bool repeat = false; bool shift = false; bool shortcut = false; bool selection = false; double time = 0; };
struct Document {
    virtual ~Document() = default;
    virtual bool preedit(const std::string &) = 0;
    virtual bool commit(const std::string &) = 0;
    virtual bool cancel() = 0;
    virtual bool clearVerified(const std::string &) = 0;
};

// All desktop adapters share routing and effect policy. Native adapters alone
// own ranges, encoding conversion, focus notifications and document transactions.
class Session {
    Core &core_; Document &document_; sv_engine_t engine_{}; Settings settings_;
    std::string recent_; std::set<uint16_t> held_;
    bool apply(int effect) {
        bool success = true;
        const auto text = Core::read(core_.copyText, engine_);
        switch (effect) {
        case SV_NONE: break;
        case SV_MARKED: recent_.clear(); success = document_.preedit(text); break;
        case SV_COMMIT: success = document_.commit(text); recent_ = success ? text : ""; break;
        case SV_CANCELLED: success = document_.cancel(); recent_.clear(); break;
        case SV_DELETE_CYCLE:
            if (!recent_.empty()) document_.clearVerified(recent_);
            recent_.clear(); break;
        default: return false;
        }
        if (!success) { core_.dispatch(engine_, SV_CANCEL, 0); recent_.clear(); }
        return success;
    }
public:
    Session(Core &core, Document &document, Settings settings = {}, bool ascii = false)
        : core_(core), document_(document), settings_(settings) {
        engine_ = core_.create(settings.output);
        if (!engine_) throw std::runtime_error("Invalid Sieuviet output mode");
        if (ascii) core_.dispatch(engine_, SV_TOGGLE_ASCII, 0);
    }
    ~Session() { core_.destroy(engine_); }
    Session(const Session &) = delete;
    Session &operator=(const Session &) = delete;
    bool pending() const { return core_.phase(engine_) > 0; }
    bool ascii() const { return core_.ascii(engine_) == 1; }
    std::string preview() const { return Core::read(core_.copyPreview, engine_); }
    std::string guide() const { return Core::read(core_.copyGuide, engine_, settings_.input); }
    Settings settings() const { return settings_; }
    bool configure(const Settings &settings) {
        if (pending()) return false;
        if (settings.input == settings_.input && settings.output == settings_.output && settings.language == settings_.language) return true;
        auto replacement = core_.create(settings.output);
        if (!replacement) return false;
        if (ascii()) core_.dispatch(replacement, SV_TOGGLE_ASCII, 0);
        core_.destroy(engine_); engine_ = replacement; settings_ = settings;
        recent_.clear(); held_.clear(); return true;
    }
    void invalidate() { core_.dispatch(engine_, SV_CANCEL, 0); recent_.clear(); held_.clear(); }
    void finish() { if (pending()) apply(core_.dispatch(engine_, SV_FINISH, 0)); }
    bool command(int command) { return apply(core_.dispatch(engine_, command, 0)); }
    bool key(Key event) {
        if (!event.down) held_.erase(event.usage);
        else { event.repeat = event.repeat || !held_.insert(event.usage).second; }
        const bool toggle = core_.observe(engine_, event.usage, event.down ? 1 : 0, event.time, event.shortcut ? 1 : 0) == 1;
        if (toggle) command(SV_TOGGLE_ASCII);
        if (!event.down) return false;
        if (event.usage >= 0xe0 && event.usage <= 0xe7) return false;
        if (event.shortcut) { finish(); recent_.clear(); return false; }
        if (event.usage == 0x2a && pending()) { command(SV_BACKSPACE); return true; }
        if (event.usage == 0x29 && pending()) { command(SV_CANCEL); return true; }
        if (event.usage == 0x4c && !ascii() && !event.selection && (pending() || !recent_.empty())) { command(SV_CLEAR); return true; }
        if (event.shift) { finish(); recent_.clear(); return false; }
        if (event.usage == 0x2c && pending()) { command(SV_SPACE); return true; }
        if (core_.wantsKey(engine_, settings_.input, event.usage) == 1) {
            if (!event.repeat) apply(core_.dispatchKey(engine_, settings_.input, event.usage));
            return true;
        }
        finish(); recent_.clear(); return false;
    }
};

// Linux evdev physical scan codes. IBus supplies evdev codes; X11/Fcitx add 8.
// This translates hardware positions only, never Sieuviet atom mappings.
inline uint16_t evdevUsage(unsigned key) {
    constexpr uint16_t codes[] = {0,0x29,0x1e,0x1f,0x20,0x21,0x22,0x23,0x24,0x25,0x26,0x27,0x2d,0x2e,0x2a,0x2b,
        0x14,0x1a,0x08,0x15,0x17,0x1c,0x18,0x0c,0x12,0x13,0x2f,0x30,0x28,0xe0,0x04,0x16,0x07,0x09,0x0a,0x0b,0x0d,0x0e,0x0f,
        0x33,0x34,0x35,0xe1,0x31,0x1d,0x1b,0x06,0x19,0x05,0x11,0x10,0x36,0x37,0x38,0xe5,0x55,0xe2,0x2c,0x39};
    if (key < sizeof codes / sizeof codes[0]) return codes[key];
    switch (key) { case 97:return 0xe4;case 100:return 0xe6;case 111:return 0x4c;case 103:return 0x52;case 108:return 0x51;
    case 105:return 0x50;case 106:return 0x4f;case 125:return 0xe3;case 126:return 0xe7;default:return static_cast<uint16_t>(0x1000 + (key & 0xfff)); }
}
}
