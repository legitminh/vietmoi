import Foundation

// Portable profile values and schema migration. Persistence belongs to the host.
enum InputType: String, Codable, CaseIterable { case grid4x8, asciiPlus = "ascii+", telex }
enum OutputType: String, Codable, CaseIterable {
    case quocNgu = "quốc ngữ", sieuviet
    var displayName: String { self == .sieuviet ? AppDesign.name : rawValue }
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
    var inputType: InputType
    var outputType: OutputType
    var showVirtualKeyboard: Bool
    var asciiPlusKeymap: ASCIIPlusKeymap? = nil
    init(id: UUID, name: String, inputType: InputType, outputType: OutputType, showVirtualKeyboard: Bool = true) {
        self.id = id
        self.name = name
        self.inputType = inputType
        self.outputType = outputType
        self.showVirtualKeyboard = showVirtualKeyboard
    }
    private enum CodingKeys: String, CodingKey {
        case id, name, inputType, outputType, showVirtualKeyboard, asciiPlusKeymap
    }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        name = try values.decode(String.self, forKey: .name)
        inputType = try values.decode(InputType.self, forKey: .inputType)
        outputType = try values.decode(OutputType.self, forKey: .outputType)
        showVirtualKeyboard = try values.decodeIfPresent(Bool.self, forKey: .showVirtualKeyboard) ?? true
        asciiPlusKeymap = try values.decodeIfPresent(ASCIIPlusKeymap.self, forKey: .asciiPlusKeymap)
    }
    static func makeDefault() -> KeyboardProfile {
        KeyboardProfile(id: UUID(), name: "Default keyboard", inputType: .grid4x8, outputType: .sieuviet)
    }
}
