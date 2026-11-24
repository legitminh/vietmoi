import Foundation

final class KeyboardPreferences {
    static let shared = KeyboardPreferences()
    // QMK's default TAPPING_TERM; a common starting point, not an OS-wide standard.
    static let defaultShiftTapSeconds = ShiftTapDetector.defaultTapSeconds
    static let shiftTapRange = 0.01...5.0
    private let defaults: UserDefaults
    private let shiftTapKey = "shiftTapSeconds.v1"

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }
    var language: String {
        get { AppCopy.supportedLanguage(defaults.string(forKey: "interfaceLanguage")) }
        set { defaults.set(AppCopy.supportedLanguage(newValue), forKey: "interfaceLanguage") }
    }
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
