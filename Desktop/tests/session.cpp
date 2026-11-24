#include "Settings.hpp"
#include "Surrounding.hpp"
#include <iostream>
#include <cstdlib>

struct Document : sv::Document {
    std::string text, original; size_t caret = 0, start = std::string::npos, length = 0;
    bool preedit(const std::string &value) override {
        if (value.empty() && start == std::string::npos) return true;
        if (start == std::string::npos) { start = caret; length = 0; original.clear(); }
        text.replace(start, length, value); length = value.size(); caret = start + length; return true;
    }
    bool commit(const std::string &value) override {
        if (start != std::string::npos) { text.replace(start, length, value); caret = start + value.size(); }
        else { text.insert(caret, value); caret += value.size(); }
        start = std::string::npos; length = 0; return true;
    }
    bool cancel() override {
        if (start != std::string::npos) { text.replace(start, length, original); caret = start + original.size(); }
        start = std::string::npos; length = 0; return true;
    }
    bool clearVerified(const std::string &value) override {
        if (caret < value.size() || text.substr(caret - value.size(), value.size()) != value) return false;
        text.erase(caret - value.size(), value.size()); caret -= value.size(); return true;
    }
};
int checks = 0;
void check(bool value, const char *message) { ++checks; if (!value) throw std::runtime_error(message); }
uint16_t usage(char key) { return key >= '1' && key <= '9' ? 0x1e + key - '1' : key == ';' ? 0x33 : 4 + key - 'a'; }
double clockTime = 0;
void press(sv::Session &session, uint16_t hid) {
    auto down = sv::Key{hid, true, false, false, false, false, clockTime += .01};
    session.key(down); down.down = false; down.time = clockTime += .01; session.key(down);
}
void type(sv::Session &session, const std::string &keys) { for (char key : keys) press(session, usage(key)); }
void tap(sv::Session &session) { session.key({0xe1,true,false,true,false,false,clockTime += 1}); session.key({0xe1,false,false,false,false,false,clockTime += .05}); }
int main(int argc, char **argv) {
    try {
        const char *path = argc > 1 ? argv[1] : std::getenv("SIEUVIET_ENGINE_PATH");
        if (!path) throw std::runtime_error("Pass the compiled shared-engine path");
        sv::Core core(path);
        { sv::CommitProof proof;
          proof.record(sv::Surrounding{"🙂é ",8,8},"má ");
          check(proof.matches(sv::Surrounding{"🙂é má ",12,12},"má "), "UTF-8 commit proof");
          check(!proof.matches(sv::Surrounding{"🙂é má má ",16,16},"má "), "identical suffix elsewhere is not owned");
          check(!proof.matches(sv::Surrounding{"🙂é má ",8,8},"má "), "moved caret invalidates proof"); }
        for (int output = 0; output < 2; ++output) {
            const char *keys[] = {"msed", "frej", "rwos", "imoj", "xaqs", "mlnd"};
            const char *expected[][6] = {{"má ", "fở ", "răo ", "khwỉo ", "xoong ", "muốn "},
                                         {"má ", "phở ", "rau ", "khuỷu ", "xoong ", "muốn "}};
            for (int index = 0; index < 6; ++index) { Document doc; sv::Session session(core, doc, {0,output}); type(session, keys[index]); check(doc.text == expected[output][index], "reviewed word"); }
        }
        { Document doc; sv::Session session(core, doc); type(session,"ms"); check(doc.text == "ma", "preview");
          press(session,0x2a); check(doc.text == "m", "round undo"); press(session,0x2a); check(doc.text.empty(), "initial undo");
          type(session,"m"); press(session,0x2c); check(doc.text == "m ", "partial space");
          type(session,"m"); session.key({0xe1,true,false,true,false,false,10}); session.key({0xe1,false,false,false,false,false,10.1});
          check(session.ascii() && doc.text == "m m", "tap keeps partial");
          session.key({0xe1,true,false,true,false,false,11}); session.key({0xe1,false,false,false,false,false,11.4}); check(session.ascii(), "hold does not toggle");
          tap(session); check(!session.ascii() && session.keyboard().id == "vi", "tap cycles back to Vietnamese");
          type(session,"xaqs"); check(doc.text == "m mxoong ", "return to Vietnamese");
          press(session,0x4c); check(doc.text == "m m", "verified cycle deletion"); }
        { Document doc; sv::Session session(core,doc,{1,1}); type(session,"r"); type(session,"z"); check(doc.text == "m", "unavailable grid key is consumed");
          type(session,"312"); check(doc.text == "má ", "grid order matches revised inventory"); }
        { Document doc; sv::Session session(core,doc); type(session,"m");
          session.key({usage('m'),true,true,false,false,false,15}); check(doc.text == "m", "repeat cannot advance");
          check(!session.key({0x33,true,false,false,false,false,16}), "semicolon passes through"); check(doc.text == "m", "boundary keeps prefix"); }
        { Document doc; sv::Session session(core,doc); type(session,"f");
          check(!session.configure({0,1}), "settings cannot change during a word"); type(session,"rej");
          check(doc.text == "fở ", "pending word keeps original output");
          check(session.configure({0,1}), "idle settings refresh"); type(session,"frej");
          check(doc.text == "fở phở ", "new word uses refreshed output"); }
        { Document doc; sv::Session session(core, doc, {1,0,"vi"});
          check(session.guide().find(": Xóa") != std::string::npos, "Vietnamese grid control label");
          check(session.configure({1,0,"en"}) && session.settings().input == 1 && session.settings().output == 0, "language keeps layout and spelling");
          check(session.guide().find(": Clear") != std::string::npos, "English grid control label");
          tap(session);
          check(session.configure({1,0,"vi"}) && session.ascii() && session.guide().find("Chạm riêng") != std::string::npos, "language keeps the English keyboard and localizes guide help"); }
        { std::istringstream file("version=2\nlanguage=en\nactive=B\nkeyboard=A,vi,grid4x8,quốc ngữ,Grid, phở\nkeyboard=B,en,qwerty,literal,English\nkeyboard=C,vi,ascii+,sieuviet,Mine\n");
          auto settings = sv::parseSettings(file);
          check(settings.keyboards.size() == 3 && settings.keyboards[0].name == "Grid, phở" && settings.keyboards[0].input == 1 && settings.keyboards[0].output == 1, "version 2 list");
          check(sv::formatSettings(settings) == "version=2\nlanguage=en\nactive=B\nkeyboard=A,vi,grid4x8,quốc ngữ,Grid, phở\nkeyboard=B,en,qwerty,literal,English\nkeyboard=C,vi,ascii+,sieuviet,Mine\n", "version 2 round trip");
          Document doc; sv::Session session(core, doc, settings);
          check(session.keyboard().id == "B" && session.ascii(), "active keyboard opens");
          tap(session); check(session.keyboard().id == "C" && !session.ascii(), "tap moves to the next keyboard");
          type(session,"msed"); check(doc.text == "má ", "third keyboard types ASCII+ siêu việt");
          tap(session); check(session.keyboard().id == "A", "tap wraps to the first keyboard");
          type(session,"r312"); check(doc.text == "má má ", "grid keyboard types quốc ngữ");
          sv::Session reopened(core, doc, settings, "C"); check(reopened.keyboard().id == "C", "adapter keeps its keyboard across focus");
          auto chosen = settings; chosen.active = "A";
          check(reopened.configure(chosen) && reopened.keyboard().id == "A", "a keyboard selected in settings opens");
          auto edited = chosen; edited.keyboards[1].name = "Anh";
          tap(reopened); check(reopened.configure(edited) && reopened.keyboard().id == "B", "an edit keeps the current keyboard"); }
        { std::istringstream file("version=1\ninput=1\noutput=1\nlanguage=vi\n");
          auto list = sv::keyboardList(sv::parseSettings(file));
          check(list.size() == 2 && list[0].input == 1 && list[0].output == 1 && list[1].literal(), "version 1 migrates to [Vietnamese, English]"); }
        std::cout << "Passed " << checks << " desktop policy checks against the actual Swift library.\n";
        return 0;
    } catch (const std::exception &error) { std::cerr << error.what() << '\n'; return 1; }
}
