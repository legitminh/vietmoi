/// An English word list for completion, the web counterpart of the system spell
/// checker the Apple keyboards ask. Lines are "word<TAB>rank", sorted by the
/// lowercased word; a lower rank is a more common word.
final class EnglishWordList {
    static var shared = EnglishWordList()
    private var keys: [String] = []     // lowercased, sorted
    private var words: [String] = []    // as listed (proper nouns keep their capitals)
    private var rank: [Int] = []
    var isAvailable: Bool { !keys.isEmpty }

    /// Reads the list a slice at a time, in idle time, so loading never blocks typing.
    final class Builder {
        private let contents: String
        private var position: String.Index
        private let list = EnglishWordList()
        private var sorted = true
        init(contents: String) { self.contents = contents; position = contents.startIndex }
        /// Reads up to `budget` lines. Returns the list once complete.
        func step(_ budget: Int) -> EnglishWordList? {
            var work = 0
            while position < contents.endIndex, work < budget {
                let end = contents.utf8[position...].firstIndex(of: UInt8(ascii: "\n")) ?? contents.endIndex
                let fields = contents[position..<end].split(separator: "\t")
                if let word = fields.first, !word.isEmpty {
                    let key = word.lowercased()
                    if let last = list.keys.last, key < last { sorted = false }
                    list.keys.append(key)
                    list.words.append(String(word))
                    list.rank.append(fields.count > 1 ? Int(fields[1]) ?? list.rank.count : list.rank.count)
                }
                position = end < contents.endIndex ? contents.index(after: end) : end
                work += 1
            }
            guard position >= contents.endIndex else { return nil }
            if !sorted {
                // A list that is not presorted still works, at the cost of one sort.
                let order = list.keys.indices.sorted { list.keys[$0] == list.keys[$1] ? list.rank[$0] < list.rank[$1] : list.keys[$0] < list.keys[$1] }
                list.keys = order.map { list.keys[$0] }; list.words = order.map { list.words[$0] }; list.rank = order.map { list.rank[$0] }
                sorted = true
            }
            return list
        }
    }

    /// Words starting with `prefix` (ignoring case), most common first, capitalized like the prefix.
    func completions(_ prefix: String, limit: Int = 16) -> [String] {
        let key = prefix.lowercased()
        guard !key.isEmpty, !keys.isEmpty else { return [] }
        var low = 0, high = keys.count
        while low < high {
            let middle = (low + high) / 2
            if keys[middle] < key { low = middle + 1 } else { high = middle }
        }
        var matches: [(word: String, rank: Int)] = []
        while low < keys.count, keys[low].hasPrefix(key) {
            matches.append((words[low], rank[low]))
            low += 1
        }
        matches.sort { $0.rank < $1.rank }
        let upper = prefix.count > 1 && prefix.allSatisfy { !$0.isLetter || $0.isUppercase }
        let capitalized = prefix.first?.isUppercase ?? false
        return matches.prefix(limit).map { match in
            upper ? match.word.uppercased() : capitalized ? match.word.prefix(1).uppercased() + match.word.dropFirst() : match.word
        }
    }
}
