import Foundation

// Microsoft (微软) double Pinyin. Each syllable uses an initial key and a
// final key; zero initials use o (aa/ee are accepted too). No tones are typed.
enum MicrosoftShuangpin {
    static let finals: [String: String] = [
        "a":"a", "o":"o", "e":"e", "i":"i", "u":"u", "v":"y",
        "ai":"l", "ei":"z", "ao":"k", "ou":"b", "an":"j", "en":"f",
        "ang":"h", "eng":"g", "er":"r", "ia":"w", "ua":"w", "ie":"x",
        "iao":"c", "iu":"q", "ian":"m", "in":"n", "iang":"d", "uang":"d",
        "ing":";", "iong":"s", "ong":"s", "uo":"o", "uai":"y", "ui":"v",
        "uan":"r", "un":"p", "ue":"t", "ve":"t", "van":"r", "vn":"p"
    ]
    static let keyLabels: [String: String] = [
        "q":"iu", "w":"ia/ua", "e":"e", "r":"uan/er", "t":"ue", "y":"uai/ü",
        "u":"sh · u", "i":"ch · i", "o":"uo/o", "p":"un", "a":"a",
        "s":"ong", "d":"iang/uang", "f":"en", "g":"eng", "h":"ang",
        "j":"an", "k":"ao", "l":"ai", ";":"ing", "z":"ei", "x":"ie",
        "c":"iao", "v":"zh · ui", "b":"ou", "n":"in", "m":"ian"
    ]
    static func codes(for syllable: String) -> [String] {
        let syllable = syllable.replacingOccurrences(of: "ü", with: "v")
        guard let first = syllable.first else { return [] }
        var initial: String
        var final: String
        if "aoe".contains(first) {
            initial = "o"
            final = syllable
        } else if let digraph = ["zh", "ch", "sh"].first(where: { syllable.hasPrefix($0) }) {
            initial = ["zh":"v", "ch":"i", "sh":"u"][digraph]!
            final = String(syllable.dropFirst(2))
        } else {
            initial = String(first)
            final = String(syllable.dropFirst())
        }
        guard let key = finals[final] else { return [] }
        var result = [initial + key]
        if first == "a" || first == "e" { result.append(String(first) + key) }
        // Microsoft's üe also accepts v. ju/qu/xu/yu use the ü key as an alias.
        if final == "ue" || final == "ve" { result.append(initial + "v") }
        if final == "u" && "jqxy".contains(first) { result.append(initial + "y") }
        return result
    }
}

struct ShuangpinCandidate: Equatable {
    let text: String
    let pinyin: String
    var isCompletion = false
}

final class ShuangpinDictionary {
    static let shared: ShuangpinDictionary = {
        let url = Bundle.main.url(forResource: "pinyin_simp.dict", withExtension: "yaml", subdirectory: "Chinese")
        return ShuangpinDictionary(contents: url.flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? "")
    }()
    private struct Entry {
        let candidate: ShuangpinCandidate
        let weight: Int
    }
    private var entries: [String: [Entry]] = [:]
    private var completions: [String: [ShuangpinCandidate]] = [:]
    private var completionOrder: [String] = []
    private var sortedCodes: [String] = []
    private let completionLock = NSLock()
    var isAvailable: Bool { !entries.isEmpty }

    init(contents: String) {
        for line in contents.split(separator: "\n") {
            let fields = line.split(separator: "\t")
            guard fields.count >= 2 else { continue }
            let syllables = fields[1].split(separator: " ").map(String.init)
            var codes = [""]
            for syllable in syllables {
                let alternatives = MicrosoftShuangpin.codes(for: syllable)
                codes = codes.flatMap { prefix in alternatives.map { prefix + $0 } }
            }
            let entry = Entry(candidate: ShuangpinCandidate(text: String(fields[0]), pinyin: String(fields[1])),
                              weight: fields.count > 2 ? Int(fields[2]) ?? 0 : 0)
            for code in Set(codes) where !code.isEmpty { entries[code, default: []].append(entry) }
        }
        sortedCodes = entries.keys.sorted()
        for key in Array(entries.keys) {
            entries[key]?.sort {
                $0.weight == $1.weight ? $0.candidate.text < $1.candidate.text : $0.weight > $1.weight
            }
        }
    }

    private func completionCandidates(for code: String) -> [ShuangpinCandidate] {
        completionLock.lock()
        defer { completionLock.unlock() }
        if let cached = completions[code] { return cached }
        // Binary-search the phrase-code range on the worker. Cache only recently
        // requested prefixes instead of building a large index in an extension.
        var low = 0, high = sortedCodes.count
        while low < high {
            let middle = (low + high) / 2
            if sortedCodes[middle] < code { low = middle + 1 } else { high = middle }
        }
        var best: [String: Entry] = [:]
        while low < sortedCodes.count, sortedCodes[low].hasPrefix(code) {
            let fullCode = sortedCodes[low]
            if fullCode.count > code.count {
                for entry in entries[fullCode, default: []] where entry.candidate.text.count > 1 {
                    if best[entry.candidate.text].map({ $0.weight < entry.weight }) ?? true { best[entry.candidate.text] = entry }
                }
            }
            low += 1
        }
        let ranked = best.values.sorted {
            $0.weight == $1.weight ? $0.candidate.text < $1.candidate.text : $0.weight > $1.weight
        }.prefix(9).map { entry -> ShuangpinCandidate in
            var candidate = entry.candidate
            candidate.isCompletion = true
            return candidate
        }
        if completionOrder.count >= 64 { completions.removeValue(forKey: completionOrder.removeFirst()) }
        completionOrder.append(code)
        completions[code] = ranked
        return ranked
    }

    func candidates(for code: String, completing: Bool = false) -> [ShuangpinCandidate] {
        guard !code.isEmpty else { return [] }
        var result = code.count % 2 == 0 ? entries[code, default: []].map(\.candidate) : []
        if completing {
            let predictions = completionCandidates(for: code)
            result = Array(result.prefix(5)) + predictions.prefix(4) + result.dropFirst(5) + predictions.dropFirst(4)
        }
        // Permit sentences absent from the phrase dictionary by joining the
        // longest known phrases. Exact dictionary phrases retain priority.
        if result.isEmpty, code.count > 2, code.count % 2 == 0, let parts = segments(code) {
            result = [ShuangpinCandidate(text: parts.map(\.text).joined(), pinyin: parts.map(\.pinyin).joined(separator: " "))]
        }
        var seen = Set<String>()
        return result.filter { seen.insert($0.text).inserted }
    }

    private func segments(_ code: String) -> [ShuangpinCandidate]? {
        var memo: [String: [ShuangpinCandidate]] = [:]
        var misses = Set<String>()
        return segments(code, memo: &memo, misses: &misses)
    }

    private func segments(_ code: String, memo: inout [String: [ShuangpinCandidate]],
                          misses: inout Set<String>) -> [ShuangpinCandidate]? {
        if code.isEmpty { return [] }
        if let cached = memo[code] { return cached }
        if misses.contains(code) { return nil }
        for length in stride(from: code.count, through: 2, by: -2) {
            if let first = entries[String(code.prefix(length))]?.first?.candidate,
               let rest = segments(String(code.dropFirst(length)), memo: &memo, misses: &misses) {
                let result = [first] + rest
                memo[code] = result
                return result
            }
        }
        misses.insert(code)
        return nil
    }
}

struct ShuangpinEngine {
    let dictionary: ShuangpinDictionary
    var completionsEnabled = false {
        didSet { if oldValue != completionsEnabled { update() } }
    }
    init(dictionary: ShuangpinDictionary = .shared) { self.dictionary = dictionary }
    private(set) var code = ""
    private(set) var candidates: [ShuangpinCandidate] = []
    private(set) var selectedIndex = 0
    static let pageSize = 9
    var isPending: Bool { !code.isEmpty }
    var selected: ShuangpinCandidate? { candidates.indices.contains(selectedIndex) ? candidates[selectedIndex] : nil }
    var pageStart: Int { selectedIndex / Self.pageSize * Self.pageSize }
    var visibleCandidates: [ShuangpinCandidate] { Array(candidates.dropFirst(pageStart).prefix(Self.pageSize)) }
    var preview: String {
        let chars = Array(code)
        return stride(from: 0, to: chars.count, by: 2).map { String(chars[$0..<min($0 + 2, chars.count)]) }.joined(separator: " ")
    }
    mutating func append(_ key: String) -> EngineEffect {
        guard key.count == 1, let c = key.first, "abcdefghijklmnopqrstuvwxyz;".contains(c),
              (c != ";" || code.count % 2 == 1), code.count < 32 else { return .none }
        code += key
        update()
        return .marked(preview)
    }
    mutating func backspace() -> EngineEffect {
        guard isPending else { return .none }
        code.removeLast()
        update()
        return isPending ? .marked(preview) : .cancel
    }
    mutating func cancel() -> EngineEffect {
        guard isPending else { return .none }
        code = ""
        update()
        return .cancel
    }
    mutating func moveSelection(_ delta: Int) {
        guard !candidates.isEmpty else { return }
        selectedIndex = max(0, min(candidates.count - 1, selectedIndex + delta))
    }
    mutating func choose(_ number: Int? = nil, literal: Bool = false) -> EngineEffect {
        guard isPending else { return .none }
        if let number = number {
            let index = pageStart + number - 1
            guard number >= 1, number <= Self.pageSize, candidates.indices.contains(index) else { return .none }
            selectedIndex = index
        }
        guard let text = literal ? code : selected?.text else { return .none }
        _ = cancel()
        return .commit(text)
    }
    mutating func applyCompletions(_ values: [ShuangpinCandidate], for expectedCode: String) {
        guard completionsEnabled, code == expectedCode else { return }
        candidates = values
        selectedIndex = min(selectedIndex, max(0, values.count - 1))
    }
    private mutating func update() {
        candidates = dictionary.candidates(for: code)
        selectedIndex = 0
    }
}
