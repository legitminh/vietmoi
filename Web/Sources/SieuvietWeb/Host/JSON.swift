/// A tiny JSON writer for the state the page renders (Embedded Swift has no JSONSerialization).
struct JSONWriter {
    private(set) var text = ""
    mutating func raw(_ value: String) { text += value }
    mutating func string(_ value: String?) {
        guard let value = value else { text += "null"; return }
        text += "\""
        for scalar in value.unicodeScalars {
            switch scalar {
            case "\"": text += "\\\""
            case "\\": text += "\\\\"
            case "\n": text += "\\n"
            case "\r": text += "\\r"
            case "\t": text += "\\t"
            default:
                if scalar.value < 0x20 {
                    let hex = Array("0123456789abcdef")
                    text += "\\u00" + String(hex[Int(scalar.value >> 4)]) + String(hex[Int(scalar.value & 0xf)])
                } else { text.unicodeScalars.append(scalar) }
            }
        }
        text += "\""
    }
    mutating func bool(_ value: Bool) { text += value ? "true" : "false" }
    mutating func int(_ value: Int) { text += String(value) }
    mutating func key(_ name: String) { if !text.hasSuffix("{") { text += "," }; string(name); text += ":" }
    mutating func strings(_ values: [String]) {
        text += "["
        for (index, value) in values.enumerated() { if index > 0 { text += "," }; string(value) }
        text += "]"
    }
}
