#if !hasFeature(Embedded)
import Foundation
#endif

// Portable profile values and schema migration. Persistence belongs to the host.
enum InputType: String, CaseIterable {
    case grid4x8, asciiPlus = "ascii+", telex, qwerty, microsoftShuangpin = "Microsoft Shuangpin"
    /// The language this layout belongs to (telex is a Vietnamese layout).
    var language: KeyboardLanguage {
        self == .qwerty ? .english : self == .microsoftShuangpin ? .chinese : .vietnamese
    }
}
#if !hasFeature(Embedded)
extension InputType: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        if value == "english" { self = .qwerty }  // 0.15 Apple builds
        else if let type = Self(rawValue: value) { self = type }
        else { throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unknown input type") }
    }
}
#endif
enum OutputType: String, CaseIterable {
    case quocNgu = "quốc ngữ", sieuviet, literal, simplifiedChinese = "Simplified Chinese"
}
#if !hasFeature(Embedded)
// Interface copy and stored values belong to the native hosts.
extension OutputType {
    var displayName: String {
        switch self {
        case .sieuviet: return AppDesign.name
        case .literal: return AppCopy.text("literalOutput")
        case .simplifiedChinese: return AppCopy.text("simplifiedChinese")
        case .quocNgu: return rawValue
        }
    }
}
extension OutputType: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        if value == "vietmoi" { self = .sieuviet }
        else if value == "vietstandard" { self = .quocNgu }
        else if value == "english" { self = .literal }  // 0.15 Apple builds
        else if let type = Self(rawValue: value) { self = type }
        else { throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unknown output type") }
    }
}
#endif

// Each keyboard types one language. A language allows its own input layouts and
// outputs; the first of each is the default. A left Shift tap moves to the next keyboard.
enum KeyboardLanguage: String, CaseIterable {
    case vietnamese = "vi", english = "en", chinese = "zh"
    var inputs: [InputType] {
        switch self {
        case .vietnamese: return [.asciiPlus, .grid4x8]
        case .english: return [.qwerty]
        case .chinese: return [.microsoftShuangpin]
        }
    }
    var outputs: [OutputType] {
        switch self {
        case .vietnamese: return [.sieuviet, .quocNgu]
        case .english: return [.literal]
        case .chinese: return [.simplifiedChinese]
        }
    }
    /// Copy keys and 0.15 Apple storage use the spelled-out name.
    var legacyName: String { self == .vietnamese ? "vietnamese" : self == .english ? "english" : "chinese" }
}
#if !hasFeature(Embedded)
extension KeyboardLanguage {
    var displayName: String { AppCopy.text("keyboardLanguage." + legacyName) }
}
extension KeyboardLanguage: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        if let language = Self(rawValue: value) ?? Self.allCases.first(where: { $0.legacyName == value }) { self = language }
        else { throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unknown keyboard language") }
    }
}
#endif

// How ASCII+ keys spell Vietnamese: by sound (siêu việt) or by quốc ngữ letters.
enum InputMode: String, CaseIterable {
    case sieuviet, quocNgu = "quốc ngữ"
    var inventory: VietnamesePhoneticInventory { self == .sieuviet ? .sieuviet : .quocNgu }
    var keymap: ASCIIPlusKeymap { self == .sieuviet ? .sieuviet : .quocNgu }
}

#if !hasFeature(Embedded)
extension InputMode: Codable {}
extension InputMode {
    var displayName: String { self == .sieuviet ? AppDesign.name : rawValue }
}
#endif

struct KeyboardProfile: Equatable, Identifiable {
    var id: UUID
    var name: String
    var language: KeyboardLanguage = .vietnamese
    var inputType: InputType
    var inputMode: InputMode = .sieuviet
    var outputType: OutputType
    var showVirtualKeyboard: Bool
    var suggestionsEnabled: Bool = true
    /// Vietnamese only: a phrase mark right after a block replaces its automatic space ("quá !" → "quá! ").
    var adaptivePunctuation: Bool = true
    var asciiPlusKeymap: ASCIIPlusKeymap? = nil
    #if !hasFeature(Embedded)
    var displayName: String {
        ["Default keyboard", "Vietnamese", "Bàn phím mặc định"].contains(name) ? language.displayName : name
    }
    #endif
    init(id: UUID, name: String, language: KeyboardLanguage? = nil, inputType: InputType, outputType: OutputType,
         showVirtualKeyboard: Bool = true, suggestionsEnabled: Bool = true) {
        self.id = id
        self.name = name
        self.language = language ?? inputType.language
        self.inputType = inputType
        self.outputType = outputType
        self.showVirtualKeyboard = showVirtualKeyboard
        self.suggestionsEnabled = suggestionsEnabled
        normalize()
    }
    /// Literal keyboards type plain text; the engine's literal mode implements them.
    var isLiteral: Bool { language == .english }
    /// Keep the input and output within those the language allows.
    mutating func normalize() {
        if !language.inputs.contains(inputType) { inputType = language.inputs[0] }
        if !language.outputs.contains(outputType) { outputType = language.outputs[0] }
    }
    static func makeDefault() -> KeyboardProfile {
        KeyboardProfile(id: UUID(), name: "Default keyboard", inputType: .grid4x8, outputType: .sieuviet)
    }
    static func makeEnglish() -> KeyboardProfile {
        KeyboardProfile(id: UUID(), name: "English", language: .english, inputType: .qwerty, outputType: .literal)
    }
    static func makeChinese() -> KeyboardProfile {
        KeyboardProfile(id: UUID(), name: "Chinese · 微软双拼", language: .chinese, inputType: .microsoftShuangpin, outputType: .simplifiedChinese)
    }
    /// A new list types Vietnamese, and a Shift tap reaches English, as before keyboards were listed.
    static func makeDefaultList() -> [KeyboardProfile] { [makeDefault(), makeEnglish()] }
}
#if !hasFeature(Embedded)
extension KeyboardProfile: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, name, language, inputType, inputMode, outputType, showVirtualKeyboard, suggestionsEnabled, adaptivePunctuation, asciiPlusKeymap
    }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        name = try values.decode(String.self, forKey: .name)
        let input = try? values.decode(InputType.self, forKey: .inputType)
        language = (try? values.decodeIfPresent(KeyboardLanguage.self, forKey: .language)) ?? input?.language ?? .vietnamese
        inputType = input ?? language.inputs[0]
        inputMode = (try? values.decodeIfPresent(InputMode.self, forKey: .inputMode)) ?? .sieuviet
        outputType = (try? values.decode(OutputType.self, forKey: .outputType)) ?? language.outputs[0]
        showVirtualKeyboard = try values.decodeIfPresent(Bool.self, forKey: .showVirtualKeyboard) ?? true
        suggestionsEnabled = try values.decodeIfPresent(Bool.self, forKey: .suggestionsEnabled) ?? true
        adaptivePunctuation = (try? values.decodeIfPresent(Bool.self, forKey: .adaptivePunctuation)) ?? true
        asciiPlusKeymap = try values.decodeIfPresent(ASCIIPlusKeymap.self, forKey: .asciiPlusKeymap)
        normalize()
    }
}
#endif
