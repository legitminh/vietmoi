import Foundation

var checks = 0
func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    checks += 1
    if !condition() { fatalError("FAILED: \(message)") }
}
func type(_ keys: [Int], into engine: inout KeyboardEngine) -> EngineEffect {
    var effect = EngineEffect.none
    for key in keys { effect = engine.press(key) }
    return effect
}
var engine = KeyboardEngine()
expect(type([11,0,0,0], into: &engine) == .commit("ma "), "ma with ngang separator")
expect(type([11,1,0,0], into: &engine) == .commit("ma´"), "má custom output")
expect(type([20,0,3,3], into: &engine) == .commit("tei "), "tay is entered as tei")
expect(type([1,0,13,5], into: &engine) == .commit("con "), "missing o nucleus restored")
expect(type([21,0,14,0], into: &engine) == .commit("thu "), "missing u nucleus restored")
expect(type([11,0,15,0], into: &engine) == .commit("mua "), "missing ua nucleus restored")
expect(type([11,1,16,5], into: &engine) == .commit("muôn´"), "missing uô nucleus restored")
expect(type([26,0,0,0], into: &engine) == .commit("a "), "empty initial skips reserved Shift slot")
expect(type([1,12,0,5], into: &engine) == .commit("cuan~"), "medial u + ngã on row two")
expect(type([1,19,0,5], into: &engine) == .commit("coan?"), "medial o + standalone hỏi on row three")
expect(engine.phase == .initial && !engine.isPending, "commit resets phase")
_ = engine.press(11)
expect(engine.press(6) == .none && engine.phase == .medialTone, "unused tone key does not advance")
_ = engine.press(0)
_ = engine.press(0)
expect(engine.backspace() == .marked("m"), "backspace undoes nucleus")
expect(engine.backspace() == .marked("m"), "backspace undoes tone")
expect(engine.backspace() == .cancel && !engine.isPending, "backspace undoes initial")
expect(engine.press(31) == .deleteCycle, "clear completed cycle")
_ = engine.press(11)
expect(engine.press(31) == .cancel, "clear incomplete cycle")
_ = engine.press(11)
expect(engine.press(24) == .cancel && engine.ascii && !engine.isPending, "mode switch cancels partial")
expect(engine.press(31) == .none && engine.ascii, "m stays literal in ASCII")
_ = engine.press(24)
expect(!engine.ascii && engine.phase == .initial, "return from ASCII")
let cycle = CommittedCycle(text: "a😀", range: NSRange(location: 4, length: 3))
expect(cycle.canDelete(selection: NSRange(location: 7, length: 0), actualText: "a😀"), "UTF16 deletion range")
expect(!cycle.canDelete(selection: NSRange(location: 8, length: 0), actualText: "a😀"), "reject moved caret")
expect(!cycle.canDelete(selection: NSRange(location: 7, length: 1), actualText: "a😀"), "reject selection")
expect(!cycle.canDelete(selection: NSRange(location: 7, length: 0), actualText: "abc"), "reject changed text")
expect(!cycle.canDelete(selection: NSRange(location: 7, length: 0), actualText: nil), "reject unavailable document access")
// Every exposed path completes in exactly four selections with no inaccessible inventory entries.
for initial in KeyboardEngine.initials.indices {
    for tone in 0..<18 {
        for nucleus in KeyboardEngine.nuclei.indices {
            for final in KeyboardEngine.finals.indices {
                let initialKey = GridKey.actionSlots[initial]
                let toneKey = (tone / 6) * 8 + tone % 6
                var candidate = KeyboardEngine()
                let result = type([initialKey, toneKey, GridKey.actionSlots[nucleus], GridKey.actionSlots[final]], into: &candidate)
                if case .commit(let text) = result {
                    expect(!text.isEmpty && !candidate.isPending, "all inventory paths commit")
                } else { fatalError("unreachable inventory combination") }
            }
        }
    }
}
print("Passed \(checks) checks (including all 95,472 inventory combinations).")
