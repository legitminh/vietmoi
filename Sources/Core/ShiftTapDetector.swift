import Foundation

// Uses event timestamps, with no delayed key dispatch or timer. A chord invalidates
// the tap even if Shift is released before the other key, or another key was held first.
struct ShiftTapDetector {
    static let defaultTapSeconds = 0.20
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
        // The caller must query hardware state. A logical/synthetic event table
        // may retain a host-handled Delete as down after its real release.
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
