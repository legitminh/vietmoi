import Foundation

// Each round binds physical positions to typed atoms, independent of inventory order.
struct ASCIIPlusKeymap: Codable, Equatable {
    var initials: [String: String]
    var vowels: [String: VietnameseVowelAtom]
    var tones: [String: VietnameseTone]
    var finals: [String: String]

    static let sieuviet = ASCIIPlusKeymap(
        initials: ["b":"b", "c":"c", "j":"ch", "y":"d", "d":"đ", "g":"g", "z":"z",
                   "h":"h", "k":"k", "i":"kh", "l":"l", "m":"m", "n":"n", "a":"ng",
                   "w":"nh", "p":"p", "f":"f", "r":"r", "s":"s", "t":"t", "u":"th",
                   "e":"tr", "v":"v", "x":"x", "q":"q", "o":""],
        vowels: Dictionary(uniqueKeysWithValues:
            [("a","oo"), ("w","ă"), ("s","a"), ("z","â"), ("e","iê"), ("d","e"), ("x","ê"),
             ("r","ơ"), ("f","o"), ("c","ô"), ("t","ư"), ("g","u"), ("v","i"), ("o","ươ"), ("l","uô")]
                .map { ($0.0, VietnameseVowelAtom(onglide: "", coreVowel: $0.1)) } +
            [("y","ă"), ("h","a"), ("b","â"), ("u","iê"), ("j","e"), ("n","ê"), ("i","ơ"),
             ("k","o"), ("m","i")]
                .map { ($0.0, VietnameseVowelAtom(onglide: "w", coreVowel: $0.1)) }),
        tones: ["s":.ngang, "d":.sac, "f":.huyen, "j":.hoi, "k":.nga, "l":.nang],
        finals: ["e":"", "c":"c", "j":"ch", "m":"m", "n":"n", "a":"ng", "w":"nh",
                 "p":"p", "t":"t", "o":"o", "i":"i"])

    static let quocNgu: ASCIIPlusKeymap = {
        var value = Self.sieuviet
        value.initials["z"] = "gi"; value.initials["f"] = "ph"
        value.vowels = Dictionary(uniqueKeysWithValues:
            [("a","oo"), ("q","yê"), ("w","ă"), ("s","a"), ("z","â"), ("e","ia"),
             ("d","e"), ("x","ê"), ("r","ơ"), ("f","o"), ("c","ô"), ("t","ư"), ("g","u"),
             ("v","i"), ("y","oă"), ("h","oa"), ("b","uâ"), ("u","uya"), ("j","oe"),
             ("n","uê"), ("i","uơ"), ("m","ui"), ("o","ươ"), ("l","uô"), ("p","ưa")]
                .map { ($0.0, VietnameseVowelAtom(onglide: "", coreVowel: $0.1)) })
        value.finals["u"] = "u"
        return value
    }()

    private static let version6Initials = [
        "b":"b", "c":"c", "j":"ch", "y":"d", "d":"đ", "g":"g", "z":"z",
        "h":"h", "k":"k", "i":"kh", "l":"l", "m":"m", "n":"n", "q":"ng",
        "w":"nh", "p":"p", "f":"f", "r":"r", "s":"s", "t":"t", "u":"th",
        "o":"tr", "v":"v", "x":"x", "e":""
    ]
    private static let version7Finals = [
        "e":"", "c":"c", "j":"ch", "m":"m", "n":"n", "q":"ng", "w":"nh",
        "p":"p", "t":"t", "o":"o", "i":"i"
    ]

    private static let version5Vowels: [String: VietnameseVowelAtom] = Dictionary(uniqueKeysWithValues:
            [("t","ă"), ("g","a"), ("b","â"), ("y","iê"), ("h","e"), ("n","ê"), ("u","ơ"),
             ("j","o"), ("m","ô"), ("i","ư"), ("k","u"), ("o","i"), ("p","ươ"), ("l","uô"), (";","oo")]
                .map { ($0.0, VietnameseVowelAtom(onglide: "", coreVowel: $0.1)) } +
            [("q","ă"), ("a","a"), ("z","â"), ("w","iê"), ("s","e"), ("x","ê"), ("e","ơ"),
             ("d","o"), ("c","ô"), ("r","ư"), ("f","u"), ("v","i")]
                .map { ($0.0, VietnameseVowelAtom(onglide: "w", coreVowel: $0.1)) })

    private static let version2Vowels: [String: VietnameseVowelAtom] = Dictionary(uniqueKeysWithValues:
            [("t","a"), ("g","ă"), ("b","â"), ("y","e"), ("h","ê"), ("n","i"), ("u","o"),
             ("j","ơ"), ("m","ô"), ("i","u"), ("k","ư"), ("o","iê"), ("l","ươ"), ("p","uô"), (",","oo")]
                .map { ($0.0, VietnameseVowelAtom(onglide: "", coreVowel: $0.1)) } +
            [("q","a"), ("a","ă"), ("z","â"), ("w","e"), ("s","ê"), ("x","i"), ("e","o"),
             ("d","ơ"), ("c","ô"), ("r","u"), ("f","ư"), ("v","iê")]
                .map { ($0.0, VietnameseVowelAtom(onglide: "w", coreVowel: $0.1)) })

    init(initials: [String: String], vowels: [String: VietnameseVowelAtom],
         tones: [String: VietnameseTone], finals: [String: String]) {
        self.initials = initials; self.vowels = vowels; self.tones = tones; self.finals = finals
    }
    private enum CodingKeys: String, CodingKey { case version, initials, vowels, tones, finals }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let version = try values.decodeIfPresent(Int.self, forKey: .version) ?? 1
        if version >= 2 {
            initials = try values.decode([String: String].self, forKey: .initials)
            vowels = try values.decode([String: VietnameseVowelAtom].self, forKey: .vowels)
            tones = try values.decode([String: VietnameseTone].self, forKey: .tones)
            finals = try values.decode([String: String].self, forKey: .finals)
            if version <= 4 {
                // Move the untouched default to o, without overwriting an existing
                // custom o binding. Custom positions follow the renamed atom.
                if finals["u"] == "u", finals["o"] == nil {
                    finals.removeValue(forKey: "u")
                    finals["o"] = "o"
                }
                finals = finals.mapValues { $0 == "u" ? "o" : $0 }
            }
            if version == 2 {
                let saved = vowels
                vowels = Self.version5Vowels
                for key in Self.version2Vowels.keys where saved[key] == nil { vowels.removeValue(forKey: key) }
                for (key, atom) in saved where Self.version2Vowels[key] != atom { vowels[key] = atom }
                if saved[","] == nil { vowels.removeValue(forKey: ";") }
            }
            if version <= 3, vowels[","] == VietnameseVowelAtom(onglide: "", coreVowel: "oo"), vowels[";"] == nil {
                vowels[";"] = vowels.removeValue(forKey: ",")
            }
            if version <= 5 {
                let saved = vowels
                vowels = Self.sieuviet.vowels
                // Preserve physical-key removals and actual overrides. Removed
                // rounded atoms remain serializable but cannot route into the
                // restricted inventory; never substitute a different vowel.
                for key in Self.version5Vowels.keys where saved[key] == nil { vowels.removeValue(forKey: key) }
                for (key, atom) in saved where Self.version5Vowels[key] != atom { vowels[key] = atom }
            }
            if version <= 6 {
                let saved = initials
                initials = Self.sieuviet.initials
                for key in Self.version6Initials.keys where saved[key] == nil { initials.removeValue(forKey: key) }
                for (key, atom) in saved where Self.version6Initials[key] != atom { initials[key] = atom }
            }
            if version <= 7 {
                let saved = finals
                finals = Self.sieuviet.finals
                for key in Self.version7Finals.keys where saved[key] == nil { finals.removeValue(forKey: key) }
                for (key, atom) in saved where Self.version7Finals[key] != atom { finals[key] = atom }
            }
        } else {
            // The old second/third rounds selected different kinds of atom. Reset
            // those to the new layout; retain actual initial/final custom overrides.
            self = Self.sieuviet
            let oldInitials = ["b":"b", "c":"c", "z":"z", "d":"d", "a":"đ", "g":"g", "j":"ch",
                               "h":"h", "k":"k", "i":"kh", "l":"l", "m":"m", "n":"n", "q":"ng",
                               "y":"nh", "p":"p", "f":"ph", "r":"r", "s":"s", "t":"t", "u":"th",
                               "o":"tr", "v":"v", "x":"x", "e":""]
            let oldFinals = ["e":"", "c":"c", "z":"ch", "i":"i", "m":"m", "n":"n", "q":"ng",
                             "y":"nh", "o":"o", "p":"p", "t":"t", "w":"w", "j":"j"]
            let savedInitials = try values.decodeIfPresent([String: String].self, forKey: .initials) ?? [:]
            let savedFinals = try values.decodeIfPresent([String: String].self, forKey: .finals) ?? [:]
            for (key, atom) in savedInitials where oldInitials[key] != atom {
                let migrated = atom == "ph" ? "f" : atom
                if VietnamesePhoneticInventory.sieuviet.initials.contains(migrated) { initials[key] = migrated }
            }
            for (key, atom) in savedFinals where oldFinals[key] != atom {
                let migrated = (atom == "w" || atom == "u") ? "o" : atom == "j" ? "i" : atom
                if VietnamesePhoneticInventory.sieuviet.finals.contains(migrated) { finals[key] = migrated }
            }
        }
    }
    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(8, forKey: .version)
        try values.encode(initials, forKey: .initials)
        try values.encode(vowels, forKey: .vowels)
        try values.encode(tones, forKey: .tones)
        try values.encode(finals, forKey: .finals)
    }
}

enum ASCIIPlusMapping {
    // US physical-position aliases, independent of a platform's numeric key codes.
    static func logicalBindings(for phase: Phase, inventory: VietnamesePhoneticInventory = .sieuviet,
                                keymap: ASCIIPlusKeymap = .sieuviet) -> [String: Int] {
        switch phase {
        case .initial: return keymap.initials.compactMapValues { inventory.initials.firstIndex(of: $0) }
        case .onglideCoreVowel:
            let atoms = inventory.vowelAtoms
            return keymap.vowels.compactMapValues { atoms.firstIndex(of: $0) }
        case .tone: return keymap.tones.mapValues(\.rawValue)
        case .final: return keymap.finals.compactMapValues { inventory.finals.firstIndex(of: $0) }
        }
    }
    static func bindings(for phase: Phase, inventory: VietnamesePhoneticInventory = .sieuviet,
                         keymap: ASCIIPlusKeymap = .sieuviet) -> [UInt16: Int] {
        var result: [UInt16: Int] = [:]
        for (key, index) in logicalBindings(for: phase, inventory: inventory, keymap: keymap) {
            guard key.count == 1, let code = ASCIIKeyboardLayout.keyCodesByLabel[key] else { continue }
            result[code] = index
        }
        return result
    }
    static func inputKeyCodes(for phase: Phase, inventory: VietnamesePhoneticInventory = .sieuviet,
                              keymap: ASCIIPlusKeymap = .sieuviet) -> Set<UInt16> {
        // Letters are always modal. Punctuation becomes an atom only in a round
        // that binds it; semicolon retains ordinary host behavior in the other rounds.
        Set(ASCIIKeyboardLayout.keyCodesByLabel.filter { ("a"..."z").contains($0.key) }.values)
            .union(bindings(for: phase, inventory: inventory, keymap: keymap).keys)
    }
    static func actions(for engine: KeyboardEngine, keymap: ASCIIPlusKeymap = .sieuviet) -> [UInt16: String] {
        var result: [UInt16: String] = [:]
        for (key, value) in bindings(for: engine.phase, inventory: engine.inventory, keymap: keymap) {
            result[key] = engine.componentLabel(value)
        }
        result[56] = "ASCII"
        result[51] = engine.isPending ? "Undo" : "⌫"
        result[53] = "Cancel"
        result[117] = "Clear"
        result[36] = "Enter"
        result[48] = "Tab"
        return result
    }
}
