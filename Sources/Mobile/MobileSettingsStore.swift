import Foundation

// The app is the only writer. A keyboard activation reads this small settings
// snapshot from its App Group; typing uses the in-memory copy. No keystrokes,
// phonetic bases, Keychain items, networking, or Full Access are involved.
final class MobileSettingsStore {
    private let file: URL?
    private let defaults: UserDefaults
    private var cached = MobileKeyboardSettings.standard
    var current: MobileKeyboardSettings { cached }

    init(bundle: Bundle = .main, defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let group = bundle.object(forInfoDictionaryKey: "VietSettingsAppGroup") as? String {
            file = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group)?
                .appendingPathComponent("KeyboardSettings-v1.json")
        } else { file = nil }
    }
    // A file URL also makes the snapshot boundary testable without an entitled
    // process or a running containing app.
    init(snapshotURL: URL, defaults: UserDefaults) {
        self.file = snapshotURL
        self.defaults = defaults
    }
    @discardableResult func load() -> MobileKeyboardSettings {
        if let value = read() { cached = value.supported }
        AppCopy.language = cached.language
        return cached
    }
    // App only. Keep a previous app-local output selection when first creating
    // the shared snapshot. The extension never initializes or writes the file.
    func initializeIfNeeded() throws {
        if let value = read() { cached = value.supported; AppCopy.language = cached.language; return }
        try save(MobileKeyboardSettings(output: defaults.string(forKey: "mobile.output").flatMap(OutputType.init(rawValue:)) ?? .sieuviet))
    }
    func save(_ settings: MobileKeyboardSettings) throws {
        guard let file = file else { throw CocoaError(.fileWriteNoPermission) }
        let value = settings.supported
        let data = try JSONEncoder().encode(value)
        var options: Data.WritingOptions = .atomic
        #if os(iOS)
        options.insert(.completeFileProtectionUntilFirstUserAuthentication)
        #endif
        try data.write(to: file, options: options)
        cached = value
        AppCopy.language = value.language
    }
    private func read() -> MobileKeyboardSettings? {
        guard let file = file, let data = try? Data(contentsOf: file) else { return nil }
        return try? JSONDecoder().decode(MobileKeyboardSettings.self, from: data)
    }
}
