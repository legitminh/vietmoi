import Foundation

enum KeyboardLanguage: String, Codable, CaseIterable {
    case english, vietnamese, chinese
    var displayName: String { AppCopy.text("keyboardLanguage." + rawValue) }
    var inputTypes: [InputType] {
        switch self {
        case .english: return [.english]
        case .vietnamese: return [.asciiPlus, .grid4x8, .telex]
        case .chinese: return [.microsoftShuangpin]
        }
    }
    var outputs: [OutputType] {
        switch self {
        case .english: return [.english]
        case .vietnamese: return [.sieuviet, .quocNgu]
        case .chinese: return [.simplifiedChinese]
        }
    }
}

enum InputMode: String, Codable, CaseIterable {
    case sieuviet, quocNgu = "quốc ngữ"
    var displayName: String { self == .sieuviet ? AppDesign.name : rawValue }
    var inventory: VietnamesePhoneticInventory { self == .sieuviet ? .sieuviet : .quocNgu }
    var keymap: ASCIIPlusKeymap { self == .sieuviet ? .sieuviet : .quocNgu }
}

enum InputType: String, Codable, CaseIterable {
    case grid4x8, asciiPlus = "ascii+", telex, english, microsoftShuangpin = "Microsoft Shuangpin"
    var language: KeyboardLanguage {
        self == .english ? .english : self == .microsoftShuangpin ? .chinese : .vietnamese
    }
}
enum OutputType: String, Codable, CaseIterable {
    case quocNgu = "quốc ngữ", sieuviet, english, simplifiedChinese = "Simplified Chinese"
    var displayName: String {
        switch self {
        case .sieuviet: return AppDesign.name
        case .english: return "English"
        case .simplifiedChinese: return AppCopy.text("simplifiedChinese")
        case .quocNgu: return rawValue
        }
    }
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        if value == "vietmoi" { self = .sieuviet }
        else if value == "vietstandard" { self = .quocNgu }
        else if let type = Self(rawValue: value) { self = type }
        else { throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unknown output type") }
    }
}

struct KeyboardProfile: Codable, Equatable, Identifiable {
    var id: UUID
    var name: String
    var language: KeyboardLanguage
    var inputType: InputType
    var inputMode: InputMode = .sieuviet
    var outputType: OutputType
    var showVirtualKeyboard: Bool
    var suggestionsEnabled: Bool
    var asciiPlusKeymap: ASCIIPlusKeymap? = nil
    var displayName: String {
        ["Default keyboard", "Vietnamese", "Bàn phím mặc định"].contains(name) ? language.displayName : name
    }
    init(id: UUID, name: String, inputType: InputType, outputType: OutputType, showVirtualKeyboard: Bool = true,
         suggestionsEnabled: Bool = true) {
        self.id = id
        self.name = name
        self.language = inputType.language
        self.inputType = inputType
        self.outputType = outputType
        self.showVirtualKeyboard = showVirtualKeyboard
        self.suggestionsEnabled = suggestionsEnabled
    }
    private enum CodingKeys: String, CodingKey {
        case id, name, language, inputType, inputMode, outputType, showVirtualKeyboard, suggestionsEnabled, asciiPlusKeymap
    }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        name = try values.decode(String.self, forKey: .name)
        inputType = try values.decode(InputType.self, forKey: .inputType)
        language = try values.decodeIfPresent(KeyboardLanguage.self, forKey: .language) ?? inputType.language
        inputMode = try values.decodeIfPresent(InputMode.self, forKey: .inputMode) ?? .sieuviet
        outputType = try values.decode(OutputType.self, forKey: .outputType)
        showVirtualKeyboard = try values.decodeIfPresent(Bool.self, forKey: .showVirtualKeyboard) ?? true
        suggestionsEnabled = try values.decodeIfPresent(Bool.self, forKey: .suggestionsEnabled) ?? true
        asciiPlusKeymap = try values.decodeIfPresent(ASCIIPlusKeymap.self, forKey: .asciiPlusKeymap)
        normalize()
    }
    mutating func normalize() {
        if !language.inputTypes.contains(inputType) { inputType = language.inputTypes[0] }
        if !language.outputs.contains(outputType) { outputType = language.outputs[0] }
    }
    static func makeDefault() -> KeyboardProfile {
        KeyboardProfile(id: UUID(), name: "Vietnamese", inputType: .asciiPlus, outputType: .sieuviet)
    }
    static func makeEnglish() -> KeyboardProfile {
        KeyboardProfile(id: UUID(), name: "English", inputType: .english, outputType: .english, showVirtualKeyboard: false)
    }
    static func makeChinese() -> KeyboardProfile {
        KeyboardProfile(id: UUID(), name: "Chinese · 微软双拼", inputType: .microsoftShuangpin, outputType: .simplifiedChinese)
    }
}
