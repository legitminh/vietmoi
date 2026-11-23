import Foundation

// The app-owned snapshot the keyboard reads: the managed keyboard list, the
// app's selected keyboard and the interface language. A Shift tap in the
// keyboard moves to the next keyboard without writing this snapshot.
struct MobileKeyboardSettings: Codable, Equatable {
    static let inputTypes: [InputType] = [.asciiPlus, .grid4x8]
    // Stable identities for lists created from older single-keyboard snapshots.
    static let vietnameseID = UUID(uuidString: "5F1E7C2A-0000-4000-8000-000000000001")!
    static let englishID = UUID(uuidString: "5F1E7C2A-0000-4000-8000-000000000002")!
    var profiles: [KeyboardProfile]
    var activeID: UUID
    var language: String = "vi"
    static let standard = MobileKeyboardSettings()

    init(input: InputType = .asciiPlus, output: OutputType = .sieuviet, language: String = "vi") {
        profiles = [KeyboardProfile(id: Self.vietnameseID, name: "Default keyboard", inputType: input, outputType: output),
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
    private static func restricted(_ profile: KeyboardProfile) -> KeyboardProfile {
        var value = profile
        value.normalize()
        if value.language == .vietnamese && !inputTypes.contains(value.inputType) { value.inputType = .asciiPlus }
        return value
    }
    var supported: MobileKeyboardSettings {
        let list = profiles.isEmpty ? Self.standard.profiles : profiles.map(Self.restricted)
        return Self(profiles: list, activeID: list.contains { $0.id == activeID } ? activeID : list[0].id,
                    language: language == "en" ? "en" : "vi")
    }
    private enum CodingKeys: String, CodingKey { case profiles, activeID, language, input, output }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let language = try values.decodeIfPresent(String.self, forKey: .language) ?? "vi"
        if let profiles = try values.decodeIfPresent([KeyboardProfile].self, forKey: .profiles), !profiles.isEmpty {
            self.init(profiles: profiles, activeID: try values.decodeIfPresent(UUID.self, forKey: .activeID) ?? profiles[0].id, language: language)
        } else {
            // A single-keyboard snapshot becomes that keyboard plus English, which the old Shift tap reached.
            self.init(input: try values.decode(InputType.self, forKey: .input),
                      output: try values.decode(OutputType.self, forKey: .output), language: language)
        }
    }
    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(profiles, forKey: .profiles)
        try values.encode(activeID, forKey: .activeID)
        try values.encode(language, forKey: .language)
    }
}
