import Foundation

@MainActor final class TestMobileDocument: MobileTextDocument {
    var identifier = "first"
    var text = ""
    var selection = NSRange(location: 0, length: 0)
    var mark: NSRange?
    var delayedBefore: String?
    var beforeInput: String? { delayedBefore ?? (text as NSString).substring(to: selection.location) }
    var afterInput: String? { (text as NSString).substring(from: NSMaxRange(selection)) }
    var selectedText: String? { (text as NSString).substring(with: selection) }
    func setMarkedText(_ value: String) {
        let target = mark ?? selection
        text = (text as NSString).replacingCharacters(in: target, with: value)
        mark = NSRange(location: target.location, length: value.utf16.count)
        selection = NSRange(location: target.location + value.utf16.count, length: 0)
    }
    func unmarkText() { mark = nil }
    func insertText(_ value: String) {
        text = (text as NSString).replacingCharacters(in: selection, with: value)
        selection = NSRange(location: selection.location + value.utf16.count, length: 0)
    }
    func deleteBackward() {
        if selection.length > 0 { insertText(""); return }
        guard selection.location > 0 else { return }
        let before = (text as NSString).substring(to: selection.location)
        let length = String(before.last!).utf16.count
        selection = NSRange(location: selection.location - length, length: length)
        insertText("")
    }
}

@main @MainActor struct MobileTests {
    static var checks = 0
    static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        checks += 1
        if !condition() { fatalError(message) }
    }
    static func key(_ label: String) -> ASCIIKey {
        if label == "Shift" { return ASCIIKey(label: label, keyCode: 56) }
        return ASCIIKey(label: label, keyCode: ASCIIKeyboardLayout.keyCodesByLabel[label]!)
    }
    static func type(_ text: String, _ session: MobileInputSession) {
        for char in text { session.press(key(String(char))) }
    }
    static func main() {
        let suite = "com.minh.viet.mobile.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let legacy = Data(#"{"input":"grid4x8","output":"quốc ngữ"}"#.utf8)
        let migrated = try! JSONDecoder().decode(MobileKeyboardSettings.self, from: legacy)
        expect(migrated.language == "vi" && migrated.input == .grid4x8 && migrated.output == .quocNgu, "Old snapshots default to Vietnamese without losing input/output")
        let english = MobileKeyboardSettings(input: .grid4x8, output: .quocNgu, language: "en")
        expect(try! JSONDecoder().decode(MobileKeyboardSettings.self, from: JSONEncoder().encode(english)) == english, "English persists alongside input/output")
        expect(MobileKeyboardSettings(language: "unknown").supported.language == "vi", "Unsupported language falls back to Vietnamese")
        let doc = TestMobileDocument()
        var settings = MobileKeyboardSettings.standard
        let session = MobileInputSession(document: doc, defaults: defaults, settingsProvider: { settings })
        func setOutput(_ output: OutputType) {
            session.finish()
            settings.output = output
            session.reloadSettings()
        }
        expect(!session.ascii, "A fresh installation starts in Vietnamese mode")
        type("m", session)
        expect(doc.text == "m" && session.pending, "Initial appears as marked text")
        session.backspace()
        expect(doc.text.isEmpty && !session.pending && doc.mark == nil, "Backspace removes the initial")
        type("m", session); session.space()
        expect(doc.text == "m " && !session.pending, "Space preserves an abbreviation")
        type("m", session); session.press(key("Shift")); type("y", session)
        expect(doc.text == "m my" && session.ascii, "ASCII switching preserves a partial initial")
        session.press(key("q"), letterCase: .shifted)
        expect(doc.text == "m myQ", "ASCII retains chosen case")
        session.press(key("Shift"))
        session.space()
        type("rwos", session)
        expect(doc.text == "m myQ răo " && session.completedBasis?.final == "o", "Sieuviet uses the shared final-o atom")
        setOutput(.quocNgu)
        type("qe", session)
        expect(doc.text.hasSuffix("ngiê") && session.preview == "ngiê", "Quốc ngữ draft stays phonetic")
        type("qs", session)
        expect(doc.text.hasSuffix("nghiêng ") && session.completedBasis?.coreVowel == "iê", "Completion renders quốc ngữ and retains its basis")
        type("frej", session)
        expect(doc.text.hasSuffix("phở "), "Expanded ph initial replaces the mark once")
        type("imoj", session)
        expect(doc.text.hasSuffix("khuỷu "), "Both glides survive quốc ngữ translation")
        type("jl", session); session.space()
        expect(doc.text.hasSuffix("chuô "), "Early Space does not translate an unfinished word")
        type("m", session); session.literal(",")
        expect(doc.text.hasSuffix("m,"), "Punctuation preserves the pending prefix")
        session.newline()
        expect(doc.text.hasSuffix("m,\n"), "Return flushes then inserts a newline")
        let safe = doc.text
        session.literal("\u{8}")
        expect(doc.text == safe, "Control payloads cannot be inserted")
        type("j", session)
        expect(session.preview == "ch", "Multi-character initial remains one atom")
        session.backspace()
        expect(doc.text == safe, "Backspace removes a whole ch initial")
        doc.selection = NSRange(location: 0, length: 1)
        session.documentDidChange()
        type("m", session); session.backspace()
        expect(doc.text == safe, "Undo restores text replaced by a partial initial")
        doc.selection = NSRange(location: doc.text.utf16.count, length: 0)
        session.documentDidChange()
        type("m", session)
        doc.unmarkText(); doc.selection = NSRange(location: 0, length: 0)
        session.documentDidChange()
        type("bses", session)
        expect(doc.text.hasPrefix("ba ") && doc.text.hasSuffix("m"), "External caret movement preserves the old preview and starts a new word")
        type("m", session)
        doc.identifier = "other"; doc.text = "box"; doc.selection = NSRange(location: 3, length: 0); doc.mark = nil
        session.documentDidChange(); session.backspace()
        expect(doc.text == "bo" && !session.pending, "A new text field never receives the previous field's pending word")
        type("m", session); session.finish()
        expect(doc.text == "bom" && doc.mark == nil, "Dismissal preserves a partial word")
        session.backspace()
        expect(doc.text == "bo", "Idle Backspace uses native deletion")
        doc.text = ""; doc.selection = NSRange(location: 0, length: 0); session.documentDidChange()
        doc.delayedBefore = ""
        type("m", session)
        doc.delayedBefore = nil
        session.documentDidChange(); session.backspace()
        expect(doc.text.isEmpty, "Delayed marked-caret acknowledgement does not lose the initial")
        type("e", session); session.space()
        expect(doc.text == " ", "Empty optional initial followed by Space inserts exactly one space")
        type("m", session); setOutput(.sieuviet)
        expect(doc.text == " m" && !session.pending, "Output change keeps unfinished text")
        setOutput(.quocNgu)
        let restored = MobileInputSession(document: doc, defaults: defaults, settingsProvider: { settings })
        expect(restored.output == .quocNgu, "Sessions read the same app-owned output setting")
        doc.text = ""; doc.selection = NSRange(location: 0, length: 0); session.documentDidChange()
        settings = MobileKeyboardSettings(input: .asciiPlus, output: .sieuviet)
        session.reloadSettings()
        type("rw", session)
        settings.output = .quocNgu
        session.reloadSettings()
        expect(session.output == .sieuviet && session.pending, "A settings update cannot change a word midway through construction")
        type("os", session)
        expect(doc.text == "răo " && session.output == .quocNgu, "New output settings apply after the current word completes")
        settings.input = .grid4x8
        session.reloadSettings()
        expect(session.rows.count == 4 && session.rows.allSatisfy { $0.count == 8 }, "Grid input uses four shared eight-key rows")
        type("r312", session)
        expect(doc.text == "răo má ", "Grid input commits through the same quốc ngữ renderer")
        type("m", session)
        expect(doc.text == "răo ", "Grid Clear removes the most recent verified commit")
        type("r3", session)
        session.backspace()
        expect(session.preview == "m", "Grid Backspace undoes one round")
        session.space()
        expect(doc.text == "răo m ", "Grid also preserves abbreviations")
        session.press(key("Shift"))
        expect(session.rows.count == 3 && session.rows[0].count == 10, "Literal ASCII exposes the whole letter keyboard even when grid input is selected")
        type("pol", session)
        expect(doc.text == "răo m pol", "ASCII retains letters outside the grid's physical block")
        settings.input = .telex
        let unsupported = MobileInputSession(document: doc, defaults: defaults, settingsProvider: { settings })
        expect(unsupported.input == .asciiPlus, "An unavailable saved input type falls back to a working layout")
        // Recreate the session and UserDefaults object, as iOS does for a new
        // host/controller. Only mode should survive, never composition or text.
        let modeDefaults = UserDefaults(suiteName: suite)!
        let otherField = TestMobileDocument()
        otherField.identifier = "mode-second-field"
        let remembered = MobileInputSession(document: otherField, defaults: modeDefaults)
        expect(remembered.ascii && !remembered.pending && remembered.completedBasis == nil,
               "A recreated keyboard restores ASCII without carrying any composition")
        type("hello", remembered)
        expect(otherField.text == "hello", "A different text field starts with literal ASCII")
        otherField.identifier = "mode-third-field"
        otherField.text = ""; otherField.selection = NSRange(location: 0, length: 0)
        remembered.documentDidChange(); remembered.finish(); remembered.reloadSettings()
        expect(remembered.ascii, "Field changes, dismissal and settings reload preserve ASCII")
        remembered.press(key("Shift"))
        let vietnamese = MobileInputSession(document: otherField, defaults: UserDefaults(suiteName: suite)!)
        expect(!vietnamese.ascii, "Switching back to Vietnamese also persists across recreation")
        type("m", vietnamese)
        vietnamese.press(key("Shift"))
        expect(otherField.text == "m" && vietnamese.ascii && !vietnamese.pending,
               "Persisting a mode change still commits partial Vietnamese text exactly once")
        let afterPartial = MobileInputSession(document: TestMobileDocument(), defaults: defaults)
        expect(afterPartial.ascii && !afterPartial.pending && afterPartial.preview.isEmpty,
               "Reopening after a partial word restores only the selected mode")
        var shift = MobileShiftState()
        shift.begin(at: 0); shift.end(at: 0.05)
        expect(shift.pendingTap != nil && !shift.uppercase, "A short tap switches mode without arming uppercase")
        expect(shift.takeModeTap() && !shift.takeModeTap(), "A single tap switches mode exactly once")
        shift.begin(at: 1); shift.end(at: 1.5)
        expect(shift.typed() == .lowercase && shift.typed() == .lowercase, "Releasing an unused hold leaves subsequent keys lowercase")
        shift.begin(at: 2)
        expect(shift.typed() == .shifted && shift.typed() == .shifted, "Every key typed during a hold uses initial capitalization")
        shift.end(at: 2.1)
        expect(!shift.takeModeTap() && shift.typed() == .lowercase, "Releasing a short chord immediately returns to lowercase without switching mode")
        shift.begin(at: 3); shift.keyBegan(); shift.end(at: 3.5)
        expect(shift.typed() == .lowercase && shift.typed() == .lowercase, "A letter released after Shift is unheld uses lowercase")
        shift.begin(at: 4); shift.end(at: 4.05)
        expect(shift.takeModeTap(), "The first tap applies mode switching immediately")
        shift.begin(at: 4.15); shift.end(at: 4.2)
        expect(shift.capsLock && shift.takeModeTap() && shift.typed() == .capsLock && shift.typed() == .capsLock, "The second tap restores the original mode and locks uppercase")
        shift.begin(at: 5); shift.end(at: 5.05)
        expect(!shift.capsLock && !shift.takeModeTap() && shift.typed() == .lowercase, "A tap exits Caps Lock without changing mode")
        shift.begin(at: 6); shift.cancelHold()
        expect(!shift.uppercase && !shift.takeModeTap(), "Cancelled touches cannot leave Shift stuck")
        shift.begin(at: 7); shift.end(at: 7.05)
        expect(shift.takeModeTap(), "Mode is saved before a subsequent hold")
        shift.begin(at: 7.15); shift.end(at: 7.7)
        expect(!shift.takeModeTap() && shift.typed() == .lowercase && shift.typed() == .lowercase, "A hold after a tap keeps the selected mode and returns to lowercase on release")
        shift.begin(at: 8); shift.end(at: 8.05); _ = shift.takeModeTap()
        shift.keyBegan()
        shift.begin(at: 8.15); shift.end(at: 8.2)
        expect(!shift.capsLock && shift.takeModeTap(), "An intervening editing key breaks the double-tap sequence")
        var panels = MobileSymbolState()
        panels.begin(.numbers, at: 0); panels.end(.numbers, at: 0.05)
        expect(panels.page == .numbers, "Tap 123 opens the number panel")
        panels.begin(.numbers, at: 1); panels.end(.numbers, at: 1.05)
        expect(panels.page == .letters, "Tap 123 again returns to letters")
        panels.begin(.symbols, at: 2)
        expect(panels.page == .symbols, "Holding #+= immediately exposes symbols")
        panels.typed(); panels.typed(); panels.end(.symbols, at: 2.1)
        expect(panels.page == .letters, "A chord restores letters even when shorter than the hold threshold")
        panels.begin(.numbers, at: 3); panels.end(.numbers, at: 3.5)
        expect(panels.page == .letters, "An unused long panel hold also returns to letters")
        panels.begin(.numbers, at: 4); panels.end(.numbers, at: 4.05)
        panels.begin(.symbols, at: 5); panels.typed(); panels.end(.symbols, at: 6)
        expect(panels.page == .numbers, "Temporary symbols restore a previously selected number panel")
        panels.begin(.symbols, at: 7); panels.end(.symbols, at: 7.05)
        expect(panels.page == .symbols, "A direct #+= tap selects symbols from numbers")
        panels.begin(.numbers, at: 8); panels.cancelHold()
        expect(panels.page == .symbols, "Dismissal restores the layout before a temporary hold")
        panels.begin(.numbers, at: 9); panels.end(.numbers, at: 9.05, cancelled: true)
        expect(panels.page == .symbols, "Cancelled panel gestures restore the previous page")
        // Case belongs to the selected phonetic atoms, not their physical keys.
        let caseSuite = suite + ".case"
        let caseDefaults = UserDefaults(suiteName: caseSuite)!
        defer { caseDefaults.removePersistentDomain(forName: caseSuite) }
        let caseDoc = TestMobileDocument()
        let caseSession = MobileInputSession(document: caseDoc, defaults: caseDefaults,
            settingsProvider: { MobileKeyboardSettings(output: .quocNgu) })
        caseSession.press(key("m"), letterCase: .shifted); type("sed", caseSession)
        expect(caseDoc.text == "Má ", "Held Shift capitalizes the Vietnamese initial through tone rendering")
        for letter in "frej" { caseSession.press(key(String(letter)), letterCase: .shifted) }
        expect(caseDoc.text == "Má PhỞ ", "Held Shift capitalizes only the first letter of expanded quốc ngữ atoms")
        caseSession.press(key("q"), letterCase: .shifted); type("eqs", caseSession)
        expect(caseDoc.text == "Má PhỞ Nghiêng ", "Uppercase initial follows the ng-to-ngh spelling rule")
        caseSession.press(key("m")); caseSession.press(key("s"), letterCase: .shifted); type("ed", caseSession)
        expect(caseDoc.text.hasSuffix("mÁ "), "Holding Shift only for the vowel affects only that atom")
        caseSession.press(key("m"), letterCase: .shifted); caseSession.backspace(); type("msed", caseSession)
        expect(caseDoc.text.hasSuffix("má "), "Undoing an uppercase atom also undoes its case")
        caseSession.press(key("j"), letterCase: .shifted); caseSession.space()
        expect(caseDoc.text.hasSuffix("Ch "), "Partial shifted text keeps its case when finished early")
        caseSession.press(key("Shift")); caseSession.press(key("a"), letterCase: .shifted); caseSession.press(key("b"))
        expect(caseDoc.text.hasSuffix("Ch Ab"), "ASCII uppercase is applied without changing lowercase typing")
        expect(MobileLetterCase.shifted.apply("nh") == "Nh" && MobileLetterCase.capsLock.apply("nh") == "NH",
               "Shift capitalizes the first character, while Caps Lock capitalizes every character")
        caseSession.press(key("Shift"))
        caseSession.press(key("w"), letterCase: .shifted); type("sed", caseSession)
        expect(caseDoc.text.hasSuffix("Nhá "), "The nh key produces Nh under held Shift")
        for letter in "wles" { caseSession.press(key(String(letter)), letterCase: .capsLock) }
        expect(caseDoc.text.hasSuffix("NHUA "), "Caps Lock uppercases every character of multi-letter initials and vowels")
        caseSession.press(key("w"), letterCase: .capsLock); caseSession.backspace()
        caseSession.press(key("w"), letterCase: .shifted); caseSession.space()
        expect(caseDoc.text.hasSuffix("Nh "), "Undoing a Caps Lock atom does not leak its casing into a held-Shift atom")
        let rows = ASCIIKeyboardLayout.guideRows
        expect(rows[0].first?.label == "q" && rows[1].first?.label == "a" && rows[2].first?.label == "Shift", "Mac and mobile share aligned columns")
        expect(rows[0].last?.label == "p" && rows[1].last?.label == ";", "Semicolon is below p")
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let snapshot = directory.appendingPathComponent("KeyboardSettings-v1.json")
        var writer: MobileSettingsStore? = MobileSettingsStore(snapshotURL: snapshot, defaults: defaults)
        try! writer!.save(MobileKeyboardSettings(input: .grid4x8, output: .quocNgu))
        writer = nil
        let reader = MobileSettingsStore(snapshotURL: snapshot, defaults: defaults)
        expect(reader.load() == MobileKeyboardSettings(input: .grid4x8, output: .quocNgu), "Keyboard reads saved choices after the app object exits")
        let snapshotKeys = Set(((try! JSONSerialization.jsonObject(with: Data(contentsOf: snapshot))) as! [String: Any]).keys)
        expect(snapshotKeys == ["profiles", "activeID", "language"], "Snapshot contains only the keyboard list, selection and language")
        let reopenedApp = MobileSettingsStore(snapshotURL: snapshot, defaults: defaults)
        try! reopenedApp.save(.standard)
        expect(reader.current == MobileKeyboardSettings(input: .grid4x8, output: .quocNgu), "Typing uses its cached snapshot without polling app settings")
        expect(reader.load() == .standard, "A new activation refreshes the snapshot")
        try! FileManager.default.setAttributes([.posixPermissions: 0o400], ofItemAtPath: snapshot.path)
        expect(reader.load() == .standard, "The keyboard needs only read access to the snapshot")
        try! Data("invalid".utf8).write(to: directory.appendingPathComponent("broken.json"))
        let broken = MobileSettingsStore(snapshotURL: directory.appendingPathComponent("broken.json"), defaults: defaults)
        expect(broken.load() == .standard, "Unreadable settings use a safe local default")
        print("Passed \(checks) mobile composition and document lifecycle checks.")
    }
}
