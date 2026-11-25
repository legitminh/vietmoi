#if !hasFeature(Embedded)
import Foundation
#endif

enum EnglishCompletion {
    /// The word being typed at the end of `context` (letters and apostrophes).
    static func prefix(of context: String) -> String {
        String(context.reversed().prefix { character in
            character == "'" || character.unicodeScalars.allSatisfy { CharacterSet.letters.contains($0) }
        }.reversed())
    }

    static func suffixes(context: String, complete: (String) -> [String], limit: Int = 9) -> [String] {
        let prefix = Self.prefix(of: context)
        guard prefix.count >= 2, prefix.count <= 64 else { return [] }
        var seen = Set<String>()
        return complete(prefix).compactMap { word in
            guard word.count > prefix.count, word.lowercased().hasPrefix(prefix.lowercased()) else { return nil }
            let suffix = String(word.dropFirst(prefix.count))
            return seen.insert(suffix).inserted ? suffix : nil
        }.prefix(limit).map { $0 }
    }
}
