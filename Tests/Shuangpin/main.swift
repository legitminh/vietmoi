import Foundation

var checks = 0
func expect(_ value: @autoclosure () -> Bool, _ message: String) {
    checks += 1
    if !value() { fatalError(message) }
}
let mapping = ["ni":"ni", "hao":"hk", "zhong":"vs", "guo":"go", "shi":"ui", "jie":"jx", "ruan":"rr", "pin":"pn", "yin":"yn", "shuang":"ud", "qing":"q;", "liu":"lq", "xue":"xt", "nve":"nt", "yuan":"yr", "er":"or", "ai":"ol", "a":"oa", "e":"oe", "ou":"ob", "ang":"oh", "eng":"og"]
for (pinyin, code) in mapping {
    expect(MicrosoftShuangpin.codes(for: pinyin).contains(code), "Microsoft mapping: \(pinyin) → \(code)")
}
expect(MicrosoftShuangpin.codes(for: "a").contains("aa"), "Zero-initial a alias")
expect(MicrosoftShuangpin.codes(for: "en").contains("ef"), "Zero-initial en alias")
expect(MicrosoftShuangpin.codes(for: "xue").contains("xv"), "üe alternate key")
let dictionary = ShuangpinDictionary(contents: try String(contentsOfFile: CommandLine.arguments[1], encoding: .utf8))
expect(dictionary.isAvailable, "Bundled offline dictionary loads")
var engine = ShuangpinEngine(dictionary: dictionary)
func type(_ keys: String) { for key in keys { _ = engine.append(String(key)) } }
for (keys, text) in [("nihk", "你好"), ("vsgo", "中国"), ("uijx", "世界"), ("wzrr", "微软")] {
    type(keys)
    expect(engine.candidates.contains { $0.text == text }, "Phrase lookup: \(keys) → \(text)")
    _ = engine.cancel()
}
type("udpnpn")
expect(engine.candidates.first?.pinyin == "shuang pin pin" && engine.candidates.first?.text.count == 3, "Unknown phrases join known segments")
_ = engine.cancel()
type("nihk")
expect(engine.preview == "ni hk", "Marked preview groups two-key syllables")
let index = engine.candidates.firstIndex { $0.text == "你好" }!
engine.moveSelection(index)
expect(engine.choose() == .commit("你好") && !engine.isPending, "Space commits chosen phrase without trailing spaces")
type("ni")
expect(engine.candidates.count > 9, "Ambiguous syllables have paginated candidates")
engine.moveSelection(9)
let tenth = engine.candidates[9].text
expect(engine.pageStart == 9 && engine.choose(1) == .commit(tenth), "Digits select within current page")
type("q;")
expect(!engine.candidates.isEmpty, "Semicolon is ing final")
_ = engine.backspace()
expect(engine.code == "q" && engine.candidates.isEmpty, "Backspace removes one physical key and invalidates candidates")
expect(engine.backspace() == .cancel && !engine.isPending, "Deleting last key cancels composition")
expect(engine.append(";") == .none, "Semicolon does not begin a syllable")
type("n")
expect(engine.choose() == .none && engine.isPending, "Incomplete syllable cannot commit a candidate")
expect(engine.choose(literal: true) == .commit("n"), "Return can commit raw incomplete input")
type("nihk")
expect(engine.cancel() == .cancel && engine.candidates.isEmpty, "Escape or keyboard switch clears candidates")
let missing = ShuangpinEngine(dictionary: ShuangpinDictionary(contents: ""))
expect(!missing.dictionary.isAvailable, "Missing dictionary is detectable")
expect(dictionary.candidates(for: "nih").isEmpty, "Conversion does not invent incomplete syllables")
let predicted = dictionary.candidates(for: "nih", completing: true)
expect(predicted.contains { $0.text == "你好" && $0.isCompletion }, "Chinese completion finishes a partially typed phrase")
var guarded = ShuangpinEngine(dictionary: dictionary)
guarded.completionsEnabled = true
_ = guarded.append("n")
guarded.applyCompletions(predicted, for: "nih")
expect(guarded.candidates.isEmpty, "Stale Chinese prediction cannot replace a newer code")
guarded.completionsEnabled = false
guarded.applyCompletions(predicted, for: "n")
expect(guarded.candidates.isEmpty, "Disabled completion ignores background results")
print("Passed \(checks) Shuangpin mapping, dictionary, composition, and candidate checks.")
