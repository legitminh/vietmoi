#include <ibus.h>
#include "Settings.hpp"
#include "Design.hpp"
#include "Surrounding.hpp"
#include <chrono>

namespace {
sv::Core &core() { static sv::Core value(sv::linuxCorePath()); return value; }
struct IBusDocument : sv::Document {
    IBusEngine *engine; sv::CommitProof proof;
    explicit IBusDocument(IBusEngine *value) : engine(value) {}
    bool preedit(const std::string &value) override {
        proof.reset();
        auto *text = ibus_text_new_from_string(value.c_str());
        const auto length = static_cast<guint>(g_utf8_strlen(value.c_str(), -1));
        ibus_text_append_attribute(text, IBUS_ATTR_TYPE_UNDERLINE, IBUS_ATTR_UNDERLINE_SINGLE, 0, length);
        ibus_engine_update_preedit_text_with_mode(engine, text, length, !value.empty(), IBUS_ENGINE_PREEDIT_COMMIT);
        return true;
    }
    bool cancel() override { proof.reset(); ibus_engine_update_preedit_text(engine, ibus_text_new_from_static_string(""), 0, FALSE); return true; }
    std::optional<sv::Surrounding> surrounding() {
        if (!(engine->client_capabilities & IBUS_CAP_SURROUNDING_TEXT)) return std::nullopt;
        IBusText *text = nullptr; guint cursor = 0, anchor = 0;
        ibus_engine_get_surrounding_text(engine, &text, &cursor, &anchor);
        std::unique_ptr<IBusText, decltype(&g_object_unref)> owned(text, g_object_unref);
        if (!text) return std::nullopt;
        const char *source = ibus_text_get_text(text);
        if (!g_utf8_validate(source, -1, nullptr)) return std::nullopt;
        const auto length = g_utf8_strlen(source, -1);
        if (cursor > length || anchor > length) return std::nullopt;
        return sv::Surrounding{source, static_cast<size_t>(g_utf8_offset_to_pointer(source,cursor)-source),
                              static_cast<size_t>(g_utf8_offset_to_pointer(source,anchor)-source)};
    }
    bool commit(const std::string &value) override {
        const auto before = surrounding(); cancel(); proof.record(before,value);
        ibus_engine_commit_text(engine, ibus_text_new_from_string(value.c_str())); return true;
    }
    bool clearVerified(const std::string &value) override {
        const bool verified = proof.matches(surrounding(), value); proof.reset();
        if (!verified) return false;
        const auto count = static_cast<guint>(g_utf8_strlen(value.c_str(), -1));
        ibus_engine_delete_surrounding_text(engine, -static_cast<int>(count), count); return true;
    }
};
struct State {
    IBusDocument document; std::unique_ptr<sv::Session> session; std::string keyboard; bool secure = false;
    sv::SettingsFile settings{sv::linuxSettingsPath()};
    explicit State(IBusEngine *engine) : document(engine) { activate(); }
    void activate() { if (session) keyboard = session->keyboard().id; session = std::make_unique<sv::Session>(core(), document, settings.current(), keyboard); }
    void guide() { ibus_engine_update_auxiliary_text(document.engine, ibus_text_new_from_string(session->guide().c_str()), !session->ascii() && !secure); }
};
struct SieuvietEngine { IBusEngine parent; State *state; };
struct SieuvietEngineClass { IBusEngineClass parent; };
G_DEFINE_TYPE(SieuvietEngine, sieuviet_engine, IBUS_TYPE_ENGINE)

void constructed(GObject *object) {
    G_OBJECT_CLASS(sieuviet_engine_parent_class)->constructed(object);
    try { reinterpret_cast<SieuvietEngine *>(object)->state = new State(IBUS_ENGINE(object)); }
    catch (const std::exception &error) { g_warning("Sieuviet cannot initialize: %s", error.what()); }
}
void finalize(GObject *object) { delete reinterpret_cast<SieuvietEngine *>(object)->state; G_OBJECT_CLASS(sieuviet_engine_parent_class)->finalize(object); }
gboolean key(IBusEngine *engine, guint keyval, guint keycode, guint flags) {
    auto *state = reinterpret_cast<SieuvietEngine *>(engine)->state;
    if (!state || state->secure) return FALSE;
    if (!state->session->pending()) state->session->configure(state->settings.current());
    auto usage = sv::evdevUsage(keycode);
    if (!keycode && ((keyval >= IBUS_KEY_a && keyval <= IBUS_KEY_z) || (keyval >= IBUS_KEY_A && keyval <= IBUS_KEY_Z)))
        usage = static_cast<uint16_t>(g_ascii_tolower(static_cast<char>(keyval)) - 'a' + 4);
    const double time = std::chrono::duration<double>(std::chrono::steady_clock::now().time_since_epoch()).count();
    sv::Key event{usage, !(flags & IBUS_RELEASE_MASK), false, !!(flags & IBUS_SHIFT_MASK),
                  !!(flags & (IBUS_CONTROL_MASK | IBUS_MOD1_MASK | IBUS_SUPER_MASK | IBUS_META_MASK)), false, time};
    event.text = static_cast<char32_t>(ibus_keyval_to_unicode(keyval));
    const bool handled = state->session->key(event); state->guide(); return handled;
}
void focusIn(IBusEngine *engine) {
    ibus_engine_get_surrounding_text(engine, nullptr, nullptr, nullptr);
    if (auto *state = reinterpret_cast<SieuvietEngine *>(engine)->state) { state->activate(); state->guide(); }
}
void focusOut(IBusEngine *engine) {
    if (auto *state = reinterpret_cast<SieuvietEngine *>(engine)->state) {
        // IBus PREEDIT_COMMIT commits at the old client's focus boundary itself.
        state->session->invalidate(); ibus_engine_hide_auxiliary_text(engine);
    }
}
void reset(IBusEngine *engine) {
    if (auto *state = reinterpret_cast<SieuvietEngine *>(engine)->state) { state->session->invalidate(); state->document.cancel(); state->guide(); }
}
void content(IBusEngine *engine, guint purpose, guint hints) {
    if (auto *state = reinterpret_cast<SieuvietEngine *>(engine)->state) {
        state->secure = purpose == IBUS_INPUT_PURPOSE_PASSWORD || purpose == IBUS_INPUT_PURPOSE_PIN || (hints & IBUS_INPUT_HINT_PRIVATE);
        if (state->secure) { state->session->invalidate(); state->document.cancel(); }
        state->guide();
    }
}
void sieuviet_engine_init(SieuvietEngine *engine) { engine->state = nullptr; }
void sieuviet_engine_class_init(SieuvietEngineClass *klass) {
    auto *object = G_OBJECT_CLASS(klass); object->constructed = constructed; object->finalize = finalize;
    auto *engine = IBUS_ENGINE_CLASS(klass); engine->process_key_event = key; engine->focus_in = focusIn;
    engine->focus_out = focusOut; engine->reset = reset; engine->set_content_type = content;
}
}
int main(int argc, char **argv) {
    ibus_init();
    auto *bus = ibus_bus_new();
    if (!ibus_bus_is_connected(bus)) { g_printerr("Sieuviet: no IBus session bus\n"); return 1; }
    g_signal_connect(bus, "disconnected", G_CALLBACK(ibus_quit), nullptr);
    auto *factory = ibus_factory_new(ibus_bus_get_connection(bus));
    ibus_factory_add_engine(factory, "sieuviet", sieuviet_engine_get_type());
    if (argc > 1 && std::string(argv[1]) == "--ibus") ibus_bus_request_name(bus, "org.freedesktop.IBus.Sieuviet", 0);
    else {
        auto *component = ibus_component_new("org.freedesktop.IBus.Sieuviet", sv::design::name, sv::design::version, "", "Sieuviet", "", "", "");
        ibus_component_add_engine(component, ibus_engine_desc_new("sieuviet", "Sieuviet", "Four-round keyboard", "vi", "", "Sieuviet", "input-keyboard", "us"));
        ibus_bus_register_component(bus, component);
    }
    ibus_main(); g_object_unref(factory); g_object_unref(bus); return 0;
}
