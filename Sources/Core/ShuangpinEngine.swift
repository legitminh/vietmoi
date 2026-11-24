#if !hasFeature(Embedded)
import Foundation
#endif

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
    /// Every Mandarin syllable the dictionary uses (ü written v), for decoding key pairs.
    static let syllables: [String] = [
        "a", "ai", "an", "ang", "ao", "ba", "bai", "ban", "bang", "bao", "bei", "ben", "beng", "bi", "bian", "biao",
        "bie", "bin", "bing", "bo", "bu", "ca", "cai", "can", "cang", "cao", "ce", "cen", "ceng", "cha", "chai",
        "chan", "chang", "chao", "che", "chen", "cheng", "chi", "chong", "chou", "chu", "chua", "chuai", "chuan",
        "chuang", "chui", "chun", "chuo", "ci", "cong", "cou", "cu", "cuan", "cui", "cun", "cuo", "da", "dai", "dan",
        "dang", "dao", "de", "dei", "den", "deng", "di", "dia", "dian", "diao", "die", "ding", "diu", "dong", "dou",
        "du", "duan", "dui", "dun", "duo", "e", "ei", "en", "eng", "er", "fa", "fan", "fang", "fei", "fen", "feng",
        "fiao", "fo", "fou", "fu", "ga", "gai", "gan", "gang", "gao", "ge", "gei", "gen", "geng", "gong", "gou", "gu",
        "gua", "guai", "guan", "guang", "gui", "gun", "guo", "ha", "hai", "han", "hang", "hao", "he", "hei", "hen",
        "heng", "hong", "hou", "hu", "hua", "huai", "huan", "huang", "hui", "hun", "huo", "ji", "jia", "jian", "jiang",
        "jiao", "jie", "jin", "jing", "jiong", "jiu", "ju", "juan", "jue", "jun", "ka", "kai", "kan", "kang", "kao",
        "ke", "kei", "ken", "keng", "kong", "kou", "ku", "kua", "kuai", "kuan", "kuang", "kui", "kun", "kuo", "la",
        "lai", "lan", "lang", "lao", "le", "lei", "leng", "li", "lia", "lian", "liang", "liao", "lie", "lin", "ling",
        "liu", "lo", "long", "lou", "lu", "luan", "lue", "lun", "luo", "lv", "ma", "mai", "man", "mang", "mao", "me",
        "mei", "men", "meng", "mi", "mian", "miao", "mie", "min", "ming", "miu", "mo", "mou", "mu", "na", "nai", "nan",
        "nang", "nao", "ne", "nei", "nen", "neng", "ni", "nian", "niang", "niao", "nie", "nin", "ning", "niu", "nong",
        "nou", "nu", "nuan", "nue", "nuo", "nv", "o", "ou", "pa", "pai", "pan", "pang", "pao", "pei", "pen", "peng",
        "pi", "pian", "piao", "pie", "pin", "ping", "po", "pou", "pu", "qi", "qia", "qian", "qiang", "qiao", "qie",
        "qin", "qing", "qiong", "qiu", "qu", "quan", "que", "qun", "ran", "rang", "rao", "re", "ren", "reng", "ri",
        "rong", "rou", "ru", "ruan", "rui", "run", "ruo", "sa", "sai", "san", "sang", "sao", "se", "sen", "seng",
        "sha", "shai", "shan", "shang", "shao", "she", "shei", "shen", "sheng", "shi", "shou", "shu", "shua", "shuai",
        "shuan", "shuang", "shui", "shun", "shuo", "si", "song", "sou", "su", "suan", "sui", "sun", "suo", "ta", "tai",
        "tan", "tang", "tao", "te", "tei", "teng", "ti", "tian", "tiao", "tie", "ting", "tong", "tou", "tu", "tuan",
        "tui", "tun", "tuo", "wa", "wai", "wan", "wang", "wei", "wen", "weng", "wo", "wu", "xi", "xia", "xian",
        "xiang", "xiao", "xie", "xin", "xing", "xiong", "xiu", "xu", "xuan", "xue", "xun", "ya", "yan", "yang", "yao",
        "ye", "yi", "yin", "ying", "yo", "yong", "you", "yu", "yuan", "yue", "yun", "za", "zai", "zan", "zang", "zao",
        "ze", "zei", "zen", "zeng", "zha", "zhai", "zhan", "zhang", "zhao", "zhe", "zhei", "zhen", "zheng", "zhi",
        "zhong", "zhou", "zhu", "zhua", "zhuai", "zhuan", "zhuang", "zhui", "zhun", "zhuo", "zi", "zong", "zou", "zu",
        "zuan", "zui", "zun", "zuo"
    ]
    /// Key pair → syllable. A pair's primary code wins over an alias; among equal
    /// claims the longer syllable wins (lo → luo).
    static let syllableForCode: [String: String] = {
        var primary: [String: String] = [:], aliases: [String: String] = [:]
        for syllable in syllables.sorted(by: { $0.count == $1.count ? $0 < $1 : $0.count > $1.count }) {
            for (index, code) in codes(for: syllable).enumerated() {
                if index == 0 { if primary[code] == nil { primary[code] = syllable } }
                else if aliases[code] == nil { aliases[code] = syllable }
            }
        }
        return primary.merging(aliases) { first, _ in first }
    }()
    /// The spelled initial an initial key produces; zero-initial keys spell nothing yet.
    static func initial(forKey key: String) -> String? {
        switch key {
        case "v": return "zh"
        case "i": return "ch"
        case "u": return "sh"
        case "o": return ""
        case ";": return nil
        default: return key.count == 1 && key.first!.isLetter ? key : nil
        }
    }
    /// Written pinyin: ü after l and n, v elsewhere is never written.
    static func written(_ syllable: String) -> String {
        syllable == "lv" || syllable == "nv" ? String(syllable.prefix(1)) + "ü" : syllable
    }
    /// What a key types next: its initial at a syllable start, otherwise the final
    /// that completes a real syllable after the typed initial (nil when none does).
    static func label(forKey key: String, after code: String) -> String? {
        if code.count % 2 == 0 {
            guard let initial = initial(forKey: key) else { return nil }
            return initial.isEmpty ? "'" : initial
        }
        guard let first = code.last.map(String.init), let syllable = syllableForCode[first + key] else { return nil }
        let spelled = written(syllable)
        let initial = Self.initial(forKey: first) ?? ""
        return "aoe".contains(first) || !spelled.hasPrefix(initial) ? spelled : String(spelled.dropFirst(initial.count))
    }
    /// The code spelled as pinyin: jing, not j;. An apostrophe separates a syllable
    /// starting with a, o or e, as in xi'an. A lone initial key shows its initial.
    static func spell(_ code: String) -> String {
        let keys = code.map(String.init)
        var result = ""
        for start in stride(from: 0, to: keys.count, by: 2) {
            let part: String
            if start + 1 < keys.count {
                let pair = keys[start] + keys[start + 1]
                part = syllableForCode[pair].map(written) ?? pair
            } else {
                part = initial(forKey: keys[start]).map { $0.isEmpty ? "'" : $0 } ?? keys[start]
            }
            if !result.isEmpty, let letter = part.first, "aoe".contains(letter) { result += "'" }
            result += part
        }
        return result
    }
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
    #if !hasFeature(Embedded)
    static let shared: ShuangpinDictionary = {
        let url = Bundle.main.url(forResource: "pinyin_simp.dict", withExtension: "yaml", subdirectory: "Chinese")
        return ShuangpinDictionary(contents: url.flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? "")
    }()
    #else
    /// Embedded hosts (the web demo) load the dictionary themselves and pass it to ShuangpinEngine.
    static let shared = ShuangpinDictionary(contents: "")
    #endif
    fileprivate struct Entry {
        let candidate: ShuangpinCandidate
        let weight: Int
    }
    private var entries: [String: [Entry]] = [:]
    private var completions: [String: [ShuangpinCandidate]] = [:]
    private var completionOrder: [String] = []
    private var sortedCodes: [String] = []
    private let completionLock = NSLock()
    var isAvailable: Bool { !entries.isEmpty }

    convenience init(contents: String) {
        let builder = ShuangpinDictionaryBuilder(contents: contents)
        while !builder.step(Int.max) {}
        self.init(builder)
    }
    fileprivate init(_ builder: ShuangpinDictionaryBuilder) {
        entries = builder.entries
        sortedCodes = builder.sortedCodes
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
        var result = code.count % 2 == 0 ? entries[code, default: []].map({ $0.candidate }) : []
        if completing {
            let predictions = completionCandidates(for: code)
            result = Array(result.prefix(5)) + predictions.prefix(4) + result.dropFirst(5) + predictions.dropFirst(4)
        }
        // Permit sentences absent from the phrase dictionary by joining the
        // longest known phrases. Exact dictionary phrases retain priority.
        if result.isEmpty, code.count > 2, code.count % 2 == 0, let parts = segments(code) {
            result = [ShuangpinCandidate(text: parts.map({ $0.text }).joined(), pinyin: parts.map({ $0.pinyin }).joined(separator: " "))]
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

/// Builds a ShuangpinDictionary in bounded steps, so a host without threads (the web
/// demo) can spread the work over idle time. init(contents:) runs the same steps at once.
final class ShuangpinDictionaryBuilder {
    private let contents: String
    private var position: String.Index
    fileprivate var entries: [String: [ShuangpinDictionary.Entry]] = [:]
    fileprivate var sortedCodes: [String] = []
    private var keys: [String] = []
    private var sortedLists = 0
    /// Codes sorted in runs, then merged pairwise, so no step sorts them all at once.
    private var runs: [[String]] = []
    private var sortedRuns = 0
    private enum Phase { case reading, sortingLists, sortingRuns, merging }
    private var phase = Phase.reading
    private(set) var dictionary: ShuangpinDictionary? = nil

    init(contents: String) {
        self.contents = contents
        position = contents.startIndex
    }

    /// Does up to `budget` units of work (a line, a candidate list or a run of codes).
    /// Returns true once `dictionary` is ready.
    func step(_ budget: Int) -> Bool {
        var work = 0
        while dictionary == nil && work < budget {
            switch phase {
            case .reading:
                guard position < contents.endIndex else {
                    keys = Array(entries.keys)
                    phase = .sortingLists
                    continue
                }
                let end = contents.utf8[position...].firstIndex(of: UInt8(ascii: "\n")) ?? contents.endIndex
                add(contents[position..<end])
                position = end < contents.endIndex ? contents.index(after: end) : end
            case .sortingLists:
                guard sortedLists < keys.count else {
                    runs = stride(from: 0, to: keys.count, by: 2048).map { Array(keys[$0..<min($0 + 2048, keys.count)]) }
                    phase = .sortingRuns
                    continue
                }
                entries[keys[sortedLists]]?.sort {
                    $0.weight == $1.weight ? $0.candidate.text < $1.candidate.text : $0.weight > $1.weight
                }
                sortedLists += 1
            case .sortingRuns:
                guard sortedRuns < runs.count else { phase = .merging; continue }
                runs[sortedRuns].sort()
                sortedRuns += 1
                work += 99   // a run is about a hundred lines' work
            case .merging:
                guard runs.count > 1 else {
                    sortedCodes = runs.first ?? []
                    runs = []; keys = []
                    dictionary = ShuangpinDictionary(self)
                    continue
                }
                // Merge the two shortest runs, keeping each step's work small.
                runs.sort { $0.count > $1.count }
                let right = runs.removeLast(), left = runs.removeLast()
                work += (left.count + right.count) / 40
                runs.append(Self.merge(left, right))
            }
            work += 1
        }
        return dictionary != nil
    }

    private static func merge(_ left: [String], _ right: [String]) -> [String] {
        var result: [String] = []
        result.reserveCapacity(left.count + right.count)
        var i = 0, j = 0
        while i < left.count && j < right.count {
            if right[j] < left[i] { result.append(right[j]); j += 1 } else { result.append(left[i]); i += 1 }
        }
        result.append(contentsOf: left[i...])
        result.append(contentsOf: right[j...])
        return result
    }

    private func add(_ line: Substring) {
        let fields = line.split(separator: "\t")
        guard fields.count >= 2 else { return }
        let syllables = fields[1].split(separator: " ").map(String.init)
        var codes = [""]
        for syllable in syllables {
            let alternatives = MicrosoftShuangpin.codes(for: syllable)
            codes = codes.flatMap { prefix in alternatives.map { prefix + $0 } }
        }
        let entry = ShuangpinDictionary.Entry(candidate: ShuangpinCandidate(text: String(fields[0]), pinyin: String(fields[1])),
                                              weight: fields.count > 2 ? Int(fields[2]) ?? 0 : 0)
        for code in Set(codes) where !code.isEmpty { entries[code, default: []].append(entry) }
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
    /// The composing text as spelled pinyin.
    var preview: String { MicrosoftShuangpin.spell(code) }
    /// The label for a key given what has been typed so far.
    func keyLabel(_ key: String) -> String? { MicrosoftShuangpin.label(forKey: key, after: code) }
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
        guard let text = literal ? preview : selected?.text else { return .none }
        _ = cancel()
        return .commit(text)
    }
    /// Completions follow the exact conversions, so Space (the first candidate) never picks a prediction.
    mutating func applyCompletions(_ values: [ShuangpinCandidate], for expectedCode: String) {
        guard completionsEnabled, code == expectedCode else { return }
        let exact = Array(candidates.prefix(exactCount))
        candidates = exact + values.filter { value in !exact.contains { $0.text == value.text } }
        selectedIndex = min(selectedIndex, max(0, candidates.count - 1))
    }
    private var exactCount = 0
    private mutating func update() {
        candidates = dictionary.candidates(for: code)
        exactCount = candidates.count
        selectedIndex = 0
    }
}
