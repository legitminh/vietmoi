import Foundation

struct MobileKeyboardSettings: Codable, Equatable {
    static let inputTypes: [InputType] = [.asciiPlus, .grid4x8]
    var input: InputType = .asciiPlus
    var output: OutputType = .sieuviet
    var language: String = "vi"
    static let standard = MobileKeyboardSettings()
    var supported: MobileKeyboardSettings {
        Self(input: Self.inputTypes.contains(input) ? input : .asciiPlus, output: output,
             language: language == "en" ? "en" : "vi")
    }
    private enum CodingKeys: String, CodingKey { case input, output, language }
    init(input: InputType = .asciiPlus, output: OutputType = .sieuviet, language: String = "vi") {
        self.input = input; self.output = output; self.language = language
    }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        input = try values.decode(InputType.self, forKey: .input)
        output = try values.decode(OutputType.self, forKey: .output)
        language = try values.decodeIfPresent(String.self, forKey: .language) ?? "vi"
    }
}
