#if !hasFeature(Embedded)
import Foundation
#endif

enum KeyboardCursorMovement {
    static func verticalOffset(before: String, after: String, lines: Int) -> Int {
        guard lines != 0 else { return 0 }
        let characters = Array(before + after)
        let caret = before.count
        var starts = [0]
        for index in characters.indices where characters[index] == "\n" { starts.append(index + 1) }
        let current = starts.lastIndex(where: { $0 <= caret }) ?? 0
        let target = max(0, min(starts.count - 1, current + lines))
        guard target != current else { return 0 }
        let end = target + 1 < starts.count ? starts[target + 1] - 1 : characters.count
        return starts[target] + min(caret - starts[current], end - starts[target]) - caret
    }
}
