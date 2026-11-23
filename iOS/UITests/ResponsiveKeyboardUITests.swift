import XCTest

final class ResponsiveKeyboardUITests: XCTestCase {
    let app = XCUIApplication()
    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launch()
        XCTAssertTrue(app.buttons["app.settings"].waitForExistence(timeout: 10))
    }
    func configure(_ language: String, completions: Bool = false) {
        app.buttons["app.settings"].tap()
        let choice = app.cells["settings.keyboardLanguage.\(language)"]
        XCTAssertTrue(choice.waitForExistence(timeout: 5))
        choice.tap()
        let completion = app.cells["settings.suggestions"]
        for _ in 0..<5 { if completion.isHittable { break }; app.swipeUp() }
        if (completion.value as? String == "1") != completions { completion.tap() }
        app.navigationBars.buttons["settings.done"].tap()
        XCTAssertTrue(app.buttons["keyboard.space"].waitForExistence(timeout: 5))
        app.buttons["practice.clear"].tap()
    }
    var text: String { app.textViews["practice.editor"].value as? String ?? "" }
    func letters(_ text: String) { for letter in text { app.buttons["key.\(letter)"].tap() } }
    func testSuggestionsDoNotOverlapKeys() {
        configure("vietnamese", completions: true)
        letters("m")
        app.buttons["keyboard.backspace"].tap()
        let bar = app.otherElements["suggestion.bar"]
        XCTAssertTrue(app.buttons["suggestion.0"].waitForExistence(timeout: 5))
        func checkSeparation(_ firstKey: XCUIElement) {
            XCTAssertLessThanOrEqual(bar.frame.maxY, firstKey.frame.minY,
                                     "The suggestion strip must remain entirely above the first key row")
            XCTAssertLessThanOrEqual(firstKey.frame.maxY, app.buttons["key.a"].frame.minY,
                                     "Key rows must not overlap after resizing")
        }
        checkSeparation(app.buttons["key.q"])
        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }
        checkSeparation(app.buttons["key.q"])
        app.buttons["keyboard.numbers"].tap()
        XCTAssertLessThanOrEqual(bar.frame.maxY, app.buttons["symbol.0"].frame.minY,
                                 "The suggestion strip must also stay above the symbol page")
        app.buttons["keyboard.numbers"].tap()
        XCUIDevice.shared.orientation = .portrait
        checkSeparation(app.buttons["key.q"])
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Suggestions above keys"; screenshot.lifetime = .keepAlways; add(screenshot)
    }
    func testExtensionSuggestionsStayAboveKeys() {
        configure("vietnamese", completions: true)
        app.segmentedControls["practice.source"].buttons.element(boundBy: 1).tap()
        for _ in 0..<6 {
            if app.staticTexts["Quickly Change Keyboards"].exists && app.buttons["Continue"].exists { app.buttons["Continue"].tap() }
            if app.buttons["key.m"].waitForExistence(timeout: 1) { break }
            let globe = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Next keyboard' OR label CONTAINS[c] 'Switch keyboard'")).firstMatch
            XCTAssertTrue(globe.waitForExistence(timeout: 5), app.debugDescription)
            globe.tap()
        }
        XCTAssertTrue(app.buttons["key.m"].waitForExistence(timeout: 5))
        letters("m")
        app.buttons["keyboard.backspace"].tap()
        XCTAssertTrue(app.buttons["suggestion.0"].waitForExistence(timeout: 5))
        let bar = app.otherElements["suggestion.bar"]
        XCTAssertLessThanOrEqual(bar.frame.maxY, app.buttons["key.q"].frame.minY)
        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }
        XCTAssertLessThanOrEqual(bar.frame.maxY, app.buttons["key.q"].frame.minY)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "System keyboard suggestions in landscape"; screenshot.lifetime = .keepAlways; add(screenshot)
    }
    func testGuttersAndSlidingCommitOnce() {
        configure("vietnamese")
        let m = app.buttons["key.m"]
        m.coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 0.5)).withOffset(CGVector(dx: 1, dy: 0)).tap()
        XCTAssertEqual(text, "m", "A tap in a visual key gutter must select its nearest key")
        app.buttons["practice.clear"].tap()
        m.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(forDuration: 0.4,
            thenDragTo: app.buttons["key.x"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)))
        XCTAssertEqual(text, "x", "Sliding must commit only the key under the finger at release")
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Neutral keys and gapless touch layout"; screenshot.lifetime = .keepAlways; add(screenshot)
    }
    func testChineseConversionAndLanguageFiltering() {
        configure("chinese")
        letters("nihk")
        app.buttons["keyboard.space"].tap()
        XCTAssertEqual(text, "你好", "Chinese conversion must work with completion disabled")
        app.buttons["app.settings"].tap()
        app.swipeDown()
        XCTAssertTrue(app.cells["settings.input.chinese"].exists)
        XCTAssertFalse(app.cells["settings.input.sieuviet"].exists)
        XCTAssertTrue(app.cells["settings.output.Simplified Chinese"].exists)
        app.navigationBars.buttons["settings.done"].tap()
    }
    func testSpaceTrackpadMovesVertically() {
        configure("english")
        letters("abcdef")
        app.buttons["keyboard.return"].tap()
        letters("ghijkl")
        let space = app.buttons["keyboard.space"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        space.press(forDuration: 0.5, thenDragTo: space.withOffset(CGVector(dx: 0, dy: -35)))
        letters("a")
        XCTAssertEqual(text, "abcdefa\nghijkl", "Dragging space up must move the caret to the previous visual line")
        space.press(forDuration: 0.5, thenDragTo: space.withOffset(CGVector(dx: 0, dy: 35)))
        letters("b")
        XCTAssertEqual(text, "abcdefa\nghijklb", "Dragging space down must return to the next visual line")
    }
}
