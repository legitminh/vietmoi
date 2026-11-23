import Foundation

struct MobileKeyboardSettings: Codable, Equatable {
    static let inputTypes: [InputType] = [.asciiPlus, .grid4x8]
    var input: InputType = .asciiPlus
    var inputMode: InputMode = .sieuviet
    var output: OutputType = .sieuviet
    var language: String = "vi"
    var suggestionsEnabled: Bool = true
    var keyboardLanguage: KeyboardLanguage = .vietnamese
    var selectionRevision = 0
    var completionByLanguage: [String: Bool] = [:]
    func completionEnabled(for language: KeyboardLanguage) -> Bool {
        language == keyboardLanguage ? suggestionsEnabled : completionByLanguage[language.rawValue] ?? true
    }
    mutating func selectLanguage(_ language: KeyboardLanguage) {
        selectionRevision += 1
        completionByLanguage[keyboardLanguage.rawValue] = suggestionsEnabled
        keyboardLanguage = language
        suggestionsEnabled = completionByLanguage[language.rawValue] ?? true
    }
    static let standard = MobileKeyboardSettings()
    var supported: MobileKeyboardSettings {
        var result = self
        result.input = Self.inputTypes.contains(input) ? input : .asciiPlus
        result.output = KeyboardLanguage.vietnamese.outputs.contains(output) ? output : .sieuviet
        result.language = language == "en" ? "en" : "vi"
        return result
    }
    private enum CodingKeys: String, CodingKey { case input, inputMode, output, language, suggestionsEnabled, keyboardLanguage, completionByLanguage, selectionRevision }
    init(input: InputType = .asciiPlus, output: OutputType = .sieuviet, language: String = "vi", inputMode: InputMode = .sieuviet,
         suggestionsEnabled: Bool = true) {
        self.inputMode = inputMode; self.input = input; self.output = output; self.language = language
        self.suggestionsEnabled = suggestionsEnabled
    }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        input = .asciiPlus
        inputMode = try values.decodeIfPresent(InputMode.self, forKey: .inputMode) ?? .sieuviet
        output = try values.decode(OutputType.self, forKey: .output)
        language = try values.decodeIfPresent(String.self, forKey: .language) ?? "vi"
        suggestionsEnabled = try values.decodeIfPresent(Bool.self, forKey: .suggestionsEnabled) ?? true
        keyboardLanguage = try values.decodeIfPresent(KeyboardLanguage.self, forKey: .keyboardLanguage) ?? .vietnamese
        selectionRevision = try values.decodeIfPresent(Int.self, forKey: .selectionRevision) ?? 0
        completionByLanguage = try values.decodeIfPresent([String: Bool].self, forKey: .completionByLanguage) ?? [:]
    }
}
