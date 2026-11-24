#include <fcitx/addonfactory.h>
#include <fcitx/addonmanager.h>
#include <fcitx/inputmethodengine.h>
#include <fcitx/instance.h>
#include <fcitx/inputcontext.h>
#include <fcitx/inputcontextmanager.h>
#include <fcitx/inputcontextproperty.h>
#include <fcitx/inputpanel.h>
#include <fcitx-utils/utf8.h>
#include "Settings.hpp"
#include "Surrounding.hpp"
#include <chrono>

namespace {
sv::Core &core() { static sv::Core value(sv::linuxCorePath()); return value; }
struct Document : sv::Document {
    fcitx::InputContext *context; sv::CommitProof proof;
    explicit Document(fcitx::InputContext *value) : context(value) {}
    bool preedit(const std::string &value) override {
        proof.reset();
        fcitx::Text text(value, fcitx::TextFormatFlag::Underline); text.setCursor(value.size());
        context->inputPanel().setClientPreedit(text); context->updatePreedit(); return true;
    }
    bool cancel() override { proof.reset(); context->inputPanel().setClientPreedit(fcitx::Text()); context->updatePreedit(); return true; }
    std::optional<sv::Surrounding> surrounding() {
        const auto &text = context->surroundingText();
        if (!text.isValid()) return std::nullopt;
        const auto length = fcitx::utf8::length(text.text());
        if (text.cursor() > length || text.anchor() > length) return std::nullopt;
        const auto begin = text.text().begin();
        return sv::Surrounding{text.text(), static_cast<size_t>(std::distance(begin,fcitx::utf8::nextNChar(begin,text.cursor()))),
            static_cast<size_t>(std::distance(begin,fcitx::utf8::nextNChar(begin,text.anchor())))};
    }
    bool commit(const std::string &value) override {
        const auto before = surrounding(); cancel(); proof.record(before,value); context->commitString(value); return true;
    }
    bool clearVerified(const std::string &value) override {
        const bool verified = proof.matches(surrounding(),value); proof.reset();
        if (!verified) return false;
        const auto count = fcitx::utf8::length(value);
        context->deleteSurroundingText(-static_cast<int>(count),count); return true;
    }
};
struct State : fcitx::InputContextProperty {
    Document document; std::unique_ptr<sv::Session> session;
    sv::SettingsFile settings{sv::linuxSettingsPath()};
    explicit State(fcitx::InputContext *context) : document(context) { activate(); }
    void activate() { const auto keyboard = session ? session->keyboard().id : std::string(); session = std::make_unique<sv::Session>(core(), document, settings.current(), keyboard); }
    void guide() {
        document.context->inputPanel().setAuxDown(fcitx::Text(session->ascii() ? "" : session->guide()));
        document.context->updateUserInterface(fcitx::UserInterfaceComponent::InputPanel);
    }
};
class Engine : public fcitx::InputMethodEngine {
    fcitx::FactoryFor<State> states_;
public:
    explicit Engine(fcitx::Instance *instance) : states_([](fcitx::InputContext &context) { return new State(&context); }) { instance->inputContextManager().registerProperty("sieuviet", &states_); }
    void activate(const fcitx::InputMethodEntry &, fcitx::InputContextEvent &event) override { auto *state = event.inputContext()->propertyFor(&states_); state->activate(); state->guide(); }
    void deactivate(const fcitx::InputMethodEntry &, fcitx::InputContextEvent &event) override {
        auto *state = event.inputContext()->propertyFor(&states_); state->session->finish(); state->session->invalidate();
        event.inputContext()->inputPanel().reset(); event.inputContext()->updatePreedit();
    }
    void reset(const fcitx::InputMethodEntry &, fcitx::InputContextEvent &event) override {
        auto *state = event.inputContext()->propertyFor(&states_); state->session->invalidate(); state->document.cancel(); state->guide();
    }
    void keyEvent(const fcitx::InputMethodEntry &, fcitx::KeyEvent &event) override {
        auto *context = event.inputContext();
        auto *state = context->propertyFor(&states_);
        if (!state->session->pending()) state->session->configure(state->settings.current());
        if (context->capabilityFlags().test(fcitx::CapabilityFlag::Password) || context->capabilityFlags().test(fcitx::CapabilityFlag::Sensitive)) {
            state->session->invalidate(); state->document.cancel(); context->inputPanel().reset(); return;
        }
        const auto key = event.rawKey();
        const auto usage = sv::evdevUsage(key.code() >= 8 ? key.code() - 8 : 0);
        const auto modifiers = key.states();
        sv::Key input{usage, !event.isRelease(), false, modifiers.test(fcitx::KeyState::Shift),
                      modifiers.test(fcitx::KeyState::Ctrl) || modifiers.test(fcitx::KeyState::Alt) || modifiers.test(fcitx::KeyState::Super), false,
                      std::chrono::duration<double>(std::chrono::steady_clock::now().time_since_epoch()).count()};
        if (state->session->key(input)) event.filterAndAccept();
        state->guide();
    }
};
class Factory : public fcitx::AddonFactory {
    fcitx::AddonInstance *create(fcitx::AddonManager *manager) override { return new Engine(manager->instance()); }
};
}
FCITX_ADDON_FACTORY(Factory)
