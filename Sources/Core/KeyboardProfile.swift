import Foundation

// Portable profile values and schema migration. Persistence belongs to the host.
enum InputType: String, Codable, CaseIterable { case grid4x8, asciiPlus = "ascii+", telex, qwerty }
enum OutputType: String, Codable, CaseIterable {
    case quocNgu = "quốc ngữ", sieuviet, literal
    var displayName: String { self == .sieuviet ? AppDesign.name : self == .literal ? AppCopy.text("literalOutput") : rawValue }
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        if value == "vietmoi" { self = .sieuviet }
        else if value == "vietstandard" { self = .quocNgu }
        else if let type = Self(rawValue: value) { self = type }
        else { throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unknown output type") }
    }
}

// Each keyboard types one language. A language allows its own input layouts and
// outputs; the first of each is the default. A left Shift tap moves to the next keyboard.
enum KeyboardLanguage: String, Codable, CaseIterable {
    case vietnamese = "vi", english = "en"
    var inputs: [InputType] { self == .vietnamese ? [.asciiPlus, .grid4x8] : [.qwerty] }
    var outputs: [OutputType] { self == .vietnamese ? [.sieuviet, .quocNgu] : [.literal] }
}

struct KeyboardProfile: Codable, Equatable, Identifiable {
    var id: UUID
    var name: String
    var language: KeyboardLanguage = .vietnamese
    var inputType: InputType
    var outputType: OutputType
    var showVirtualKeyboard: Bool
    var asciiPlusKeymap: ASCIIPlusKeymap? = nil
    init(id: UUID, name: String, language: KeyboardLanguage = .vietnamese, inputType: InputType, outputType: OutputType,
         showVirtualKeyboard: Bool = true) {
        self.id = id
        self.name = name
        self.language = language
        self.inputType = inputType
        self.outputType = outputType
        self.showVirtualKeyboard = showVirtualKeyboard
        normalize()
    }
    /// Literal keyboards type plain text; the engine's literal mode implements them.
    var isLiteral: Bool { language == .english }
    /// Keep the input and output within those the language allows.
    mutating func normalize() {
        if !language.inputs.contains(inputType) { inputType = language.inputs[0] }
        if !language.outputs.contains(outputType) { outputType = language.outputs[0] }
    }
    private enum CodingKeys: String, CodingKey {
        case id, name, language, inputType, outputType, showVirtualKeyboard, asciiPlusKeymap
    }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        name = try values.decode(String.self, forKey: .name)
        language = (try? values.decodeIfPresent(KeyboardLanguage.self, forKey: .language)) ?? .vietnamese
        inputType = (try? values.decode(InputType.self, forKey: .inputType)) ?? language.inputs[0]
        outputType = (try? values.decode(OutputType.self, forKey: .outputType)) ?? language.outputs[0]
        showVirtualKeyboard = try values.decodeIfPresent(Bool.self, forKey: .showVirtualKeyboard) ?? true
        asciiPlusKeymap = try values.decodeIfPresent(ASCIIPlusKeymap.self, forKey: .asciiPlusKeymap)
        normalize()
    }
    static func makeDefault() -> KeyboardProfile {
        KeyboardProfile(id: UUID(), name: "Default keyboard", inputType: .grid4x8, outputType: .sieuviet)
    }
    static func makeEnglish() -> KeyboardProfile {
        KeyboardProfile(id: UUID(), name: "English", language: .english, inputType: .qwerty, outputType: .literal)
    }
    /// A new list types Vietnamese, and a Shift tap reaches English, as before keyboards were listed.
    static func makeDefaultList() -> [KeyboardProfile] { [makeDefault(), makeEnglish()] }
}
