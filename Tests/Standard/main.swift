import Foundation

var checks = 0
func expect(_ value: @autoclosure () -> Bool, _ message: String) {
    checks += 1
    if !value() { fatalError(message) }
}
func render(_ onset: String, _ onglide: String, _ core: String, _ final: String, _ tone: Int = 0) -> String {
    VietnamesePhoneticBasis(initial: onset, onglide: onglide, coreVowel: core,
                            tone: VietnameseTone(rawValue: tone)!, final: final).standard()
}
// Independently written word families check all six marks and main-vowel placement.
let families: [(String, String, String, String, String)] = [
    ("m", "", "a", "", "ma má mà mả mã mạ"),
    ("t", "", "ă", "i", "tay táy tày tảy tãy tạy"),
    ("t", "", "â", "i", "tây tấy tầy tẩy tẫy tậy"),
    ("r", "", "ă", "o", "rau ráu ràu rảu rãu rạu"),
    ("t", "", "a", "o", "tao táo tào tảo tão tạo"),
    ("", "", "i", "", "y ý ỳ ỷ ỹ ỵ"),
    ("h", "w", "a", "", "hoa hoá hoà hoả hoã hoạ"),
    ("kh", "w", "e", "", "khoe khoé khoè khoẻ khoẽ khoẹ"),
    ("th", "w", "i", "", "thuy thuý thuỳ thuỷ thuỹ thuỵ"),
    ("m", "", "iê", "", "mia mía mìa mỉa mĩa mịa"),
    ("m", "", "uô", "", "mua múa mùa mủa mũa mụa"),
    ("c", "", "ươ", "", "cưa cứa cừa cửa cữa cựa"),
    ("t", "", "iê", "ng", "tiêng tiếng tiềng tiểng tiễng tiệng"),
    ("m", "", "uô", "n", "muôn muốn muồn muổn muỗn muộn"),
    ("d", "", "ươ", "ng", "dương dướng dường dưởng dưỡng dượng"),
    ("c", "w", "a", "", "qua quá quà quả quã quạ")
]
for (initial, onglide, core, final, forms) in families {
    for (tone, word) in forms.split(separator: " ").enumerated() {
        expect(render(initial, onglide, core, final, tone) == word, "Tone/spelling: \(word)")
    }
}
let cases: [(String, String, String, String, Int, String)] = [
    ("t", "", "a", "i", 0, "tai"), ("t", "", "ă", "i", 0, "tay"),
    ("b", "w", "â", "i", 0, "buây"), ("", "w", "â", "i", 0, "uây"),
    ("b", "", "ê", "i", 0, "bêi"), // An extra combination must not be changed into another sound.
    ("kh", "w", "iê", "", 0, "khuya"), ("kh", "w", "i", "o", 3, "khuỷu"),
    ("ng", "", "iê", "ng", 0, "nghiêng"), ("ng", "", "iê", "", 4, "nghĩa"),
    ("ng", "", "e", "", 0, "nghe"), ("ng", "", "ê", "", 2, "nghề"),
    ("ng", "", "i", "", 3, "nghỉ"), ("ng", "", "a", "", 2, "ngà"),
    ("ng", "", "ă", "i", 2, "ngày"), ("ng", "w", "a", "i", 2, "ngoài"),
    ("g", "", "e", "", 0, "ghe"), ("g", "", "ê", "", 1, "ghế"),
    ("g", "", "i", "", 0, "ghi"), ("g", "", "a", "", 2, "gà"),
    ("g", "", "ă", "i", 0, "gay"), ("g", "w", "i", "", 0, "guy"),
    ("c", "", "e", "", 3, "kẻ"), ("c", "", "ê", "", 0, "kê"),
    ("c", "", "iê", "", 0, "kia"), ("k", "", "a", "", 1, "cá"),
    ("z", "", "i", "", 2, "gì"), ("z", "", "i", "n", 2, "gìn"),
    ("z", "", "iê", "ng", 1, "giếng"), ("z", "", "a", "", 2, "già"),
    ("z", "", "a", "i", 3, "giải"), ("z", "", "ươ", "", 4, "giữa"),
    ("z", "", "iê", "", 1, "gía"), ("z", "", "a", "", 1, "giá"),
    ("c", "w", "a", "", 3, "quả"), ("k", "w", "a", "", 3, "quả"),
    ("c", "", "uô", "", 3, "của"), ("c", "", "uô", "i", 1, "cuối"),
    ("c", "w", "i", "", 1, "quý"), ("c", "w", "iê", "n", 3, "quyển"),
    ("c", "w", "ê", "", 0, "quê"), ("c", "w", "ô", "c", 1, "quốc"),
    ("c", "w", "e", "o", 2, "quèo"), ("c", "w", "ă", "i", 0, "quay"),
    ("th", "w", "iê", "n", 2, "thuyền"), ("t", "w", "iê", "t", 1, "tuyết"),
    ("kh", "w", "iê", "n", 0, "khuyên"), ("", "", "iê", "n", 1, "yến"),
    ("", "", "iê", "o", 0, "yêu"), ("b", "", "iê", "", 2, "bìa"),
    ("m", "", "uô", "n", 5, "muộn"), ("m", "", "uô", "", 1, "múa"),
    ("l", "", "ươ", "", 3, "lửa"), ("đ", "", "ươ", "c", 5, "được"),
    ("t", "", "ươ", "i", 0, "tươi"), ("t", "", "iê", "o", 3, "tiểu"),
    ("h", "w", "ê", "", 5, "huệ"), ("th", "w", "ơ", "", 3, "thuở"),
    ("h", "w", "â", "n", 1, "huấn"), ("h", "w", "ă", "c", 5, "hoặc"),
    ("s", "", "a", "o", 0, "sao"), ("s", "", "ă", "o", 0, "sau"),
    ("m", "", "i", "o", 5, "mịu"), ("t", "", "ư", "", 2, "từ"),
    ("ch", "", "uô", "", 0, "chua"), ("f", "", "ơ", "", 3, "phở"),
    ("b", "", "e", "o", 2, "bèo"), ("k", "", "ê", "o", 0, "kêu"),
    ("c", "", "â", "o", 2, "cầu"), ("c", "", "ư", "o", 1, "cứu"),
    ("h", "", "ươ", "o", 0, "hươu"), ("x", "", "oo", "ng", 0, "xoong"),
    ("s", "", "oo", "c", 1, "soóc"), ("", "", "o", "ng", 0, "ong"),
    ("m", "", "i", "ng", 2, "mình"), ("k", "", "ê", "ng", 0, "kênh"),
    ("m", "", "e", "c", 1, "mách"), ("th", "", "e", "nh", 0, "thanh"),
    ("m", "", "i", "ch", 5, "mịch"), ("ch", "", "e", "ng", 0, "chanh")
]
for (initial, onglide, core, final, tone, word) in cases {
    expect(render(initial, onglide, core, final, tone) == word, "Spelling: \(word)")
}

func choose(_ character: Character, into engine: inout KeyboardEngine) -> EngineEffect {
    let key = ASCIIKeyboardLayout.keyCodesByLabel[String(character)]!
    return engine.selectComponent(ASCIIPlusMapping.bindings(for: engine.phase)[key]!)
}
var engine = KeyboardEngine(outputType: .quocNgu)
for (key, preview) in zip("aea", ["ng", "ngiê", "ngiêng"]) {
    expect(choose(key, into: &engine) == .marked(preview), "No spelling conversion during a partial word")
}
expect(choose("s", into: &engine) == .commit("nghiêng "), "Only final tone converts the full basis")
expect(engine.lastCommittedBasis?.initial == "ng" && engine.lastCommittedBasis?.coreVowel == "iê", "Conversion retains the original basis")
for keys in ["f", "jl", "rw", "aea"] {
    var partial = KeyboardEngine(outputType: .quocNgu)
    for key in keys { _ = choose(key, into: &partial) }
    let expected = ["f":"f ", "jl":"chuô ", "rw":"ră ", "aea":"ngiêng "][keys]!
    expect(partial.finishPartial(suffix: " ") == .commit(expected), "Space keeps unfinished phonetic text")
}
var abbreviated = KeyboardEngine(outputType: .quocNgu)
_ = choose("f", into: &abbreviated)
expect(abbreviated.press(24) == .commit("f") && abbreviated.ascii, "Mode switch keeps unfinished initial without translating")

// All complete paths must stay permissive, carry the chosen tone once, and agree
// while keeping the draft phonetic through round three.
let toneMarks: Set<UInt32> = [0x301, 0x300, 0x309, 0x303, 0x323]
let expectedMarks: [UInt32?] = [nil, 0x301, 0x300, 0x309, 0x303, 0x323]
var paths = 0
for initial in engine.inventory.initials.indices {
    for vowel in engine.inventory.vowelAtoms.indices {
        for final in engine.inventory.finals.indices {
            for tone in VietnameseTone.allCases {
                var composed = KeyboardEngine(outputType: .quocNgu)
                for atom in [initial, vowel, final] { _ = composed.selectComponent(atom) }
                let draft = composed.phoneticBasis!
                expect(composed.preview == draft.sieuviet(), "Draft is always phonetic")
                let result = composed.selectComponent(tone.rawValue)
                guard case .commit(let text) = result else { fatalError("Every full construction must commit") }
                let marks = text.decomposedStringWithCanonicalMapping.unicodeScalars.map(\.value).filter { toneMarks.contains($0) }
                expect(text.hasSuffix(" ") && CompositionText.isSafe(text) && text == text.precomposedStringWithCanonicalMapping &&
                       marks == (expectedMarks[tone.rawValue].map { [$0] } ?? []), "Safe NFC output with one selected tone")
                expect(composed.lastCommittedBasis?.tone == tone && composed.lastCommittedBasis?.final == draft.final, "Stored basis survives rendering")
                paths += 1
            }
        }
    }
}
print("Passed \(checks) quốc ngữ checks, including \(paths) completed phonetic paths.")
