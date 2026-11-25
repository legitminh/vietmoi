// Number picks on computers. While suggestions are shown, the number keys 1–9 accept
// the matching suggestion. "-" escapes the next key, so digits stay typeable:
// "a" + "-2" → "a2", and "-" + "-" → "-". Hosts own the keys; this only decides.
struct SuggestionNumberKeys {
    enum Outcome: Equatable {
        /// Accept the suggestion at this index (0-based).
        case pick(Int)
        /// Swallow this "-": it escapes the next key.
        case escape
        /// The key types as usual (an escaped digit or "-", or any key that is not ours).
        case pass
        /// An escape was pending and the next key is neither a digit nor "-": type the
        /// held "-" first, then the key as usual.
        case minusThenPass
    }

    /// True after a "-" that escapes the next key.
    private(set) var escaping = false

    /// `text` is what the key types without Shift ("1", "-", "a"); `shown` counts the
    /// suggestions on screen and is read only for a digit or "-".
    mutating func key(_ text: String, shown: () -> Int) -> Outcome {
        if escaping {
            escaping = false
            if text == "-" || Self.digit(text) != nil { return .pass }
            return Self.printable(text) ? .minusThenPass : .pass
        }
        if text == "-" {
            guard shown() > 0 else { return .pass }
            escaping = true
            return .escape
        }
        if let digit = Self.digit(text), digit > 0, digit <= 9, digit <= shown() { return .pick(digit - 1) }
        return .pass
    }

    /// Backspace or Escape drops a pending escape. Returns true when there was one (the key is then used up).
    mutating func cancel() -> Bool {
        defer { escaping = false }
        return escaping
    }

    mutating func reset() { escaping = false }

    private static func digit(_ text: String) -> Int? {
        let scalars = Array(text.unicodeScalars)
        guard scalars.count == 1, scalars[0].value >= 48, scalars[0].value <= 57 else { return nil }
        return Int(scalars[0].value - 48)
    }

    private static func printable(_ text: String) -> Bool {
        let scalars = Array(text.unicodeScalars)
        return scalars.count == 1 && scalars[0].value >= 0x20 && scalars[0].value != 0x7f
    }
}
