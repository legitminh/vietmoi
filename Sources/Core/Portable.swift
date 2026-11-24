// Embedded Swift (the WebAssembly build of the web demo) has no Foundation. These
// stand-ins give the shared core the few Foundation APIs it uses, with the same
// meaning, so the core sources compile unchanged for every host. Native builds
// use Foundation itself and never compile this file's contents.
#if hasFeature(Embedded)
typealias TimeInterval = Double

/// RFC 4122 identifiers, as Foundation formats them (uppercase).
struct UUID: Hashable {
    private var bytes: [UInt8]
    init() {
        var generator = SystemRandomNumberGenerator()
        bytes = (0..<16).map { _ in UInt8.random(in: 0...255, using: &generator) }
        bytes[6] = bytes[6] & 0x0f | 0x40
        bytes[8] = bytes[8] & 0x3f | 0x80
    }
    init?(uuidString: String) {
        let digits = uuidString.utf8.filter { $0 != UInt8(ascii: "-") }
        guard uuidString.utf8.count == 36, digits.count == 32 else { return nil }
        var result: [UInt8] = []
        var high: UInt8? = nil
        for digit in digits {
            let value: UInt8
            switch digit {
            case UInt8(ascii: "0")...UInt8(ascii: "9"): value = digit - UInt8(ascii: "0")
            case UInt8(ascii: "a")...UInt8(ascii: "f"): value = digit - UInt8(ascii: "a") + 10
            case UInt8(ascii: "A")...UInt8(ascii: "F"): value = digit - UInt8(ascii: "A") + 10
            default: return nil
            }
            if let first = high { result.append(first << 4 | value); high = nil } else { high = value }
        }
        bytes = result
    }
    var uuidString: String {
        let hex = Array("0123456789ABCDEF".utf8)
        var text: [UInt8] = []
        for (index, byte) in bytes.enumerated() {
            if [4, 6, 8, 10].contains(index) { text.append(UInt8(ascii: "-")) }
            text.append(hex[Int(byte >> 4)]); text.append(hex[Int(byte & 0xf)])
        }
        return String(decoding: text, as: UTF8.self)
    }
}

/// Single-threaded WebAssembly: there is nothing to lock.
final class NSLock {
    func lock() {}
    func unlock() {}
}

/// The two Foundation sets the core reads, by Unicode general category as Foundation defines them.
struct CharacterSet {
    private let test: (Unicode.Scalar) -> Bool
    func contains(_ scalar: Unicode.Scalar) -> Bool { test(scalar) }
    /// Categories L* and M*.
    static let letters = CharacterSet { scalar in
        switch scalar.properties.generalCategory {
        case .uppercaseLetter, .lowercaseLetter, .titlecaseLetter, .modifierLetter, .otherLetter,
             .nonspacingMark, .spacingMark, .enclosingMark: return true
        default: return false
        }
    }
    /// Categories Cc and Cf.
    static let controlCharacters = CharacterSet { scalar in
        switch scalar.properties.generalCategory {
        case .control, .format: return true
        default: return false
        }
    }
}

extension StringProtocol {
    /// Character-wise substring search, as Foundation's contains(_:) on strings.
    func range(of target: String) -> Range<Index>? {
        guard let first = target.first else { return nil }
        var start = startIndex
        while let match = self[start...].firstIndex(of: first) {
            if self[match...].starts(with: target) {
                return match..<index(match, offsetBy: target.count)
            }
            start = index(after: match)
        }
        return nil
    }
    func contains(_ other: String) -> Bool { other.isEmpty || range(of: other) != nil }
}

enum ComparisonResult: Int { case orderedAscending = -1, orderedSame = 0, orderedDescending = 1 }

extension String {
    /// Unicode NFC, from the standard library's normalizer.
    var precomposedStringWithCanonicalMapping: String { String(decoding: _nfcCodeUnits, as: UTF8.self) }

    func replacingOccurrences(of target: String, with replacement: String) -> String {
        guard !target.isEmpty else { return self }
        var result = "", rest = self[...]
        while let range = rest.range(of: target) {
            result += rest[..<range.lowerBound]
            result += replacement
            rest = rest[range.upperBound...]
        }
        return result + rest
    }

    /// Approximates Foundation's Finder-like order for the core's Latin (Vietnamese) text:
    /// base letters first, ignoring case and accents (đ right after d), then accents,
    /// then case; digit runs compare by value. The core uses it only to break score ties.
    func localizedStandardCompare(_ other: String) -> ComparisonResult {
        let left = Self.collationKey(self), right = Self.collationKey(other)
        for level in 0..<3 {
            if let order = Self.compare(left[level], right[level]) { return order }
        }
        return .orderedSame
    }
    private static func compare(_ left: [UInt32], _ right: [UInt32]) -> ComparisonResult? {
        for (a, b) in zip(left, right) where a != b { return a < b ? .orderedAscending : .orderedDescending }
        return left.count == right.count ? nil : left.count < right.count ? .orderedAscending : .orderedDescending
    }
    /// Primary (base letters, digit runs by value), secondary (accents) and tertiary (case) keys.
    private static func collationKey(_ text: String) -> [[UInt32]] {
        var primary: [UInt32] = [], secondary: [UInt32] = [], tertiary: [UInt32] = []
        var number: UInt32? = nil
        func flush() { if let value = number { primary.append(0x30); primary.append(value); number = nil } }
        for scalar in text.decomposedScalars {
            if let digit = scalar.properties.numericType == .decimal ? scalar.properties.numericValue : nil {
                number = (number ?? 0) &* 10 &+ UInt32(digit)
                continue
            }
            flush()
            switch scalar.properties.generalCategory {
            case .nonspacingMark, .spacingMark, .enclosingMark:
                secondary.append(scalar.value)
                continue
            default: break
            }
            let lower = scalar.properties.lowercaseMapping.unicodeScalars.first ?? scalar
            switch lower {
            case "đ": primary.append(UInt32(("d" as Unicode.Scalar).value) << 8 | 1); secondary.append(0x111)
            default: primary.append(lower.value << 8)
            }
            secondary.append(0)
            tertiary.append(lower == scalar ? 0 : 1)
        }
        flush()
        return [primary, secondary, tertiary]
    }
    /// Canonical decomposition of Latin letters with Vietnamese and common European accents.
    private var decomposedScalars: [Unicode.Scalar] {
        var result: [Unicode.Scalar] = []
        for scalar in unicodeScalars {
            if let parts = Self.decompositions[scalar] { result.append(contentsOf: parts) } else { result.append(scalar) }
        }
        return result
    }
    /// Built once from the standard library's NFC composer: each composed letter → base + marks.
    private static let decompositions: [Unicode.Scalar: [Unicode.Scalar]] = {
        let bases = Array("aeiouyAEIOUYcCnN".unicodeScalars)
        let tones: [Unicode.Scalar] = ["\u{300}", "\u{301}", "\u{303}", "\u{309}", "\u{323}"]
        let shapes: [Unicode.Scalar] = ["\u{302}", "\u{306}", "\u{31B}"]
        let marks = (tones + shapes + ["\u{308}", "\u{327}"]).map { [$0] } + shapes.flatMap { shape in tones.map { [shape, $0] } }
        var table: [Unicode.Scalar: [Unicode.Scalar]] = [:]
        for base in bases {
            for combination in marks {
                var view = String.UnicodeScalarView()
                view.append(base)
                view.append(contentsOf: combination)
                let composed = String(view).precomposedStringWithCanonicalMapping.unicodeScalars
                if composed.count == 1, let scalar = composed.first { table[scalar] = [base] + combination }
            }
        }
        return table
    }()
}
#endif
