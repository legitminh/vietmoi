import XCTest
@testable import SieuvietCore

final class EngineTests: XCTestCase {
    private func usage(_ character: Character) -> Int32 {
        character == ";" ? 0x33 : Int32(character.asciiValue! - 97 + 4)
    }

    private func type(_ keys: String, output: SieuvietEngine.Output) throws -> SieuvietEngine.Effect {
        let engine = SieuvietEngine(output: output)
        for key in keys { try engine.dispatch(.key, argument: usage(key)) }
        return engine.effect
    }

    func testReviewedWordsInBothOutputs() throws {
        for (keys, sieuviet, standard) in [
            ("msed", "má ", "má "), ("mlnd", "muốn ", "muốn "),
            ("rwos", "răo ", "rau "), ("frej", "fở ", "phở "),
            ("xaqs", "xoong ", "xoong "), ("imoj", "khwỉo ", "khuỷu ")
        ] {
            for (output, expected) in [(SieuvietEngine.Output.sieuviet, sieuviet), (.quocNgu, standard)] {
                let effect = try type(keys, output: output)
                XCTAssertEqual(effect.kind, .commit, keys)
                XCTAssertEqual(effect.text, expected, keys)
            }
        }
    }

    func testPhasePreviewsAndRoundUndo() throws {
        let engine = SieuvietEngine(output: .quocNgu)
        for (key, preview, phase): (Character, String, Int32) in [("q", "ng", 1), ("e", "ngiê", 2), ("q", "ngiêng", 3)] {
            let effect = try engine.dispatch(.key, argument: usage(key))
            XCTAssertEqual(effect.kind, .marked)
            XCTAssertEqual(effect.text, preview)
            XCTAssertEqual(engine.preview, preview)
            XCTAssertEqual(engine.phase, phase)
        }
        XCTAssertEqual(try engine.dispatch(.backspace).text, "ngiê")
        XCTAssertEqual(try engine.dispatch(.backspace).text, "ng")
        XCTAssertEqual(try engine.dispatch(.backspace).kind, .cancel)
        XCTAssertEqual(engine.phase, 0)
        XCTAssertEqual(engine.preview, "")
    }

    func testPartialBoundariesModeAndUnavailableKeys() throws {
        let engine = SieuvietEngine(output: .quocNgu)
        try engine.dispatch(.key, argument: usage("m"))
        XCTAssertEqual(try engine.dispatch(.space).text, "m ")
        try engine.dispatch(.key, argument: usage("m"))
        XCTAssertEqual(try engine.dispatch(.toggleASCII).text, "m")
        XCTAssertTrue(engine.ascii)
        let effect = engine.effect
        XCTAssertThrowsError(try engine.dispatch(.key, argument: usage("y")))
        XCTAssertEqual(engine.effect, effect)
        try engine.dispatch(.toggleASCII)
        XCTAssertFalse(engine.ascii)
        XCTAssertEqual(try engine.dispatch(.key, argument: usage("a")).kind, .none)
        XCTAssertEqual(engine.phase, 0)
        XCTAssertThrowsError(try engine.dispatch(.key, argument: 0x33))
        XCTAssertThrowsError(try engine.dispatch(.component, argument: -1))
        XCTAssertThrowsError(try engine.dispatch(.component, argument: Int32.max))
        XCTAssertEqual(try engine.dispatch(.key, argument: usage("e")).kind, .marked)
        XCTAssertEqual(engine.preview, "")
        XCTAssertEqual(try engine.dispatch(.space).text, " ", "Empty onset still allows a space")
        XCTAssertEqual(try engine.dispatch(.clear).kind, .deleteCycle, "Host must verify any deletion")
    }

    func testGuideAndInstanceIsolation() throws {
        let first = SieuvietEngine()
        let second = SieuvietEngine(output: .quocNgu)
        XCTAssertEqual(first.label(forHIDUsage: usage("e")), "∅")
        XCTAssertNil(first.label(forHIDUsage: 0x33))
        XCTAssertNil(first.label(forHIDUsage: Int32.max))
        try first.dispatch(.key, argument: usage("m"))
        XCTAssertEqual(first.label(forHIDUsage: usage("a")), "oo")
        XCTAssertEqual(second.phase, 0)
        XCTAssertEqual(second.preview, "")
        try first.dispatch(.toggleASCII)
        XCTAssertFalse(second.ascii)
    }

    func testSharedGuideModelAndSymbols() throws {
        let engine = SieuvietEngine()
        func state(_ input: Int32) throws -> [String: Any] {
            try JSONSerialization.jsonObject(with: XCTUnwrap(engine.stateJSON(inputType: input)).data(using: .utf8)!) as! [String: Any]
        }
        let ascii = try state(0)
        let rows = try XCTUnwrap(ascii["rows"] as? [[[String: Any]]])
        XCTAssertEqual(rows.map(\.count), [10, 10, 8])
        XCTAssertEqual(rows[0][0]["id"] as? String, "q")
        XCTAssertEqual(rows[1][9]["id"] as? String, ";")
        XCTAssertEqual(rows[2][0]["id"] as? String, "mode")
        XCTAssertEqual(rows[2][7]["argument"] as? Int, 0x10, "m uses HID, not Mac keycode 46")
        XCTAssertEqual((try state(1)["rows"] as? [[[String: Any]]])?.map(\.count), [8, 8, 8, 8])
        XCTAssertEqual(ascii["symbolPages"] as? [[[String]]], TouchKeyboardSymbols.pages.map { $0.map { $0.map(String.init) } })
        XCTAssertNil(engine.stateJSON(inputType: -1))
        try engine.dispatch(.key, argument: usage("m"))
        XCTAssertEqual(try state(0)["preview"] as? String, "m")
    }

    func testSharedShiftGesturesDoNotMutateCompositionBeforeDispatch() throws {
        let engine = SieuvietEngine()
        try engine.dispatch(.key, argument: usage("m"))
        XCTAssertFalse(engine.observeHardwareKey(usage: 0xe1, down: true, time: 0, otherModifiers: false))
        XCTAssertTrue(engine.observeHardwareKey(usage: 0xe1, down: false, time: 0.1, otherModifiers: false))
        XCTAssertFalse(engine.ascii)
        XCTAssertEqual(engine.preview, "m")
        try engine.dispatch(.toggleASCII)
        XCTAssertEqual(engine.effect.text, "m")
        XCTAssertTrue(engine.ascii)
        XCTAssertFalse(engine.observeHardwareKey(usage: 0xe1, down: true, time: 1, otherModifiers: false))
        XCTAssertFalse(engine.observeHardwareKey(usage: 0xe1, down: false, time: 1.3, otherModifiers: false))
        _ = engine.observeHardwareKey(usage: 0xe1, down: true, time: 2, otherModifiers: false)
        _ = engine.observeHardwareKey(usage: 4, down: true, time: 2.01, otherModifiers: false)
        _ = engine.observeHardwareKey(usage: 4, down: false, time: 2.02, otherModifiers: false)
        XCTAssertFalse(engine.observeHardwareKey(usage: 0xe1, down: false, time: 2.1, otherModifiers: false))
        _ = engine.observeHardwareKey(usage: 0xe5, down: true, time: 3, otherModifiers: false)
        _ = engine.observeHardwareKey(usage: 0xe1, down: true, time: 3.01, otherModifiers: false)
        XCTAssertFalse(engine.observeHardwareKey(usage: 0xe1, down: false, time: 3.1, otherModifiers: false))
    }

    func testEveryConstructionThroughPortableBoundary() throws {
        let inventory = VietnamesePhoneticInventory.sieuviet
        var paths = 0
        for output in [SieuvietEngine.Output.sieuviet, .quocNgu] {
            let portable = SieuvietEngine(output: output)
            var reference = KeyboardEngine(outputType: output == .quocNgu ? .quocNgu : .sieuviet)
            for initial in inventory.initials.indices {
                for vowel in inventory.vowelAtoms.indices {
                    for final in inventory.finals.indices {
                        for tone in VietnameseTone.allCases {
                            for index in [initial, vowel, final, tone.rawValue] {
                                let expected = reference.selectComponent(index)
                                let actual = try portable.dispatch(.component, argument: Int32(index))
                                switch expected {
                                case .marked(let text):
                                    XCTAssertEqual(actual.kind, .marked)
                                    XCTAssertEqual(actual.text, text)
                                case .commit(let text):
                                    XCTAssertEqual(actual.kind, .commit)
                                    XCTAssertEqual(actual.text, text)
                                    XCTAssertEqual(text, text.precomposedStringWithCanonicalMapping)
                                default: XCTFail("Unexpected effect for valid construction")
                                }
                                XCTAssertEqual(portable.preview, reference.preview)
                                XCTAssertEqual(portable.phase, Int32(reference.phase.rawValue))
                            }
                            paths += 1
                        }
                    }
                }
            }
        }
        XCTAssertEqual(paths, 79_200)
    }

    func testDesktopRoutingUsesSharedLayouts() throws {
        let engine = SieuvietEngine(output: .quocNgu)
        XCTAssertFalse(engine.wantsKey(usage: 0x33, inputType: 0))
        XCTAssertFalse(engine.wantsKey(usage: 4, inputType: -1))
        XCTAssertThrowsError(try engine.dispatchKey(usage: 4, inputType: 2))
        XCTAssertThrowsError(try engine.dispatchKey(usage: 0x33, inputType: 0))
        for (hid, expected): (Int32, String) in [(usage("r"), "m"), (0x20, "ma"), (0x1e, "ma"), (0x1f, "má ")] {
            XCTAssertTrue(engine.wantsKey(usage: hid, inputType: 1))
            XCTAssertEqual(try engine.dispatchKey(usage: hid, inputType: 1).text, expected)
        }
        try engine.dispatchKey(usage: usage("m"), inputType: 0)
        let guide = try XCTUnwrap(engine.guideText(inputType: 0))
        XCTAssertTrue(guide.contains("m: wi"))
        XCTAssertTrue(guide.contains("n: wê"))
        XCTAssertFalse(guide.contains("wô"))
        XCTAssertNil(engine.guideText(inputType: -1))
        try engine.dispatch(.toggleASCII)
        XCTAssertFalse(engine.wantsKey(usage: usage("m"), inputType: 0))
        XCTAssertFalse(engine.wantsKey(usage: 0x1e, inputType: 1))
    }
}
