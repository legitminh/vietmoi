import Foundation
#if canImport(UIKit)
import UIKit
#endif

enum MobileEnglishCompletion {
    static func words(_ prefix: String) -> [String] {
        #if canImport(UIKit)
        return UITextChecker().completions(forPartialWordRange: NSRange(location: 0, length: prefix.utf16.count),
                                          in: prefix, language: "en_US") ?? []
        #else
        return []
        #endif
    }
}
