import Foundation

// The phonetic basis is independent of physical keys and display orthography.
// Empty optional atoms are "", never literal spaces. Completed cycles and explicit Space boundaries add a space.
struct VietnameseVowelAtom: Codable, Equatable, Hashable {
    var onglide: String
    var coreVowel: String
    var label: String { onglide + coreVowel }
}

struct VietnamesePhoneticInventory: Equatable {
    var initials = ["b", "c", "ch", "d", "đ", "g", "z", "h", "k", "kh", "l", "m",
                    "n", "ng", "nh", "p", "f", "r", "s", "t", "th", "tr", "v", "x", ""]
    var onglides = ["", "w"]
    var coreVowels = ["a", "ă", "â", "e", "ê", "i", "o", "ơ", "ô", "u", "ư", "iê", "ươ", "uô", "oo"]
    // Only the requested rounded combinations are selectable. Keep the combined
    // inventory in the user's order for grid input, independent of physical keys.
    var roundedCoreVowels = ["ă", "a", "â", "iê", "e", "ê", "ơ", "o", "i"]
    var vowelAtoms: [VietnameseVowelAtom] {
        ["oo", "ă", "a", "â", "iê", "e", "ê", "ơ", "o", "ô", "ư", "u", "i",
         "wă", "wa", "wâ", "wiê", "we", "wê", "wơ", "wo", "wi", "ươ", "uô"].compactMap { label in
            let onglide = label.hasPrefix("w") ? "w" : ""
            let core = onglide.isEmpty ? label : String(label.dropFirst())
            guard onglides.contains(onglide), coreVowels.contains(core),
                  onglide.isEmpty || roundedCoreVowels.contains(core) else { return nil }
            return VietnameseVowelAtom(onglide: onglide, coreVowel: core)
        }
    }
    var finals = ["", "c", "ch", "m", "n", "ng", "nh", "p", "t", "o", "i"]
    // Character offsets within a core atom. Tone never attaches to on/offglides.
    var toneAnchors = ["iê": 1, "ươ": 1, "uô": 1, "oo": 1]
    static let sieuviet = VietnamesePhoneticInventory()
}

enum VietnameseTone: Int, Codable, CaseIterable {
    case ngang, sac, huyen, hoi, nga, nang
    var preview: String { ["", "´", "ˋ", "?", "˜", "."][rawValue] }
    var label: String { ["∅", "´", "`", "̉", "~", "."][rawValue] }
    var name: String { ["ngang", "sắc", "huyền", "hỏi", "ngã", "nặng"][rawValue] }
}

struct VietnamesePhoneticBasis: Codable, Equatable {
    var initial: String
    var onglide: String
    var coreVowel: String
    var tone: VietnameseTone
    var final: String

    // A stable, serializable viet.phonetic.basis schema, without parsing displayed text.
    private enum CodingKeys: String, CodingKey {
        case initial = "vietnamese_initial", onglide = "vietnamese_onglide"
        case coreVowel = "vietnamese_core_vowel", tone = "vietnamese_tone", final = "vietnamese_final"
    }
    func sieuviet(inventory: VietnamesePhoneticInventory = .sieuviet) -> String {
        var letters = Array(coreVowel)
        let anchor = inventory.toneAnchors[coreVowel] ?? 0
        if letters.indices.contains(anchor) {
            letters[anchor] = VietnameseToneMarks.apply(tone, to: letters[anchor])
        }
        return (initial + onglide + String(letters) + final).precomposedStringWithCanonicalMapping
    }
    // Called only once a tone choice completes all four construction rounds.
    func standard() -> String { StandardVietnamese.render(self) }
}

enum VietnameseToneMarks {
    private static let forms: [Character: [Character]] = [
        "a": Array("aáàảãạ"), "ă": Array("ăắằẳẵặ"), "â": Array("âấầẩẫậ"),
        "e": Array("eéèẻẽẹ"), "ê": Array("êếềểễệ"), "i": Array("iíìỉĩị"),
        "o": Array("oóòỏõọ"), "ô": Array("ôốồổỗộ"), "ơ": Array("ơớờởỡợ"),
        "u": Array("uúùủũụ"), "ư": Array("ưứừửữự"), "y": Array("yýỳỷỹỵ")
    ]
    static func apply(_ tone: VietnameseTone, to character: Character) -> Character {
        forms[character]?[tone.rawValue] ?? character
    }
}

// A second boundary check protects IMK clients even if a future mapping contains bad data.
enum CompositionText {
    static func isSafe(_ text: String) -> Bool {
        text.unicodeScalars.allSatisfy {
            !CharacterSet.controlCharacters.contains($0) && !(0xE000...0xF8FF).contains($0.value)
        }
    }
}
