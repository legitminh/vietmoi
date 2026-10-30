import Foundation

final class KeyboardPreferences {
    static let shared = KeyboardPreferences()
    // QMK's default TAPPING_TERM; a common starting point, not an OS-wide standard.
    static let defaultShiftTapSeconds = 0.20
    static let shiftTapRange = 0.01...5.0
    private let defaults: UserDefaults
    private let shiftTapKey = "shiftTapSeconds.v1"

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }
    var shiftTapSeconds: Double {
        guard let number = defaults.object(forKey: shiftTapKey) as? NSNumber else {
            return Self.defaultShiftTapSeconds
        }
        let value = number.doubleValue
        return value.isFinite && Self.shiftTapRange.contains(value) ? value : Self.defaultShiftTapSeconds
    }
    @discardableResult func setShiftTapSeconds(_ value: Double) -> Bool {
        guard value.isFinite && Self.shiftTapRange.contains(value) else { return false }
        defaults.set(value, forKey: shiftTapKey)
        return true
    }
    func resetShiftTapSeconds() { defaults.removeObject(forKey: shiftTapKey) }
}

// Uses event timestamps, with no delayed key dispatch or timer. A chord invalidates
// the tap even if Shift is released before the other key, or another key was held first.
struct ShiftTapDetector {
    private var heldKeys: Set<UInt16> = []
    private var startedAt: TimeInterval?
    private var limit: TimeInterval = 0
    private var eligible = false

    mutating func press(at time: TimeInterval, threshold: TimeInterval, isolated: Bool,
                        isKeyDown: ((UInt16) -> Bool)? = nil) {
        guard startedAt == nil else { return }
        // IMK clients do not reliably forward every ordinary key-up. Reconcile
        // old observations at the start of a new tap so they cannot block it forever.
        // Never revive a tap after a chord: eligible remains false until a new press.
        if let isKeyDown = isKeyDown { heldKeys = heldKeys.filter(isKeyDown) }
        startedAt = time
        limit = threshold
        eligible = isolated && heldKeys.isEmpty
    }
    mutating func release(at time: TimeInterval) -> Bool {
        defer { startedAt = nil; eligible = false }
        guard let start = startedAt else { return false }
        let elapsed = time - start
        return eligible && heldKeys.isEmpty && elapsed >= 0 && elapsed < limit
    }
    mutating func keyDown(_ key: UInt16) { heldKeys.insert(key); interrupt() }
    mutating func keyUp(_ key: UInt16) { heldKeys.remove(key); interrupt() }
    mutating func interrupt() { eligible = false }
    mutating func reset() { self = ShiftTapDetector() }
}
