import Foundation

var checks = 0
func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    checks += 1
    if !condition() { fatalError("FAILED: \(message)") }
}
func key(_ character: Character) -> UInt16 { ASCIIKeyboardLayout.keyCodesByLabel[String(character)]! }
func type(_ text: String, into engine: inout KeyboardEngine, keymap: ASCIIPlusKeymap = .sieuviet) -> EngineEffect {
    var result = EngineEffect.none
    for character in text {
        guard let value = ASCIIPlusMapping.bindings(for: engine.phase, inventory: engine.inventory, keymap: keymap)[key(character)] else { fatalError("Unmapped example \(character) in \(engine.phase)") }
        result = engine.selectComponent(value)
    }
    return result
}
var engine = KeyboardEngine()
let examples = [("mses", "ma "), ("msed", "má "), ("msej", "mả "), ("xvns", "xin "),
                ("jsos", "chao "), ("dses", "đa "), ("zses", "za "), ("rwos", "răo "),
                ("iues", "khwiê "), ("hhef", "hwà "), ("jles", "chuô "), ("mlnd", "muốn "),
                ("frej", "fở "), ("imoj", "khwỉo "), ("teqd", "tiếng "), ("xaqs", "xoong "), ("baqs", "boong "), ("sacd", "soóc "), ("tsos", "tao ")]
for (keys, output) in examples { expect(type(keys, into: &engine) == .commit(output), "ASCII+ \(keys) -> \(output)") }
let expectedVowels: [String: String] = [
    "a":"oo", "w":"ă", "s":"a", "z":"â", "e":"iê", "d":"e", "x":"ê", "r":"ơ", "f":"o", "c":"ô", "t":"ư", "g":"u", "v":"i",
    "y":"wă", "h":"wa", "b":"wâ", "u":"wiê", "j":"we", "n":"wê", "i":"wơ", "k":"wo", "m":"wi", "o":"ươ", "l":"uô"]
expect(expectedVowels.count == 24, "combined map has 24 unique physical positions")
for (physical, expected) in expectedVowels {
    let choice = ASCIIPlusMapping.bindings(for: .onglideCoreVowel)[key(physical.first!)]!
    expect(engine.inventory.vowelAtoms[choice].label == expected, "exact supplied combined binding \(physical)")
}
let expectedInitials = ["j":"ch", "y":"d", "d":"đ", "i":"kh", "q":"ng", "w":"nh", "f":"f", "u":"th", "o":"tr", "e":""]
for (physical, expected) in expectedInitials {
    let index = ASCIIPlusMapping.bindings(for: .initial)[key(physical.first!)]!
    expect(engine.inventory.initials[index] == expected, "exact initial binding \(physical)")
}
expect(!engine.inventory.finals.contains("u") && engine.inventory.finals.contains("o"), "Final inventory replaces u with o")
expect(ASCIIPlusMapping.bindings(for: .final)[key("o")] == engine.inventory.finals.firstIndex(of: "o"), "o key chooses final o")
expect(ASCIIPlusMapping.bindings(for: .final)[key("u")] == nil, "u no longer chooses a final")
var finalGuide = KeyboardEngine()
_ = type("ms", into: &finalGuide)
expect(ASCIIPlusMapping.actions(for: finalGuide)[key("o")] == "o" && ASCIIPlusMapping.actions(for: finalGuide)[key("u")] == nil, "Guide follows final o mapping")
let expectedTones: [Character: VietnameseTone] = ["s":.ngang, "d":.sac, "f":.huyen, "j":.hoi, "k":.nga, "l":.nang]
for (physical, expected) in expectedTones { expect(ASCIIPlusMapping.bindings(for: .tone)[key(physical)] == expected.rawValue, "exact tone binding") }
expect(ASCIIPlusMapping.bindings(for: .onglideCoreVowel)[key("a")] == engine.inventory.vowelAtoms.firstIndex { $0.label == "oo" }, "a chooses oo in round two")
for phase in Phase.allCases {
    expect(!ASCIIPlusMapping.inputKeyCodes(for: phase).contains(41), "semicolon remains ordinary punctuation in every round")
}
for unused in ["p", "q"] { expect(ASCIIPlusMapping.bindings(for: .onglideCoreVowel)[key(unused.first!)] == nil, "unused modal letters do not select a vowel") }
expect(!ASCIIPlusMapping.inputKeyCodes(for: .onglideCoreVowel).contains(43), "comma is ordinary punctuation in every round")
let counts = [25, 24, 11, 6]
let bindingsByPhase = Phase.allCases.map { ASCIIPlusMapping.bindings(for: $0) }
for phase in Phase.allCases {
    let bindings = bindingsByPhase[phase.rawValue]
    expect(Set(bindings.values) == Set(0..<counts[phase.rawValue]), "complete inventory coverage")
    expect(bindings.count == Set(bindings.values).count, "one physical key per default atom")
    expect(bindings[49] == nil && bindings[51] == nil && bindings[53] == nil, "semicolonnds cannot become atoms")
}
var remap = ASCIIPlusKeymap.sieuviet
remap.initials["b"] = "m"; remap.initials["m"] = "b"
expect(type("bses", into: &engine, keymap: remap) == .commit("ma "), "remap physical positions without changing atoms")
let decoded = try JSONDecoder().decode(ASCIIPlusKeymap.self, from: JSONEncoder().encode(remap))
expect(decoded == remap, "new keymaps are serializable with schema version")
var inventory = VietnamesePhoneticInventory.sieuviet
inventory.initials.reverse(); inventory.coreVowels.reverse(); inventory.onglides.reverse(); inventory.finals.reverse()
var reordered = KeyboardEngine(inventory: inventory)
expect(type("msed", into: &reordered) == .commit("má "), "named bindings survive inventory reordering")
for row in ASCIIKeyboardLayout.rows { expect(abs(row.reduce(0) { $0 + $1.units } - 14.5) < 0.001, "popup rows align") }
let inverseBindings = bindingsByPhase.map { Dictionary(uniqueKeysWithValues: $0.map { ($0.value, $0.key) }) }
var paths = 0
for onset in engine.inventory.initials.indices {
    for vowel in engine.inventory.vowelAtoms.indices {
        for tone in VietnameseTone.allCases {
            for final in engine.inventory.finals.indices {
                var grid = KeyboardEngine(), ascii = KeyboardEngine()
                let values = [onset, vowel, final, tone.rawValue]
                var gridResult = EngineEffect.none, asciiResult = EngineEffect.none
                for phase in Phase.allCases {
                    let index = phase.rawValue
                    gridResult = grid.press(GridKey.actionSlots[values[index]])
                    let physical = inverseBindings[index][values[index]]!
                    asciiResult = ascii.selectComponent(bindingsByPhase[index][physical]!)
                }
                expect(gridResult == asciiResult && grid.lastCommittedBasis == ascii.lastCommittedBasis,
                       "grid and every ASCII+ physical path produce identical basis and display")
                paths += 1
            }
        }
    }
}
print("Passed \(checks) ASCII+ mapping checks (\(paths) physical-path equivalence cases).")
