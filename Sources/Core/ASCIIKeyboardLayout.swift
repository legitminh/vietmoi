import Foundation

struct ASCIIKey {
    let label: String
    let keyCode: UInt16
    var units: Double = 1
}

enum ASCIIKeyboardLayout {
    // ANSI/US physical key positions. Modifier shortcuts remain handled by macOS.
    static let rows: [[ASCIIKey]] = [
        [ASCIIKey(label: "`", keyCode: 50), ASCIIKey(label: "1", keyCode: 18),
         ASCIIKey(label: "2", keyCode: 19), ASCIIKey(label: "3", keyCode: 20),
         ASCIIKey(label: "4", keyCode: 21), ASCIIKey(label: "5", keyCode: 23),
         ASCIIKey(label: "6", keyCode: 22), ASCIIKey(label: "7", keyCode: 26),
         ASCIIKey(label: "8", keyCode: 28), ASCIIKey(label: "9", keyCode: 25),
         ASCIIKey(label: "0", keyCode: 29), ASCIIKey(label: "-", keyCode: 27),
         ASCIIKey(label: "=", keyCode: 24), ASCIIKey(label: "⌫", keyCode: 51, units: 1.5)],
        [ASCIIKey(label: "Tab", keyCode: 48, units: 1.5),
         ASCIIKey(label: "q", keyCode: 12), ASCIIKey(label: "w", keyCode: 13),
         ASCIIKey(label: "e", keyCode: 14), ASCIIKey(label: "r", keyCode: 15),
         ASCIIKey(label: "t", keyCode: 17), ASCIIKey(label: "y", keyCode: 16),
         ASCIIKey(label: "u", keyCode: 32), ASCIIKey(label: "i", keyCode: 34),
         ASCIIKey(label: "o", keyCode: 31), ASCIIKey(label: "p", keyCode: 35),
         ASCIIKey(label: "[", keyCode: 33), ASCIIKey(label: "]", keyCode: 30),
         ASCIIKey(label: "\\", keyCode: 42)],
        [ASCIIKey(label: "Caps", keyCode: 57, units: 1.75),
         ASCIIKey(label: "a", keyCode: 0), ASCIIKey(label: "s", keyCode: 1),
         ASCIIKey(label: "d", keyCode: 2), ASCIIKey(label: "f", keyCode: 3),
         ASCIIKey(label: "g", keyCode: 5), ASCIIKey(label: "h", keyCode: 4),
         ASCIIKey(label: "j", keyCode: 38), ASCIIKey(label: "k", keyCode: 40),
         ASCIIKey(label: "l", keyCode: 37), ASCIIKey(label: ";", keyCode: 41),
         ASCIIKey(label: "'", keyCode: 39), ASCIIKey(label: "Return", keyCode: 36, units: 1.75)],
        [ASCIIKey(label: "Shift", keyCode: 56, units: 2.25),
         ASCIIKey(label: "z", keyCode: 6), ASCIIKey(label: "x", keyCode: 7),
         ASCIIKey(label: "c", keyCode: 8), ASCIIKey(label: "v", keyCode: 9),
         ASCIIKey(label: "b", keyCode: 11), ASCIIKey(label: "n", keyCode: 45),
         ASCIIKey(label: "m", keyCode: 46), ASCIIKey(label: ",", keyCode: 43),
         ASCIIKey(label: ".", keyCode: 47), ASCIIKey(label: "/", keyCode: 44),
         ASCIIKey(label: "Shift", keyCode: 60, units: 2.25)],
        [ASCIIKey(label: "Esc", keyCode: 53, units: 2.25),
         ASCIIKey(label: "Space", keyCode: 49, units: 10),
         ASCIIKey(label: "Fn⌫", keyCode: 117, units: 2.25)]
    ]
    static let keys = rows.flatMap { $0 }
    static let keyCodesByLabel: [String: UInt16] = Dictionary(
        keys.filter { $0.label.count == 1 }.map { ($0.label, $0.keyCode) },
        uniquingKeysWith: { first, _ in first })
}
