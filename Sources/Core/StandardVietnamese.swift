import Foundation

// Quốc ngữ is a renderer of a completed phonetic basis. It never parses the
// displayed preview or changes the user's chosen atoms. Rules follow the notes
// in this project and https://en.wikipedia.org/wiki/Vietnamese_alphabet#Spelling.
enum StandardVietnamese {
    static func render(_ basis: VietnamesePhoneticBasis) -> String {
        parts(basis).joined().precomposedStringWithCanonicalMapping
    }
    // Keep orthography and its component boundaries together. Touch keyboards
    // can apply Shift to chosen atoms without duplicating spelling rules.
    static func parts(_ basis: VietnamesePhoneticBasis) -> [String] {
        var onset = basis.initial == "f" ? "ph" : basis.initial == "z" ? "gi" : basis.initial
        let rounded = basis.onglide == "w"
        let qu = rounded && ["c", "k"].contains(onset)
        let core = basis.coreVowel
        var vowel = core
        var coda = basis.final

        // /w/ is o after long a/e, u elsewhere; /j/ is y after short ă/â.
        // ă itself becomes a in au/ay, preserving ao/ai for the long vowel.
        if coda == "o" {
            coda = ["a", "e"].contains(core) ? "o" : "u"
            if core == "ă" { vowel = "a" }
        } else if coda == "i" {
            if ["ă", "â"].contains(core) { coda = "y" }
            if core == "ă" { vowel = "a" }
        }

        // Hanoi front-vowel allophones of /k, ŋ/ use ch/nh. Explicit ch/nh
        // choices are retained too, so the input inventory supports both analyses.
        if ["e", "ê", "i"].contains(core) {
            if coda == "c" { coda = "ch" }
            if coda == "ng" { coda = "nh" }
            if core == "e", ["ch", "nh"].contains(coda) { vowel = "a" }
        }

        let closed = !basis.final.isEmpty
        switch core {
        case "iê":
            vowel = closed ? (rounded || onset.isEmpty ? "yê" : "iê") : (rounded ? "ya" : "ia")
        case "uô": vowel = closed ? "uô" : "ua"
        case "ươ": vowel = closed ? "ươ" : "ưa"
        case "i":
            // Use the project's existing y convention for a standalone syllable;
            // ordinary consonant+i stays i. Rounded /wi/ always uses uy.
            if rounded || (onset.isEmpty && !closed) { vowel = "y" }
        default: break
        }

        let glide: String
        if rounded {
            glide = qu || !["a", "ă", "e"].contains(core) ? "u" : "o"
        } else { glide = basis.onglide }
        if qu { onset = "q" }
        else {
            let front = (glide + vowel).first.map { "eêiy".contains($0) } ?? false
            if onset == "ng", front { onset = "ngh" }
            if onset == "g", front { onset = "gh" }
            if ["c", "k"].contains(onset) { onset = front ? "k" : "c" }
        }
        // gi shares the first i of i/iê/ia, but that i remains the tone anchor.
        if onset == "gi", glide.isEmpty, vowel.first == "i" { onset = "g" }

        var letters = Array(vowel)
        // Main-vowel tone placement: hoá/huỷ; closed diphthongs take ê/ô/ơ,
        // open ia/ua/ưa take their first vowel. Explicit oo takes the second o.
        let anchor = ["iê", "yê", "uô", "ươ", "oo"].contains(vowel) ? 1 : 0
        if letters.indices.contains(anchor) {
            letters[anchor] = VietnameseToneMarks.apply(basis.tone, to: letters[anchor])
        }
        return [onset, glide + String(letters), coda]
    }
}
