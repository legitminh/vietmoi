import Foundation

// Render structured syllables rather than guessing which letters in a flat string
// are the onset, medial, nucleus, or coda. No dictionary or network is needed.
enum StandardVietnamese {
    private static let accented: [Character: [Character]] = [
        "a": Array("aáàảãạ"), "ă": Array("ăắằẳẵặ"), "â": Array("âấầẩẫậ"),
        "e": Array("eéèẻẽẹ"), "ê": Array("êếềểễệ"), "i": Array("iíìỉĩị"),
        "o": Array("oóòỏõọ"), "ô": Array("ôốồổỗộ"), "ơ": Array("ơớờởỡợ"),
        "u": Array("uúùủũụ"), "ư": Array("ưứừửữự"), "y": Array("yýỳỷỹỵ")
    ]

    // nil final means composition is still waiting for its fourth input.
    // In that case keep the selected diphthong form until the coda is known.
    static func render(initial: String, medial: String, nucleus: String, final: String?, tone: Int) -> String {
        var onset = initial
        var glide = medial
        var vowel = nucleus
        var coda = final ?? ""
        let rounded = !glide.isEmpty || onset == "qu"

        // The prototype's ei is the short-a + y rhyme, distinct from ai.
        if coda == "i", vowel == "e" || vowel == "ă" {
            vowel = "a"
            coda = "y"
        } else if coda == "i", vowel == "â" {
            coda = "y"
        } else if coda == "i", vowel == "ê" {
            // Standard spelling writes êi as ây and uêi as uây. Preserve
            // the explicitly requested buêi -> uây exception.
            vowel = "â"
            coda = "y"
            if onset == "b" && glide == "u" { onset = "" }
        } else if coda == "u", vowel == "ă" {
            vowel = "a"
        }

        // Open/closed spellings of the three diphthongs; vowel finals count
        // as codas too (e.g. iê + u -> iêu, ươ + i -> ươi).
        if ["ia", "iê"].contains(vowel) {
            let closed = final == nil ? vowel == "iê" : !coda.isEmpty
            vowel = closed ? (rounded || onset.isEmpty ? "yê" : "iê") : (rounded ? "ya" : "ia")
        } else if ["ua", "uô"].contains(vowel), final != nil {
            vowel = coda.isEmpty ? "ua" : "uô"
        } else if ["ưa", "ươ"].contains(vowel), final != nil {
            vowel = coda.isEmpty ? "ưa" : "ươ"
        }
        // A completed onsetless i syllable uses orthographic y. Do not apply
        // this while its final is still unknown or when i has a coda (in, im…).
        if final != nil && onset.isEmpty && glide.isEmpty && vowel == "i" && coda.isEmpty {
            vowel = "y"
        }
        if rounded && vowel == "i" { vowel = "y" }

        // Only the explicit qu onset is written q + u. A selected c/k onset and
        // u medial stay distinct (c + u + a + hỏi -> cuả), rather than being
        // silently rewritten as qu. The u of an explicit qu is never duplicated.
        if onset == "qu" {
            onset = "q"
            glide = "u"
        } else if rounded {
            // Preserve the explicit medial for c/k. Other onsets retain the
            // standard o/u spelling chosen from the following main vowel.
            if !["c", "k"].contains(onset) {
                if let first = vowel.first, "aăe".contains(first) { glide = "o" }
                else if let first = vowel.first, "âêiy".contains(first) { glide = "u" }
            }
        }

        let following = (glide + vowel).first
        let frontVowel = following.map { "eêi".contains($0) } ?? false
        if onset == "ng" && frontVowel { onset = "ngh" }
        if onset == "g" && frontVowel { onset = "gh" }
        if ["c", "k"].contains(onset) {
            onset = frontVowel || following == "y" ? "k" : "c"
        }
        // gi + i/iê/ia shares one i: gì, giếng, ...; gi + a is still gia.
        if onset == "gi" && glide.isEmpty && vowel.first == "i" { onset = "g" }

        var letters = Array(vowel)
        // Main-vowel convention: never put the tone on a medial or final glide.
        // Open ia/ya/ua/ưa take the first vowel; closed forms take the second.
        let position = ["iê", "yê", "uô", "ươ"].contains(vowel) ? 1 : 0
        if letters.indices.contains(position),
           let forms = accented[letters[position]], forms.indices.contains(tone) {
            letters[position] = forms[tone]
        }
        return (onset + glide + String(letters) + coda).precomposedStringWithCanonicalMapping
    }
}
