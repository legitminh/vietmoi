import Foundation

var checks = 0
func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    checks += 1
    if !condition() { fatalError("FAILED: \(message)") }
}
func choose(_ initial: String, _ onglide: String, _ vowel: String, _ final: String,
            _ tone: VietnameseTone = .ngang, engine: inout KeyboardEngine) -> EngineEffect {
    let atom = VietnameseVowelAtom(onglide: onglide, coreVowel: vowel)
    let indices = [engine.inventory.initials.firstIndex(of: initial)!, engine.inventory.vowelAtoms.firstIndex(of: atom)!,
                   engine.inventory.finals.firstIndex(of: final)!, tone.rawValue]
    var effect = EngineEffect.none
    for index in indices { effect = engine.selectComponent(index) }
    return effect
}
var engine = KeyboardEngine()
expect(choose("m", "", "a", "", .sac, engine: &engine) == .commit("má "), "tone attaches to core and every cycle adds one space")
expect(engine.lastCommittedBasis == VietnamesePhoneticBasis(initial: "m", onglide: "", coreVowel: "a", tone: .sac, final: ""), "commit retains structured phonetic basis")
expect(choose("r", "", "ă", "o", engine: &engine) == .commit("răo "), "offglide /w/ is now written o")
expect(choose("kh", "w", "iê", "", engine: &engine) == .commit("khwiê "), "khuya preserves the combined w+iê selection")
expect(choose("f", "", "ơ", "", .hoi, engine: &engine) == .commit("fở "), "ph is phonetic f")
expect(choose("ch", "", "uô", "", engine: &engine) == .commit("chuô "), "chua uses the fixed uô nucleus")
expect(choose("kh", "w", "i", "o", .hoi, engine: &engine) == .commit("khwỉo "), "khuỷu retains both onglide and offglide")
expect(choose("m", "", "uô", "n", .sac, engine: &engine) == .commit("muốn "), "uô tone anchor is ô")
expect(choose("d", "", "ươ", "ng", .nang, engine: &engine) == .commit("dượng "), "ươ tone anchor is ơ")
expect(choose("x", "", "oo", "ng", engine: &engine) == .commit("xoong "), "long oo distinguishes xoong")
expect(choose("s", "", "oo", "c", .sac, engine: &engine) == .commit("soóc "), "long oo takes the tone on its second o")
// Deliberately broad construction space: phonotactics must not silently reject atoms.
expect(choose("p", "w", "e", "t", .ngang, engine: &engine) == .commit("pwet "), "nonstandard combinations of supported atoms remain constructible")
expect(engine.inventory.vowelAtoms.count == 24, "revised inventory has 24 choices")
for removed in ["wô", "wư", "wu"] {
    expect(!engine.inventory.vowelAtoms.contains { $0.label == removed }, "commented-out combination is unavailable")
}
_ = engine.selectComponent(14)
expect(engine.phase == .onglideCoreVowel, "second round chooses onglide and core together")
expect(engine.selectComponent(2) == .marked("nha") && engine.phase == .final, "vowel preview precedes final selection")
expect(engine.phoneticBasis?.onglide == "" && engine.phoneticBasis?.coreVowel == "a", "round two exposes structured vowel atom")
expect(engine.selectComponent(4) == .marked("nhan") && engine.phase == .tone, "third round previews the full unaccented syllable")
expect(engine.phoneticBasis?.final == "n", "draft basis retains the selected final before tone")
expect(engine.selectComponent(6) == .none && engine.isPending, "invalid final-round tone cannot commit")
expect(engine.selectComponent(4) == .commit("nhãn "), "last tone choice accents the core and commits the entire syllable")
_ = engine.selectComponent(14); _ = engine.selectComponent(2); _ = engine.selectComponent(4)
expect(engine.backspace() == .marked("nha") && engine.phase == .final, "undo removes the selected final")
expect(engine.backspace() == .marked("nh") && engine.phase == .onglideCoreVowel, "undo combined round removes both vowel components")
expect(engine.backspace() == .cancel, "undo initial")
expect(engine.clearCycle() == .deleteCycle, "clear completed cycle")
let completedBasis = engine.lastCommittedBasis!
_ = engine.selectComponent(0)
expect(engine.press(24) == .commit("b") && engine.ascii, "mode switching commits the partial initial without a separator")
expect(engine.press(31) == .none, "ASCII preserves literal m")
_ = engine.press(24)
expect(engine.selectComponent(-1) == .none && engine.selectComponent(999) == .none, "invalid atoms cannot advance")
expect(engine.action(at: -1) == nil && engine.action(at: 32) == nil, "invalid grid index is safe")

let cycle = CommittedCycle(text: "a😀", range: NSRange(location: 4, length: 3))
expect(cycle.canDelete(selection: NSRange(location: 7, length: 0), actualText: "a😀"), "UTF16 deletion")
expect(!cycle.canDelete(selection: NSRange(location: 8, length: 0), actualText: "a😀"), "reject moved caret")
expect(!cycle.canDelete(selection: NSRange(location: 7, length: 0), actualText: nil), "reject unreadable document")
for scalar in [0, 8, 9, 10, 13, 27, 127, 0x9B, 0xF700] {
    expect(!CompositionText.isSafe(String(UnicodeScalar(scalar)!)), "reject control/function scalar \(scalar)")
}
var invalidInventory = VietnamesePhoneticInventory.sieuviet
invalidInventory.initials[0] = "\u{8}"
var unsafe = KeyboardEngine(inventory: invalidInventory)
expect(unsafe.selectComponent(0) == .cancel && !unsafe.isPending, "invalid configured atom cannot emit a control")
var custom = VietnamesePhoneticInventory.sieuviet
custom.initials.reverse(); custom.coreVowels.reverse(); custom.onglides.reverse()
custom.toneAnchors["uô"] = 0
var customized = KeyboardEngine(inventory: custom)
expect(choose("m", "", "uô", "", .sac, engine: &customized) == .commit("múô "), "inventory order and tone anchor are configurable")
let saved = try JSONEncoder().encode(completedBasis)
let decodedBasis = try JSONDecoder().decode(VietnamesePhoneticBasis.self, from: saved)
expect(decodedBasis == completedBasis, "basis JSON round trip")
expect(String(data: saved, encoding: .utf8)!.contains("vietnamese_core_vowel"), "stable basis field names")

for rounds in 1...3 {
    var partial = KeyboardEngine()
    for value in [11,2,4].prefix(rounds) { _ = partial.selectComponent(value) }
    let expected = ["m", "ma", "man"][rounds - 1]
    expect(partial.finishPartial(suffix: " ") == .commit(expected + " ") && !partial.isPending,
           "A normal boundary commits exactly the visible partial text")
    expect(partial.lastCommittedBasis == nil, "Partial text is not mislabelled as a fully chosen phonetic basis")
    expect(partial.finishPartial() == .none, "A repeated host flush does not duplicate text")
}
var emptyInitial = KeyboardEngine()
_ = emptyInitial.selectComponent(KeyboardEngine.initials.firstIndex(of: "")!)
expect(emptyInitial.finishPartial() == .cancel && !emptyInitial.isPending, "An empty optional initial cannot create phantom text")

let expectedMarks: [UInt32?] = [nil, 0x301, 0x300, 0x309, 0x303, 0x323]
let toneMarks = Set(expectedMarks.compactMap { $0 })
var paths = 0
for initial in engine.inventory.initials.indices {
    for vowel in engine.inventory.vowelAtoms.indices {
        for tone in VietnameseTone.allCases {
            for final in engine.inventory.finals.indices {
                var candidate = KeyboardEngine()
                let values = [initial, vowel, final, tone.rawValue]
                var result = EngineEffect.none
                for value in values {
                    result = candidate.press(GridKey.actionSlots[value])
                    if case .marked(let text) = result { expect(CompositionText.isSafe(text), "safe marked text") }
                }
                guard case .commit(let text) = result, let basis = candidate.lastCommittedBasis else { fatalError("unreachable path") }
                let marks = text.decomposedStringWithCanonicalMapping.unicodeScalars.map(\.value).filter { toneMarks.contains($0) }
                expect(!candidate.isPending && text.hasSuffix(" ") && CompositionText.isSafe(text) &&
                       text == text.precomposedStringWithCanonicalMapping &&
                       marks == (expectedMarks[tone.rawValue].map { [$0] } ?? []) && text == basis.sieuviet() + " ",
                       "safe NFC composition through stored basis")
                paths += 1
            }
        }
    }
}
expect(paths == engine.inventory.initials.count * engine.inventory.vowelAtoms.count *
       engine.inventory.finals.count * VietnameseTone.allCases.count,
       "all supplied four-round combinations are reachable")
print("Passed \(checks) Sieuviet engine checks (\(paths) complete composition paths).")
