import XCTest

final class KeyboardUITests: XCTestCase {
    var app: XCUIApplication!
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["app.settings"].waitForExistence(timeout: 10))
        configure(input: "ascii+", output: "sieuviet")
        selectVietnameseMode()
    }
    func configure(input: String = "ascii+", output: String) {
        app.buttons["app.settings"].tap()
        XCTAssertTrue(app.cells["settings.input.\(input)"].waitForExistence(timeout: 5))
        app.cells["settings.input.\(input)"].tap()
        app.cells["settings.output.\(output)"].tap()
        app.navigationBars.buttons["settings.done"].tap()
        XCTAssertTrue(app.buttons["keyboard.space"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.segmentedControls["keyboard.output"].exists)
        XCTAssertFalse(app.staticTexts["keyboard.phase"].exists)
        XCTAssertFalse(app.staticTexts["keyboard.preview"].exists)
        let surface = app.otherElements["keyboard.surface"].firstMatch
        XCTAssertTrue(surface.exists)
        XCTAssertLessThan(surface.frame.maxY - app.buttons["keyboard.space"].frame.maxY, 7,
                          "Keys must sit at the bottom of the custom keyboard surface")
    }
    func selectVietnameseMode() {
        let toggle = app.buttons["key.Shift"]
        if toggle.label.contains("Switch to Vietnamese") || toggle.label.contains("Chuyển sang tiếng Việt") { toggle.tap() }
    }
    func testModePersistsAfterRelaunch() {
        app.buttons["key.Shift"].tap()
        tap("hello")
        XCTAssertEqual(text, "hello")
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["key.Shift"].waitForExistence(timeout: 10))
        tap("world")
        XCTAssertEqual(text, "world", "A recreated keyboard must retain literal ASCII mode")
        app.buttons["key.Shift"].tap()
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["key.m"].waitForExistence(timeout: 10))
        tap("msed")
        XCTAssertEqual(text, "má ", "Switching back to Vietnamese must persist too")
    }
    func tap(_ keys: String) { for character in keys { app.buttons["key.\(character)"].tap() } }
    var text: String { app.textViews["practice.editor"].value as? String ?? "" }
    func clear() { app.buttons["practice.clear"].tap() }
    func testInterfaceLanguagePersistsWithoutChangingOutput() {
        app.buttons["app.settings"].tap()
        let english = app.cells["settings.language.en"]
        for _ in 0..<3 { if english.isHittable { break }; app.swipeUp() }
        english.tap()
        XCTAssertTrue(app.navigationBars["Keyboard settings"].exists)
        app.navigationBars.buttons["settings.done"].tap()
        XCTAssertEqual(app.buttons["keyboard.space"].label, "space")
        app.terminate(); app.launch()
        XCTAssertEqual(app.buttons["keyboard.space"].label, "space")
        tap("msed"); XCTAssertEqual(text, "má ")
        app.buttons["app.settings"].tap()
        let vietnamese = app.cells["settings.language.vi"]
        for _ in 0..<3 { if vietnamese.isHittable { break }; app.swipeUp() }
        vietnamese.tap()
        XCTAssertTrue(app.navigationBars["Cài đặt bàn phím"].exists)
        app.navigationBars.buttons["settings.done"].tap()
        XCTAssertEqual(app.buttons["keyboard.space"].label, "dấu cách")
    }
    func testBothOutputsAndEditing() {
        configure(output: "sieuviet")
        tap("rwos")
        XCTAssertEqual(text, "răo ")
        clear()
        configure(output: "quốc ngữ")
        tap("qe")
        XCTAssertEqual(text, "ngiê")
        tap("qs")
        XCTAssertEqual(text, "nghiêng ")
        tap("frejimojjles")
        XCTAssertEqual(text, "nghiêng phở khuỷu chua ")
        clear()
        tap("m")
        app.buttons["keyboard.backspace"].tap()
        XCTAssertEqual(text, "")
        tap("m")
        app.buttons["keyboard.space"].tap()
        XCTAssertEqual(text, "m ")
        tap("m")
        app.buttons["key.Shift"].tap()
        tap("y")
        XCTAssertEqual(text, "m my")
        app.buttons["keyboard.numbers"].tap()
        app.buttons["symbol.0"].tap()
        app.buttons["keyboard.backspace"].tap()
        XCTAssertEqual(text, "m my")
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "iPhone keyboard"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }
    func testTouchModifiersAndDirectSymbolPanels() {
        let shift = app.buttons["key.Shift"]
        XCTAssertFalse(app.buttons["keyboard.caps"].exists)
        XCTAssertTrue(app.buttons["keyboard.moreSymbols"].exists)
        shift.doubleTap()
        tap("w"); app.buttons["keyboard.space"].tap()
        XCTAssertEqual(text, "NH ", "Caps Lock capitalizes both letters of a digraph")
        shift.tap()
        tap("w"); app.buttons["keyboard.space"].tap()
        XCTAssertEqual(text, "NH nh ", "Exiting Caps Lock restores ordinary digraphs")
        clear()
        shift.press(forDuration: 0.5)
        tap("msedmsed")
        XCTAssertEqual(text, "má má ", "Releasing an unused Shift hold must leave the next atom lowercase")
        clear()
        shift.tap()
        shift.press(forDuration: 0.5)
        tap("ab")
        XCTAssertEqual(text, "ab")
        shift.doubleTap()
        tap("cd")
        XCTAssertEqual(text, "abCD")
        shift.tap()
        tap("e")
        XCTAssertEqual(text, "abCDe", "Unlocking Caps Lock must stay in ASCII")
        app.buttons["keyboard.moreSymbols"].tap()
        app.buttons["symbol.0"].tap()
        let afterSymbol = text
        app.buttons["keyboard.moreSymbols"].tap()
        XCTAssertTrue(app.buttons["key.a"].isHittable)
        app.buttons["keyboard.numbers"].press(forDuration: 0.5)
        XCTAssertTrue(app.buttons["key.a"].isHittable, "Releasing a temporary number hold restores letters")
        app.buttons["keyboard.moreSymbols"].press(forDuration: 0.5)
        XCTAssertTrue(app.buttons["key.a"].isHittable, "Releasing a temporary symbol hold restores letters")
        tap("f")
        XCTAssertEqual(text, afterSymbol + "f")
        app.buttons["keyboard.numbers"].tap()
        app.buttons["symbol.0"].tap()
        XCTAssertTrue(text.hasSuffix("1"))
        app.buttons["keyboard.numbers"].tap()
        app.buttons["keyboard.return"].tap()
        XCTAssertTrue(text.hasSuffix("1\n"))
        selectVietnameseMode()
    }
    func testAlignedLayoutAndLandscape() {
        XCTAssertEqual(app.buttons["key.q"].frame.minX, app.buttons["key.a"].frame.minX, accuracy: 1)
        XCTAssertEqual(app.buttons["key.p"].frame.minX, app.buttons["key.;"].frame.minX, accuracy: 1)
        XCTAssertEqual(app.buttons["key.q"].frame.minX, app.buttons["key.Shift"].frame.minX, accuracy: 1)
        configure(output: "quốc ngữ")
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(app.buttons["keyboard.space"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["keyboard.space"].isHittable)
        tap("msed")
        XCTAssertEqual(text, "má ")
        XCUIDevice.shared.orientation = .portrait
    }
}

extension KeyboardUITests {
    func testSystemKeyboardExtension() {
        let settings = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
        settings.launch()
        // Settings persists its navigation state between launches. Return to root.
        for _ in 0..<5 {
            if settings.buttons["General"].exists { break }
            let back = settings.navigationBars.buttons.firstMatch
            if back.exists { back.tap() } else { break }
        }
        if !settings.buttons["General"].exists { settings.swipeUp() }
        XCTAssertTrue(settings.buttons["General"].waitForExistence(timeout: 5), settings.debugDescription)
        settings.buttons["General"].tap()
        if !settings.buttons["Keyboard"].exists { settings.swipeUp() }
        XCTAssertTrue(settings.buttons["Keyboard"].waitForExistence(timeout: 5), settings.debugDescription)
        settings.buttons["Keyboard"].tap()
        XCTAssertTrue(settings.buttons["KEYBOARDS"].waitForExistence(timeout: 5), settings.debugDescription)
        settings.buttons["KEYBOARDS"].tap()
        let enabled = settings.cells.matching(NSPredicate(format: "identifier CONTAINS 'com.minh.sieuviet.ios' OR label == 'siêu việt'")).firstMatch
        if !enabled.exists {
            let addKeyboard = settings.buttons["AddNewKeyboard"]
            XCTAssertTrue(addKeyboard.waitForExistence(timeout: 5), settings.debugDescription)
            addKeyboard.tap()
            let viet = settings.cells["com.minh.sieuviet.ios"]
            XCTAssertTrue(viet.waitForExistence(timeout: 5), settings.debugDescription)
            for _ in 0..<8 { if viet.isHittable { break }; settings.tables.firstMatch.swipeUp() }
            XCTAssertTrue(viet.isHittable, settings.debugDescription)
            viet.tap()
        }
        app.activate()
        app.segmentedControls["practice.source"].buttons.element(boundBy: 1).tap()
        // The test helper selects the enabled extension in simulator preferences.
        // Fall back to the system globe when testing a different simulator.
        for _ in 0..<45 {
            if app.staticTexts["Quickly Change Keyboards"].exists && app.buttons["Continue"].exists { app.buttons["Continue"].tap() }
            if app.buttons["key.m"].waitForExistence(timeout: 0.7) { break }
            let globe = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Next keyboard' OR label CONTAINS[c] 'Switch keyboard'")).firstMatch
            XCTAssertTrue(globe.waitForExistence(timeout: 5), app.debugDescription)
            globe.tap()
        }
        XCTAssertTrue(app.buttons["key.m"].waitForExistence(timeout: 10), app.debugDescription)
        configure(output: "quốc ngữ")
        selectVietnameseMode()
        tap("frejrwos")
        XCTAssertEqual(text, "phở rau ")
        configure(output: "sieuviet")
        tap("rwos")
        XCTAssertEqual(text, "phở rau răo ", "The extension reads an output changed only in the app")
        configure(input: "grid4x8", output: "quốc ngữ")
        tap("r312")
        XCTAssertEqual(text, "phở rau răo má ", "The extension reads the app's grid input choice")
        tap("m")
        XCTAssertEqual(text, "phở rau răo ", "Grid Clear deletes a verified completed word")
        configure(output: "quốc ngữ")
        tap("m")
        app.buttons["keyboard.backspace"].tap()
        XCTAssertEqual(text, "phở rau răo ")
        tap("m")
        app.buttons["key.Shift"].tap()
        tap("y")
        XCTAssertEqual(text, "phở rau răo my")
        XCTAssertLessThan(app.frame.maxY - app.buttons["keyboard.space"].frame.maxY, 140,
                          "Extension height must not leave an empty panel below the keys")
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "System keyboard extension"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        configure(output: "quốc ngữ")
        tap("hello")
        XCTAssertEqual(text, "phở rau răo myhello", "Reactivating the extension must preserve ASCII")
        app.terminate(); app.launch()
        XCTAssertTrue(app.segmentedControls["practice.source"].waitForExistence(timeout: 10))
        app.segmentedControls["practice.source"].buttons.element(boundBy: 1).tap()
        XCTAssertTrue(app.buttons["key.Shift"].waitForExistence(timeout: 10))
        tap("world")
        XCTAssertEqual(text, "world", "The system keyboard must restore ASCII in a new host editor")
        selectVietnameseMode()
    }
}

#if !targetEnvironment(simulator)
extension KeyboardUITests {
    func testDeviceConfigurationTransfer() {
        configure(output: "quốc ngữ")
        app.segmentedControls["practice.source"].buttons.element(boundBy: 1).tap()
        XCTAssertTrue(app.buttons["key.m"].waitForExistence(timeout: 10), "Select the installed siêu việt keyboard with the system globe first")
        selectVietnameseMode()
        tap("frejrwos")
        XCTAssertEqual(text, "phở rau ")
        configure(output: "sieuviet")
        tap("rwos")
        XCTAssertEqual(text, "phở rau răo ")
        configure(input: "grid4x8", output: "quốc ngữ")
        tap("r312")
        XCTAssertEqual(text, "phở rau răo má ")
        configure(output: "quốc ngữ")
    }
}
#endif
