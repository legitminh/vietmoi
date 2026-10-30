import Foundation

var checks = 0
func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    checks += 1
    if !condition() { fatalError("FAILED: \(message)") }
}
func key(_ character: Character) -> UInt16 {
    character == " " ? 49 : ASCIIKeyboardLayout.keyCodesByLabel[String(character)]!
}
func type(_ text: String, into engine: inout KeyboardEngine) -> EngineEffect {
    var result: EngineEffect = .none
    for character in text {
        guard let value = ASCIIPlusMapping.bindings(for: engine.phase)[key(character)] else { fatalError("Unmapped example key") }
        result = engine.selectComponent(value)
    }
    return result
}
var engine = KeyboardEngine()
expect(type("mwae", into: &engine) == .commit("ma "), "ma with empty final")
expect(type("meae", into: &engine) == .commit("ma´"), "má uses e for sắc")
expect(type("xwin", into: &engine) == .commit("xin "), "xin")
expect(type("zwao", into: &engine) == .commit("chao "), "ch initial uses z")
expect(type("awae", into: &engine) == .commit("đa "), "đ initial uses a")
expect(type("twei", into: &engine) == .commit("tei "), "tay entered as tei")
expect(type("khae", into: &engine) == .commit("kua?"), "u medial + standalone hỏi uses h")
expect(type("hcae", into: &engine) == .commit("hoa`"), "o medial + huyền uses c")
expect(type("mwue", into: &engine) == .commit("mia "), "u nucleus selects corrected ia")
expect(type("nwiy", into: &engine) == .commit("ninh "), "final y selects nh")
expect(type("ywie", into: &engine) == .commit("nhi "), "initial y selects nh")
expect(type("uwce", into: &engine) == .commit("tho "), "th initial and extra o nucleus")
expect(type("twle", into: &engine) == .commit("tu "), "spare l preserves u nucleus")
expect(type("mwwe", into: &engine) == .commit("mua "), "spare w preserves ua nucleus")
expect(type("mevn", into: &engine) == .commit("muôn´"), "spare v preserves uô nucleus")
expect(type("ewae", into: &engine) == .commit("a "), "e initial selects no onset")

expect(type("owae", into: &engine) == .commit("tra "), "o initial selects tr")
expect(ASCIIPlusMapping.finals[49] == nil, "Space is no longer a final action")

let toneOrder = [0, 1, 2, 3, 5, 4]
for (row, keys) in ["weryui", "sdfhjk", "zxcbnm"].enumerated() {
    for (column, character) in keys.enumerated() {
        expect(ASCIIPlusMapping.medialTones[key(character)] == row * 6 + toneOrder[column],
               "new pre-vowel/tone layout maps \(character)")
    }
}
expect(ASCIIPlusMapping.medialTones[key("i")] == 4, "explicit empty pre-vowel + ngã maps to i")

// Every phoneme from the original engine must remain reachable, with no collisions per phase.
let inventories = [KeyboardEngine.initials.count, 18, KeyboardEngine.nuclei.count, KeyboardEngine.finals.count]
for phase in Phase.allCases {
    let bindings = ASCIIPlusMapping.bindings(for: phase)
    expect(Set(bindings.values) == Set(0..<inventories[phase.rawValue]), "complete component coverage")
    expect(bindings.count == Set(bindings.values).count, "one distinct key for every component")
}
for row in ASCIIKeyboardLayout.rows {
    expect(abs(row.reduce(0) { $0 + $1.units } - 14.5) < 0.001, "ASCII popup rows align")
}
expect(Set(ASCIIKeyboardLayout.keys.map(\.keyCode)).count == ASCIIKeyboardLayout.keys.count, "physical layout has no duplicate keys")
let initial = ASCIIPlusMapping.initials[key("m")]!
_ = engine.selectComponent(initial)
let tone = ASCIIPlusMapping.medialTones[key("w")]!
_ = engine.selectComponent(tone)
let vowel = ASCIIPlusMapping.nuclei[key("u")]!
_ = engine.selectComponent(vowel)
expect(engine.backspace() == .marked("m"), "component backspace also undoes ia")
expect(engine.clearCycle() == .cancel && engine.phase == .initial, "clear resets ASCII+ cycle")
_ = engine.selectComponent(initial)
expect(engine.press(24) == .cancel && engine.ascii, "Shift toggles literal ASCII and cancels partial cycle")
_ = engine.press(24)
expect(!engine.ascii && engine.phase == .initial, "Shift returns to phonemic input")

// The same selected components must render identically through both input methods.
for onset in KeyboardEngine.initials.indices {
    for tone in 0..<18 {
        for vowel in KeyboardEngine.nuclei.indices {
            for final in KeyboardEngine.finals.indices {
                var grid = KeyboardEngine(), ascii = KeyboardEngine()
                let gridKeys = [GridKey.actionSlots[onset], (tone / 6) * 8 + tone % 6,
                                GridKey.actionSlots[vowel], GridKey.actionSlots[final]]
                var gridResult: EngineEffect = .none, asciiResult: EngineEffect = .none
                for phase in Phase.allCases {
                    gridResult = grid.press(gridKeys[phase.rawValue])
                    let value = [onset, tone, vowel, final][phase.rawValue]
                    let physicalKey = ASCIIPlusMapping.bindings(for: phase).first { $0.value == value }!.key
                    asciiResult = ascii.selectComponent(ASCIIPlusMapping.bindings(for: phase)[physicalKey]!)
                }
                expect(gridResult == asciiResult && !ascii.isPending, "grid and ASCII+ must emit identical syllables")
            }
        }
    }
}
print("Passed \(checks) ASCII+ checks, including all 95,472 grid/ASCII+ equivalence cases.")
