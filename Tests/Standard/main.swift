import Foundation

var checks = 0
func expect(_ value: @autoclosure () -> Bool, _ message: String) {
    checks += 1
    if !value() { fatalError(message) }
}
func render(_ onset: String, _ medial: String, _ nucleus: String, _ coda: String, _ tone: Int = 0) -> String {
    StandardVietnamese.render(initial: onset, medial: medial, nucleus: nucleus, final: coda, tone: tone)
}
// Hand-written expected spellings, independent of the formatter's tone table.
let families: [(String, String, String, String, String)] = [
    ("m", "", "a", "", "ma má mà mả mã mạ"),
    ("t", "", "e", "i", "tay táy tày tảy tãy tạy"),
    ("t", "", "â", "i", "tây tấy tầy tẩy tẫy tậy"),
    ("", "", "i", "", "y ý ỳ ỷ ỹ ỵ"),
    ("b", "", "ê", "i", "bây bấy bầy bẩy bẫy bậy"),
    ("b", "u", "ê", "i", "uây uấy uầy uẩy uẫy uậy"),
    ("h", "o", "a", "", "hoa hoá hoà hoả hoã hoạ"),
    ("kh", "o", "e", "", "khoe khoé khoè khoẻ khoẽ khoẹ"),
    ("th", "u", "i", "", "thuy thuý thuỳ thuỷ thuỹ thuỵ"),
    ("m", "", "ia", "", "mia mía mìa mỉa mĩa mịa"),
    ("m", "", "ua", "", "mua múa mùa mủa mũa mụa"),
    ("c", "", "ưa", "", "cưa cứa cừa cửa cữa cựa"),
    ("t", "", "iê", "ng", "tiêng tiếng tiềng tiểng tiễng tiệng"),
    ("m", "", "uô", "n", "muôn muốn muồn muổn muỗn muộn"),
    ("d", "", "ươ", "ng", "dương dướng dường dưởng dưỡng dượng")
]
for (onset, medial, nucleus, coda, forms) in families {
    let expected = forms.split(separator: " ")
    for (tone, word) in expected.enumerated() {
        expect(render(onset, medial, nucleus, coda, tone) == word, "Tone placement: \(word)")
    }
}
let cases: [(String, String, String, String, Int, String)] = [
    ("t", "", "a", "i", 0, "tai"), ("t", "", "e", "i", 0, "tay"),
    ("", "", "i", "", 1, "ý"), ("", "", "i", "n", 1, "ín"),
    ("b", "", "ê", "i", 0, "bây"), ("b", "u", "ê", "i", 0, "uây"),
    ("", "u", "ê", "i", 0, "uây"),
    ("kh", "u", "ia", "", 0, "khuya"),
    ("kh", "u", "iê", "", 0, "khuya"),
    ("ng", "", "iê", "ng", 0, "nghiêng"),
    ("ng", "", "ia", "ng", 2, "nghiềng"),
    ("ng", "", "ia", "", 4, "nghĩa"),
    ("ng", "", "e", "", 0, "nghe"), ("ng", "", "ê", "", 2, "nghề"),
    ("ng", "", "i", "", 3, "nghỉ"), ("ng", "", "a", "", 2, "ngà"),
    ("ng", "", "e", "i", 2, "ngày"), ("ng", "o", "a", "i", 2, "ngoài"),
    ("g", "", "e", "", 0, "ghe"), ("g", "", "ê", "", 1, "ghế"),
    ("g", "", "i", "", 0, "ghi"), ("g", "", "a", "", 2, "gà"),
    ("g", "", "e", "i", 0, "gay"),
    ("c", "", "e", "", 3, "kẻ"), ("c", "", "ê", "", 0, "kê"),
    ("c", "", "ia", "", 0, "kia"), ("k", "", "a", "", 1, "cá"),
    ("gi", "", "i", "", 2, "gì"), ("gi", "", "i", "n", 2, "gìn"),
    ("gi", "", "iê", "ng", 1, "giếng"), ("gi", "", "a", "", 2, "già"),
    ("gi", "", "a", "i", 3, "giải"), ("gi", "", "ưa", "", 4, "giữa"),
    ("qu", "", "a", "", 3, "quả"), ("qu", "u", "a", "", 3, "quả"),
    ("c", "u", "a", "", 3, "cuả"), ("c", "o", "a", "", 0, "coa"),
    ("k", "u", "a", "", 3, "cuả"), ("k", "o", "a", "", 0, "coa"),
    ("c", "", "ua", "", 3, "của"), ("c", "", "ua", "i", 1, "cuối"),
    ("qu", "", "i", "", 1, "quý"), ("qu", "", "iê", "n", 3, "quyển"),
    ("qu", "", "ê", "", 0, "quê"), ("qu", "", "ô", "c", 1, "quốc"),
    ("th", "u", "iê", "n", 2, "thuyền"),
    ("t", "u", "ia", "t", 1, "tuyết"),
    ("kh", "u", "iê", "n", 0, "khuyên"),
    ("", "", "iê", "n", 1, "yến"), ("", "", "ia", "u", 0, "yêu"),
    ("b", "", "iê", "", 2, "bìa"),
    ("m", "", "ua", "n", 5, "muộn"), ("m", "", "uô", "", 1, "múa"),
    ("l", "", "ươ", "", 3, "lửa"), ("đ", "", "ưa", "c", 5, "được"),
    ("t", "", "ươ", "i", 0, "tươi"), ("t", "", "iê", "u", 3, "tiểu"),
    ("h", "u", "ê", "", 5, "huệ"), ("th", "u", "ơ", "", 3, "thuở"),
    ("t", "", "ă", "i", 0, "tay"), ("s", "", "ă", "u", 0, "sau"),
    ("h", "u", "â", "n", 1, "huấn"), ("h", "o", "ă", "c", 5, "hoặc"),
    ("s", "", "a", "o", 0, "sao"), ("s", "", "a", "u", 0, "sau"),
    ("m", "", "i", "u", 5, "mịu"), ("t", "", "ư", "", 2, "từ")
]
for (onset, medial, nucleus, coda, tone, expected) in cases {
    expect(render(onset, medial, nucleus, coda, tone) == expected, "Spelling: \(expected)")
}

// The engine applies the renderer during composition, and adds a space only at commit.
var engine = KeyboardEngine(outputType: .vietstandard)
_ = engine.selectComponent(KeyboardEngine.initials.firstIndex(of: "ng")!)
_ = engine.selectComponent(1)
expect(engine.selectComponent(KeyboardEngine.nuclei.firstIndex(of: "iê")!) == .marked("nghiế"), "Nucleus preview uses standard tone and ngh")
expect(engine.selectComponent(KeyboardEngine.finals.firstIndex(of: "ng")!) == .commit("nghiếng "), "Fourth key commits standard text and separator")
_ = engine.selectComponent(11)
_ = engine.selectComponent(1)
_ = engine.selectComponent(0)
expect(engine.backspace() == .marked("m"), "Undo removes the rendered vowel and tone")
expect(engine.cancel() == .cancel, "Cancel resets standard composition")

// Every inventory path must be safe, NFC, and carry exactly the selected tone.
// This verifies encoding and reachability, not dictionary/phonotactic validity.
let toneMarks: Set<UInt32> = [0x301, 0x300, 0x309, 0x303, 0x323]
let expectedMarks: [UInt32?] = [nil, 0x301, 0x300, 0x309, 0x303, 0x323]
for onset in KeyboardEngine.initials {
    for medial in ["", "u", "o"] {
        for nucleus in KeyboardEngine.nuclei {
            for coda in KeyboardEngine.finals {
                for tone in 0..<6 {
                    let word = render(onset, medial, nucleus, coda, tone)
                    let marks = word.decomposedStringWithCanonicalMapping.unicodeScalars.map(\.value).filter { toneMarks.contains($0) }
                    expect(!word.isEmpty && word == word.precomposedStringWithCanonicalMapping &&
                           marks == (expectedMarks[tone].map { [$0] } ?? []),
                           "Invalid Unicode/tone for \(onset)|\(medial)|\(nucleus)|\(coda)|\(tone)")
                }
            }
        }
    }
}
print("Passed \(checks) standard-output checks, including all 95,472 inventory paths.")
