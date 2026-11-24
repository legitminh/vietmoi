#if !hasFeature(Embedded)
import Foundation
#endif

// The app-owned snapshot the keyboard reads: the managed keyboard list, the
// app's selected keyboard and the interface language. A Shift tap in the
// keyboard moves to the next keyboard without writing this snapshot.
struct MobileKeyboardSettings: Equatable {
    static let inputTypes: [InputType] = [.asciiPlus, .grid4x8]
    // Stable identities for lists created from older single-keyboard snapshots.
    static let vietnameseID = UUID(uuidString: "5F1E7C2A-0000-4000-8000-000000000001")!
    static let englishID = UUID(uuidString: "5F1E7C2A-0000-4000-8000-000000000002")!
    static let chineseID = UUID(uuidString: "5F1E7C2A-0000-4000-8000-000000000003")!
    var profiles: [KeyboardProfile]
    var activeID: UUID
    var language: String = "vi"
    static let standard = MobileKeyboardSettings()

    init(input: InputType = .asciiPlus, output: OutputType = .sieuviet, language: String = "vi",
         inputMode: InputMode = .sieuviet, suggestionsEnabled: Bool = true) {
        var first = KeyboardProfile(id: Self.vietnameseID, name: "Default keyboard", inputType: input, outputType: output,
                                    suggestionsEnabled: suggestionsEnabled)
        first.inputMode = inputMode
        profiles = [first,
                    KeyboardProfile(id: Self.englishID, name: "English", language: .english, inputType: .qwerty, outputType: .literal)]
        activeID = Self.vietnameseID
        self.language = language
    }
    init(profiles: [KeyboardProfile], activeID: UUID, language: String) {
        self.profiles = profiles; self.activeID = activeID; self.language = language
    }
    /// The keyboard selected in the app.
    var active: KeyboardProfile { profiles.first { $0.id == activeID } ?? profiles[0] }
    private var activeIndex: Int { profiles.firstIndex { $0.id == activeID } ?? 0 }
    /// Input and output of the app's selected keyboard.
    var input: InputType {
        get { active.inputType }
        set { profiles[activeIndex].inputType = newValue; profiles[activeIndex] = Self.restricted(profiles[activeIndex]) }
    }
    var output: OutputType {
        get { active.outputType }
        set { profiles[activeIndex].outputType = newValue; profiles[activeIndex] = Self.restricted(profiles[activeIndex]) }
    }
    var inputMode: InputMode {
        get { active.inputMode }
        set { profiles[activeIndex].inputMode = newValue }
    }
    /// Completion for the app's selected keyboard.
    var suggestionsEnabled: Bool {
        get { active.suggestionsEnabled }
        set { profiles[activeIndex].suggestionsEnabled = newValue }
    }
    var keyboardLanguage: KeyboardLanguage { active.language }
    /// Completion for the first listed keyboard of a language (on when none is listed).
    func completionEnabled(for language: KeyboardLanguage) -> Bool {
        profiles.first { $0.language == language }?.suggestionsEnabled ?? true
    }
    private static func restricted(_ profile: KeyboardProfile) -> KeyboardProfile {
        var value = profile
        value.normalize()
        if value.language == .vietnamese && !inputTypes.contains(value.inputType) { value.inputType = .asciiPlus }
        return value
    }
    var supported: MobileKeyboardSettings {
        let list = profiles.isEmpty ? Self.standard.profiles : profiles.map(Self.restricted)
        return Self(profiles: list, activeID: list.contains { $0.id == activeID } ? activeID : list[0].id,
                    language: AppCopy.supportedLanguage(language))
    }
}

// Stored snapshots. The web demo hands its list to the session directly.
#if !hasFeature(Embedded)
extension MobileKeyboardSettings: Codable {
    private enum CodingKeys: String, CodingKey {
        case profiles, activeID, language, input, output
        case inputMode, suggestionsEnabled, keyboardLanguage, completionByLanguage  // 0.15 single-keyboard snapshots
    }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let language = try values.decodeIfPresent(String.self, forKey: .language) ?? "vi"
        if let profiles = try values.decodeIfPresent([KeyboardProfile].self, forKey: .profiles), !profiles.isEmpty {
            self.init(profiles: profiles, activeID: try values.decodeIfPresent(UUID.self, forKey: .activeID) ?? profiles[0].id, language: language)
        } else {
            // A single-keyboard snapshot becomes that keyboard plus English, which the old Shift tap reached.
            self.init(input: (try? values.decode(InputType.self, forKey: .input)) ?? .asciiPlus,
                      output: try values.decode(OutputType.self, forKey: .output), language: language)
            // 0.15 snapshots also cycled to Chinese and kept completion per language.
            guard let selected = try values.decodeIfPresent(KeyboardLanguage.self, forKey: .keyboardLanguage) else { return }
            profiles.append(KeyboardProfile(id: Self.chineseID, name: "Chinese · 微软双拼", language: .chinese,
                                            inputType: .microsoftShuangpin, outputType: .simplifiedChinese))
            profiles[0].inputMode = try values.decodeIfPresent(InputMode.self, forKey: .inputMode) ?? .sieuviet
            let completion = try values.decodeIfPresent([String: Bool].self, forKey: .completionByLanguage) ?? [:]
            let current = try values.decodeIfPresent(Bool.self, forKey: .suggestionsEnabled) ?? true
            for index in profiles.indices {
                let language = profiles[index].language
                profiles[index].suggestionsEnabled = language == selected ? current : completion[language.legacyName] ?? true
            }
            activeID = profiles.first { $0.language == selected }?.id ?? activeID
        }
    }
    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(profiles, forKey: .profiles)
        try values.encode(activeID, forKey: .activeID)
        try values.encode(language, forKey: .language)
    }
}
#endif
