// Adaptive punctuation. A Vietnamese block commits with an automatic trailing space,
// so a phrase mark typed right after it would land after that space ("mệt quá !").
// When the text before the caret is still exactly the block (or the result of an
// earlier rewrite), the host replaces it with the block, the mark and one space:
// "mệt quá " + "!" → "mệt quá! ", and a further "!" → "mệt quá!! ".
// Every app shares this rule; hosts only verify and edit their own document.
enum AdaptivePunctuation {
    /// Phrase marks that attach to the word before them in Vietnamese.
    static let marks: Set<Unicode.Scalar> = [",", ".", "?", "!", ";", ":", "…"]

    static func isMark(_ scalar: Unicode.Scalar) -> Bool { marks.contains(scalar) }

    /// The replacement for `tail` (the automatic block just before the caret) when
    /// `text` is typed, or nil to type `text` as usual.
    static func rewrite(tail: String?, typing text: String) -> String? {
        guard let tail = tail, tail.hasSuffix(" "), !tail.hasSuffix("  "),
              text.unicodeScalars.count == 1, let scalar = text.unicodeScalars.first, isMark(scalar) else { return nil }
        return String(tail.dropLast()) + text + " "
    }
}

/// The comma and period keys of an on-screen keyboard's letter layer type the
/// language's own marks. Number and symbol panes always type their printed ASCII.
enum LetterLayerPunctuation {
    static func mark(_ text: String, language: KeyboardLanguage) -> String {
        guard language == .chinese else { return text }
        switch text {
        case ",": return "，"
        case ".": return "。"
        default: return text
        }
    }
}
