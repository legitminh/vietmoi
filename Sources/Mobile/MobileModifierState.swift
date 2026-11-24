#if !hasFeature(Embedded)
import Foundation
#endif

// Touch modifiers use event times so their hold/double-tap behavior can be
// checked without UIKit or real-time sleeps. Only input mode is persisted.
enum MobileLetterCase {
    case lowercase, shifted, capsLock

    func apply(_ text: String) -> String {
        switch self {
        case .lowercase: return text
        case .shifted: return text.prefix(1).uppercased() + text.dropFirst()
        case .capsLock: return text.uppercased()
        }
    }
}

struct MobileShiftState {
    static let holdSeconds = 0.20
    static let doubleTapSeconds = 0.30
    private(set) var heldSince: TimeInterval?
    private var usedWhileHeld = false
    private var secondTap = false
    private var exitingLock = false
    private var lastTap: TimeInterval?
    private(set) var pendingTap: TimeInterval?
    private(set) var capsLock = false
    var letterCase: MobileLetterCase { capsLock ? .capsLock : (heldSince != nil ? .shifted : .lowercase) }
    var uppercase: Bool { letterCase != .lowercase }

    mutating func begin(at time: TimeInterval) {
        guard heldSince == nil else { return }
        exitingLock = capsLock
        if capsLock { capsLock = false }
        secondTap = lastTap.map { time - $0 <= Self.doubleTapSeconds } ?? false
        heldSince = time
        usedWhileHeld = false
    }
    mutating func end(at time: TimeInterval) {
        guard let start = heldSince else { return }
        heldSince = nil
        defer { usedWhileHeld = false; secondTap = false; exitingLock = false }
        guard !usedWhileHeld && !exitingLock else { return }
        if time - start >= Self.holdSeconds { lastTap = nil }
        else if secondTap {
            capsLock = true; pendingTap = time; lastTap = nil
        } else { pendingTap = time; lastTap = time }
    }
    mutating func keyBegan() {
        if heldSince != nil { usedWhileHeld = true }
        lastTap = nil
    }
    mutating func typed() -> MobileLetterCase {
        let result = letterCase
        keyBegan()
        lastTap = nil
        return result
    }
    // Apply each short tap immediately. The second tap restores the first
    // tap's mode and enables Caps Lock, leaving the original mode selected.
    mutating func takeModeTap() -> Bool {
        guard pendingTap != nil else { return false }
        pendingTap = nil
        return true
    }
    mutating func cancelHold() {
        heldSince = nil; usedWhileHeld = false; secondTap = false; exitingLock = false
        lastTap = nil
    }
}

struct MobileSymbolState {
    enum Page: Int { case letters, numbers, symbols }
    private(set) var page: Page = .letters
    private var previous: Page = .letters
    private var held: Page?
    private var startedAt: TimeInterval = 0
    private var used = false
    mutating func begin(_ requested: Page, at time: TimeInterval) {
        guard held == nil else { return }
        previous = page; held = requested; startedAt = time; used = false
        page = requested
    }
    mutating func typed() { if held != nil { used = true } }
    mutating func end(_ requested: Page, at time: TimeInterval, cancelled: Bool = false) {
        guard held == requested else { return }
        if cancelled || used || time - startedAt >= MobileShiftState.holdSeconds { page = previous }
        else { page = previous == requested ? .letters : requested }
        held = nil
    }
    mutating func cancelHold() {
        if held != nil { page = previous }
        held = nil
    }
}
