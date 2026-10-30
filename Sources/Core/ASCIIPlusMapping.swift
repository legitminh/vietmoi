import Foundation

enum ASCIIPlusMapping {
    private static func build(_ entries: [(String, Int)]) -> [UInt16: Int] {
        var result: [UInt16: Int] = [:]
        for (key, value) in entries {
            let code = key == " " ? UInt16(49) : ASCIIKeyboardLayout.keyCodesByLabel[key]!
            precondition(result[code] == nil, "Duplicate ascii+ binding: \(key)")
            result[code] = value
        }
        return result
    }
    static let initials = build(Array(zip(
        ["b","c","z","d","a","g","j","h","k","i","l","m","n","q","y","p","f","w","r","s","t","u","o","v","x","e"],
        KeyboardEngine.initials.indices)))
    // Each pre-vowel occupies six ergonomic positions. The final two keys are
    // nặng then ngã, as specified by the explicit ∅ + ngã -> i example.
    private static let toneOrder = [0, 1, 2, 3, 5, 4]
    static let medialTones = build(["weryui", "sdfhjk", "zxcbnm"].enumerated().flatMap { row, keys in
        keys.enumerated().map { column, key in
            (String(key), row * 6 + toneOrder[column])
        }
    })
    static let nuclei: [UInt16: Int] = build([
        ("a",0), ("s",1), ("d",2), ("e",3), ("r",4), ("i",5),
        ("o",6), ("p",7), ("y",8), ("h",9), ("j",10), ("u",11), ("k",12),
        // Preserve access to the additional nuclei from the original MVP.
        // c/l/w/v are spare keys for o/u/ua/uô, absent from the ascii+ spec.
        ("c",13), ("l",14), ("w",15), ("v",16)
    ])
    static let finals = build(Array(zip(
        ["e","c","z","i","m","n","q","y","o","p","t","u"],
        KeyboardEngine.finals.indices)))
    // Keys that belong to ASCII+ in at least one phase. Keys outside this set
    // are ordinary host input even while Vietnamese mode is active.
    static let inputKeyCodes = Set(initials.keys)
        .union(medialTones.keys)
        .union(nuclei.keys)
        .union(finals.keys)
    static func bindings(for phase: Phase) -> [UInt16: Int] {
        switch phase {
        case .initial: return initials
        case .medialTone: return medialTones
        case .nucleus: return nuclei
        case .final: return finals
        }
    }
    static func actions(for engine: KeyboardEngine) -> [UInt16: String] {
        var result: [UInt16: String] = [:]
        for (key, value) in bindings(for: engine.phase) { result[key] = engine.componentLabel(value) }
        result[56] = "ASCII"
        result[51] = engine.isPending ? "Undo" : "⌫"
        result[53] = "Cancel"
        result[117] = "Clear"
        result[36] = "Enter"
        result[48] = "Tab"
        return result
    }
}
