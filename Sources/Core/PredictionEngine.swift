#if !hasFeature(Embedded)
import Foundation
#endif

struct PredictionCandidate: Equatable {
    let suffix: String
    let score: Int
}

// A small, allocation-bounded contextual model that is always available, including
// inside restricted keyboard extensions. Its boundary deliberately matches a future
// neural scorer: context + current visible prefix in, ranked suffixes out.
enum VietnamesePredictionEngine {
    private struct Entry {
        let text: String
        let weight: Int
    }

    // Phrase weights encode a compact offline prior. Longer/contextual matches outrank
    // generic words, so "chúc mừng " can offer "sinh nhật" while "s" offers
    // "inh nhật". No document text or learned vocabulary is persisted here.
    private static let entries: [Entry] = [
        Entry(text: "xin", weight: 1800), Entry(text: "xin chào", weight: 1200),
        Entry(text: "xin cảm ơn", weight: 1120), Entry(text: "xin lỗi", weight: 1180),
        Entry(text: "xinh", weight: 820), Entry(text: "xuống", weight: 800),
        Entry(text: "xuân", weight: 760), Entry(text: "xuất", weight: 750),
        Entry(text: "xong", weight: 900), Entry(text: "xem", weight: 880),
        Entry(text: "xác nhận", weight: 930), Entry(text: "xử lý", weight: 850),
        Entry(text: "sinh nhật", weight: 1250), Entry(text: "chúc mừng sinh nhật", weight: 1600),
        Entry(text: "chúc mừng", weight: 1250), Entry(text: "cảm ơn", weight: 1500),
        Entry(text: "cảm ơn bạn", weight: 1550), Entry(text: "không", weight: 1500),
        Entry(text: "không sao", weight: 1380), Entry(text: "không có gì", weight: 1450),
        Entry(text: "được", weight: 1450), Entry(text: "được rồi", weight: 1420),
        Entry(text: "đồng ý", weight: 1150), Entry(text: "tôi", weight: 1500),
        Entry(text: "tôi nghĩ", weight: 1330), Entry(text: "tôi muốn", weight: 1370),
        Entry(text: "tôi sẽ", weight: 1320), Entry(text: "mình", weight: 1420),
        Entry(text: "mình sẽ", weight: 1300), Entry(text: "mình nghĩ", weight: 1270),
        Entry(text: "bạn", weight: 1450), Entry(text: "bạn có", weight: 1250),
        Entry(text: "có", weight: 1480), Entry(text: "có thể", weight: 1420),
        Entry(text: "có lẽ", weight: 1190), Entry(text: "rất", weight: 1300),
        Entry(text: "rất vui", weight: 1180), Entry(text: "vui lòng", weight: 1320),
        Entry(text: "vui lòng cho", weight: 1260), Entry(text: "cho", weight: 1410),
        Entry(text: "cho tôi", weight: 1350), Entry(text: "cho mình", weight: 1220),
        Entry(text: "và", weight: 1460), Entry(text: "nhưng", weight: 1250),
        Entry(text: "vì", weight: 1260), Entry(text: "vì vậy", weight: 1230),
        Entry(text: "nếu", weight: 1240), Entry(text: "nếu bạn", weight: 1220),
        Entry(text: "khi", weight: 1220), Entry(text: "trong", weight: 1370),
        Entry(text: "trong đó", weight: 1210), Entry(text: "một", weight: 1430),
        Entry(text: "một cách", weight: 1190), Entry(text: "những", weight: 1340),
        Entry(text: "các", weight: 1400), Entry(text: "này", weight: 1280),
        Entry(text: "đó", weight: 1260), Entry(text: "hôm nay", weight: 1360),
        Entry(text: "ngày mai", weight: 1310), Entry(text: "hôm qua", weight: 1180),
        Entry(text: "bây giờ", weight: 1300), Entry(text: "sau đó", weight: 1230),
        Entry(text: "ở", weight: 1360), Entry(text: "ở đây", weight: 1320),
        Entry(text: "đi", weight: 1220), Entry(text: "đến", weight: 1320),
        Entry(text: "về", weight: 1340), Entry(text: "làm", weight: 1390),
        Entry(text: "làm việc", weight: 1340), Entry(text: "thời gian", weight: 1280),
        Entry(text: "công việc", weight: 1300), Entry(text: "gia đình", weight: 1250),
        Entry(text: "Việt Nam", weight: 1290), Entry(text: "tiếng Việt", weight: 1270),
        Entry(text: "thông tin", weight: 1280), Entry(text: "vấn đề", weight: 1270),
        Entry(text: "giải quyết", weight: 1210), Entry(text: "phát triển", weight: 1210),
        Entry(text: "hệ thống", weight: 1200), Entry(text: "ứng dụng", weight: 1190),
        Entry(text: "cập nhật", weight: 1230), Entry(text: "hoàn thành", weight: 1210),
        Entry(text: "thành công", weight: 1240), Entry(text: "tuyệt vời", weight: 1160),
        Entry(text: "chào buổi sáng", weight: 1220), Entry(text: "chào buổi tối", weight: 1150),
        Entry(text: "hẹn gặp lại", weight: 1250), Entry(text: "chúc ngủ ngon", weight: 1200),
        Entry(text: "mừng sinh nhật", weight: 1310), Entry(text: "sức khỏe", weight: 1180),
        Entry(text: "yêu", weight: 1190), Entry(text: "thích", weight: 1260),
        Entry(text: "muốn", weight: 1320), Entry(text: "cần", weight: 1360),
        Entry(text: "biết", weight: 1350), Entry(text: "hiểu", weight: 1240),
        Entry(text: "thấy", weight: 1320), Entry(text: "nói", weight: 1340),
        Entry(text: "gửi", weight: 1260), Entry(text: "nhận", weight: 1240)
    ]

    /// Each phrase normalized and split once, so ranking runs on every key without
    /// re-normalizing the table (the Mac ranks it inline while drawing the guide).
    private struct Prepared {
        let tails: [String]
        let loweredTails: [String]
        let loweredWords: [String]
        let weight: Int
    }
    private static let prepared: [Prepared] = entries.compactMap { entry in
        let words = entry.text.precomposedStringWithCanonicalMapping.split(separator: " ").map(String.init)
        guard !words.isEmpty else { return nil }
        let tails = words.indices.map { words[$0...].joined(separator: " ") }
        return Prepared(tails: tails, loweredTails: tails.map { $0.lowercased() },
                        loweredWords: words.map { $0.lowercased() }, weight: entry.weight)
    }

    static func suggestions(context: String, prefix: String, limit: Int = 12) -> [PredictionCandidate] {
        guard limit > 0 else { return [] }
        let normalizedPrefix = prefix.precomposedStringWithCanonicalMapping.lowercased()
        var base = context.precomposedStringWithCanonicalMapping.lowercased()
        if !normalizedPrefix.isEmpty, base.hasSuffix(normalizedPrefix) {
            base.removeLast(normalizedPrefix.count)
        }
        let contextWords = words(in: base)
        var best: [String: Int] = [:]

        for entry in prepared {
            for start in entry.tails.indices {
                let candidate = entry.tails[start]
                guard entry.loweredTails[start].hasPrefix(normalizedPrefix) else { continue }
                let preceding = Array(entry.loweredWords[..<start])
                let matched = matchingContextWords(contextWords, preceding)
                if normalizedPrefix.isEmpty && matched == 0 { continue }
                if start > 0 && matched < min(preceding.count, 1) { continue }
                let suffix = String(candidate.dropFirst(normalizedPrefix.count))
                guard !suffix.isEmpty else { continue }
                let contextual = matched * 5000 + (matched == preceding.count && matched > 0 ? 2500 : 0)
                // Prefer finishing one word over guessing an entire phrase when
                // context does not yet support the longer phrase.
                let phrasePenalty = matched == 0 ? suffix.filter { $0 == " " }.count * 700 : 0
                let score = entry.weight + contextual - suffix.count - phrasePenalty
                best[suffix] = max(best[suffix] ?? Int.min, score)
            }
        }

        // With no previous-word match, keep useful next-word choices available.
        if normalizedPrefix.isEmpty && best.isEmpty {
            for entry in entries where !entry.text.contains(" ") {
                best[entry.text] = entry.weight - entry.text.count
            }
        }
        let hasSingleWord = best.keys.contains { !$0.contains(" ") }
        return best.map { PredictionCandidate(suffix: $0.key, score: $0.value) }
            .sorted {
                // A phrase is never allowed to displace an available one-word
                // completion. Scores only compare candidates within the same tier.
                if hasSingleWord && $0.suffix.contains(" ") != $1.suffix.contains(" ") {
                    return !$0.suffix.contains(" ")
                }
                return $0.score == $1.score ? $0.suffix.localizedStandardCompare($1.suffix) == .orderedAscending : $0.score > $1.score
            }
            .prefix(limit).map { $0 }
    }

    private static func words(in text: String) -> [String] {
        text.split { character in
            !character.unicodeScalars.allSatisfy { CharacterSet.letters.contains($0) }
        }.map { String($0).lowercased() }
    }

    private static func matchingContextWords(_ context: [String], _ preceding: [String]) -> Int {
        var count = 0
        while count < context.count && count < preceding.count &&
              context[context.count - 1 - count] == preceding[preceding.count - 1 - count] {
            count += 1
        }
        return count
    }
}
