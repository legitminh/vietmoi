#pragma once
#include "Core.hpp"
#include "Design.hpp"
#include <algorithm>
#include <memory>
#include <set>
#include <string>
#include <vector>

namespace sv {
// One managed keyboard. Vietnamese keyboards choose an input layout (0 ASCII+,
// 1 grid4x8) and an output (0 siêu việt, 1 quốc ngữ); English keyboards type literally.
struct Keyboard {
    std::string id, name, language = "vi"; int input = 0; int output = 0;
    bool literal() const { return language == "en"; }
};
inline bool operator==(const Keyboard &a, const Keyboard &b) {
    return a.id == b.id && a.name == b.name && a.language == b.language && a.input == b.input && a.output == b.output;
}
inline bool operator!=(const Keyboard &a, const Keyboard &b) { return !(a == b); }
// `input` and `output` describe the Vietnamese keyboard of a legacy snapshot that
// has no list; such a snapshot behaves as [that keyboard, English].
struct Settings {
    int input = 0; int output = 0; std::string language = "vi";
    std::vector<Keyboard> keyboards; std::string active;
    std::string shiftTapSeconds; // kept for the shared UI; the engines use their own default
};
inline bool operator==(const Settings &a, const Settings &b) {
    return a.input == b.input && a.output == b.output && a.language == b.language && a.keyboards == b.keyboards && a.active == b.active;
}
inline std::vector<Keyboard> keyboardList(const Settings &settings) {
    if (!settings.keyboards.empty()) return settings.keyboards;
    return {Keyboard{"vi", "Tiếng Việt", "vi", settings.input, settings.output}, Keyboard{"en", "English", "en", 0, 0}};
}
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
    std::vector<Keyboard> keyboards_; size_t index_ = 0; std::string seenActive_;
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
    static size_t find(const std::vector<Keyboard> &list, const std::string &id) {
        for (size_t index = 0; index < list.size(); ++index) if (list[index].id == id) return index;
        return list.size();
    }
    sv_engine_t make(const Keyboard &keyboard) {
        auto engine = core_.create(keyboard.output);
        if (engine && keyboard.literal()) core_.dispatch(engine, SV_TOGGLE_ASCII, 0);
        return engine;
    }
public:
    /// `keyboard` is the id the adapter last used; otherwise the snapshot's active keyboard opens.
    Session(Core &core, Document &document, Settings settings = {}, const std::string &keyboard = {})
        : core_(core), document_(document), settings_(settings), keyboards_(keyboardList(settings)), seenActive_(settings.active) {
        index_ = find(keyboards_, keyboard);
        if (index_ == keyboards_.size()) index_ = find(keyboards_, settings.active);
        if (index_ == keyboards_.size()) index_ = 0;
        engine_ = make(keyboards_[index_]);
        if (!engine_) throw std::runtime_error("Invalid Sieuviet output mode");
    }
    ~Session() { core_.destroy(engine_); }
    Session(const Session &) = delete;
    Session &operator=(const Session &) = delete;
    bool pending() const { return core_.phase(engine_) > 0; }
    bool ascii() const { return core_.ascii(engine_) == 1; }
    const Keyboard &keyboard() const { return keyboards_[index_]; }
    std::string preview() const { return Core::read(core_.copyPreview, engine_); }
    std::string guide() const {
        if (ascii()) return keyboard().name + " · " + design::text("shiftLimitHelp", settings_.language);
        auto result = Core::read(core_.copyGuide, engine_, keyboard().input);
        // Keep ABI control tokens stable and localize native presentation.
        if (auto position = result.find(": Clear"); position != std::string::npos)
            result.replace(position, 7, ": " + design::text("clear", settings_.language));
        return result;
    }
    Settings settings() const { return settings_; }
    /// Adopt a new snapshot between words. A keyboard newly selected in settings
    /// opens; otherwise the current keyboard stays if it still exists.
    bool configure(const Settings &settings) {
        if (pending()) return false;
        if (settings == settings_) return true;
        auto list = keyboardList(settings);
        size_t index = settings.active != seenActive_ ? find(list, settings.active) : find(list, keyboard().id);
        if (index == list.size()) index = std::min(index_, list.size() - 1);
        if (list[index] != keyboard()) {
            auto replacement = make(list[index]);
            if (!replacement) return false;
            core_.destroy(engine_); engine_ = replacement;
        }
        settings_ = settings; keyboards_ = std::move(list); index_ = index; seenActive_ = settings.active;
        recent_.clear(); held_.clear(); return true;
    }
    /// Finish the word in progress and move to another keyboard of the list.
    bool select(size_t index) {
        if (index >= keyboards_.size()) return false;
        finish();
        if (keyboards_[index] != keyboard()) {
            auto replacement = make(keyboards_[index]);
            if (!replacement) return false;
            core_.destroy(engine_); engine_ = replacement;
        }
        index_ = index; return true;
    }
    bool next() { return select((index_ + 1) % keyboards_.size()); }
    void invalidate() { core_.dispatch(engine_, SV_CANCEL, 0); recent_.clear(); held_.clear(); }
    void finish() { if (pending()) apply(core_.dispatch(engine_, SV_FINISH, 0)); }
    bool command(int command) { return apply(core_.dispatch(engine_, command, 0)); }
    bool key(Key event) {
        if (!event.down) held_.erase(event.usage);
        else { event.repeat = event.repeat || !held_.insert(event.usage).second; }
        // A lone left Shift tap moves to the next keyboard in the list.
        if (core_.observe(engine_, event.usage, event.down ? 1 : 0, event.time, event.shortcut ? 1 : 0) == 1) next();
        if (!event.down) return false;
        if (event.usage >= 0xe0 && event.usage <= 0xe7) return false;
        if (event.shortcut) { finish(); recent_.clear(); return false; }
        if (event.usage == 0x2a && pending()) { command(SV_BACKSPACE); return true; }
        if (event.usage == 0x29 && pending()) { command(SV_CANCEL); return true; }
        if (event.usage == 0x4c && !ascii() && !event.selection && (pending() || !recent_.empty())) { command(SV_CLEAR); return true; }
        if (event.shift) { finish(); recent_.clear(); return false; }
        if (event.usage == 0x2c && pending()) { command(SV_SPACE); return true; }
        if (core_.wantsKey(engine_, keyboard().input, event.usage) == 1) {
            if (!event.repeat) apply(core_.dispatchKey(engine_, keyboard().input, event.usage));
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
