import AppKit
import InputMethodKit

// A document-side protocol implementation exercises native controller behavior without
// posting system keyboard events or modifying an external application.
final class TestDocument: NSObject, IMKTextInput {
    var text = ""
    var selection = NSRange(location: 0, length: 0)
    var mark = NSRange(location: NSNotFound, length: 0)
    var deferNextCommitSelection = false
    var deferNextMarkedSelection = false
    var staleSelection: NSRange?
    var attributedAccessEnabled = true
    var plainAccessEnabled = true
    var lastMarkedWasUnderlined = false
    func replace(_ value: String, range: NSRange) {
        text = (text as NSString).replacingCharacters(in: range, with: value)
        selection = NSRange(location: range.location + value.utf16.count, length: 0)
    }
    func insertText(_ string: Any!, replacementRange range: NSRange) {
        let before = selection
        let value = (string as? String) ?? (string as? NSAttributedString)?.string ?? ""
        replace(value, range: range.location != NSNotFound ? range : (mark.location != NSNotFound ? mark : selection))
        mark = NSRange(location: NSNotFound, length: 0)
        if deferNextCommitSelection {
            staleSelection = before
            deferNextCommitSelection = false
        }
    }
    func setMarkedText(_ string: Any!, selectionRange relative: NSRange, replacementRange range: NSRange) {
        let before = selection
        let attributed = string as? NSAttributedString
        let value = (string as? String) ?? attributed?.string ?? ""
        if let attributed = attributed, attributed.length > 0 {
            lastMarkedWasUnderlined = (attributed.attribute(.underlineStyle, at: 0, effectiveRange: nil) as? Int) == NSUnderlineStyle.single.rawValue
        } else { lastMarkedWasUnderlined = false }
        let target = range.location != NSNotFound ? range : (mark.location != NSNotFound ? mark : selection)
        replace(value, range: target)
        mark = NSRange(location: target.location, length: value.utf16.count)
        selection = NSRange(location: target.location + relative.location, length: relative.length)
        if deferNextMarkedSelection {
            staleSelection = before
            deferNextMarkedSelection = false
        }
    }
    func selectedRange() -> NSRange { staleSelection ?? selection }
    func markedRange() -> NSRange { mark }
    func attributedSubstring(from range: NSRange) -> NSAttributedString! {
        guard attributedAccessEnabled else { return nil }
        guard range.location != NSNotFound, NSMaxRange(range) <= text.utf16.count else { return nil }
        return NSAttributedString(string: (text as NSString).substring(with: range))
    }
    func length() -> Int { text.utf16.count }
    func characterIndex(for point: NSPoint, tracking mappingMode: IMKLocationToOffsetMappingMode, inMarkedRange: UnsafeMutablePointer<ObjCBool>!) -> Int { 0 }
    func attributes(forCharacterIndex index: Int, lineHeightRectangle rect: UnsafeMutablePointer<NSRect>!) -> [AnyHashable: Any]! { [:] }
    func validAttributesForMarkedText() -> [Any]! { [] }
    func overrideKeyboard(withKeyboardNamed name: String!) {}
    func selectMode(_ modeIdentifier: String!) {}
    func supportsUnicode() -> Bool { true }
    func bundleIdentifier() -> String! { "com.minh.VietMoi.TestDocument" }
    func windowLevel() -> CGWindowLevel { 0 }
    func supportsProperty(_ property: TSMDocumentPropertyTag) -> Bool { true }
    func uniqueClientIdentifierString() -> String! { "test-document" }
    func string(from range: NSRange, actualRange: NSRangePointer!) -> String! {
        guard plainAccessEnabled else { return nil }
        actualRange?.pointee = range
        guard range.location != NSNotFound, NSMaxRange(range) <= text.utf16.count else { return nil }
        return (text as NSString).substring(with: range)
    }
    func firstRect(forCharacterRange range: NSRange, actualRange: NSRangePointer!) -> NSRect { .zero }
}

let document = TestDocument()
var testProfile = KeyboardProfile.makeDefault()
testProfile.inputType = .grid4x8
testProfile.suggestionsEnabled = false
var tapThreshold = 0.20
var eventTime: TimeInterval = 1
var checks = 0
var physicalKeys: Set<UInt16> = []
var persistentASCII = false
var englishFixture = KeyboardProfile.makeEnglish()
englishFixture.suggestionsEnabled = false
let dictionary = ShuangpinDictionary(contents: try String(contentsOfFile: CommandLine.arguments[1], encoding: .utf8))
let controller = InputSession(showGuide: false, profileProvider: { persistentASCII ? englishFixture : testProfile },
                              shiftTapThreshold: { tapThreshold }, keyIsDown: { physicalKeys.contains($0) },
                              switchKeyboard: { persistentASCII.toggle() }, chineseDictionary: dictionary)
@discardableResult func press(_ key: UInt16, characters: String = "", flags: NSEvent.ModifierFlags = [], type: NSEvent.EventType = .keyDown, at time: TimeInterval? = nil, autoRelease: Bool = true, isRepeat: Bool = false) -> Bool {
    eventTime = time ?? eventTime + 0.01
    if type == .flagsChanged && [56,60].contains(key) {
        let side = flags.rawValue & 0x6
        let down = side != 0 ? side & (key == 56 ? 0x2 : 0x4) != 0 : flags.contains(.shift)
        if down { physicalKeys.insert(key) } else { physicalKeys.remove(key) }
    }
    if type == .keyDown { physicalKeys.insert(key) }
    if type == .keyUp { physicalKeys.remove(key) }
    let event = NSEvent.keyEvent(with: type, location: .zero, modifierFlags: flags, timestamp: eventTime,
                               windowNumber: 0, context: nil, characters: characters,
                               charactersIgnoringModifiers: characters, isARepeat: isRepeat, keyCode: key)!
    let handled = controller.handle(event, client: document)
    if type == .keyDown && autoRelease {
        physicalKeys.remove(key)
        eventTime += 0.005
        let release = NSEvent.keyEvent(with: .keyUp, location: .zero, modifierFlags: flags, timestamp: eventTime,
                                      windowNumber: 0, context: nil, characters: characters,
                                      charactersIgnoringModifiers: characters, isARepeat: false, keyCode: key)!
        _ = controller.handle(release, client: document)
    }
    return handled
}
func expect(_ value: Bool, _ message: String) { checks += 1; if !value { fatalError(message) } }
func ma() { for key: UInt16 in [15,20,18,18] { press(key) } }
ma()
expect(document.text == "ma ", "native controller must commit ma")
press(46)
expect(document.text == "", "m must erase the completed cycle")
document.deferNextCommitSelection = true
ma()
document.staleSelection = nil
press(46)
expect(document.text == "", "cycle clearing must allow asynchronously updated selection after commit")
ma()
controller.commitComposition(document)
press(46)
expect(document.text == "", "empty host boundary must preserve recent-cycle deletion")
press(15); press(20); press(18); press(51)
expect(document.text == "ma", "Backspace undoes the final while retaining the combined vowel")
press(53)
expect(document.text == "", "Escape must cancel partial marked text")
document.text = "keep"; document.selection = NSRange(location: 0, length: 4)
press(15); press(53)
expect(document.text == "keep", "cancelling replacement must restore selected text")
document.selection = NSRange(location: 4, length: 0)
ma()
document.selection = NSRange(location: 0, length: 0)
press(46)
expect(document.text == "keepma ", "clear must not erase at moved caret")
press(56, flags: .shift, type: .flagsChanged)
press(56, type: .flagsChanged)
press(46, characters: "m")
expect(document.text == "mkeepma ", "m must remain literal in ASCII")
press(56, flags: .shift, type: .flagsChanged)
press(56, type: .flagsChanged)
ma()
expect(document.text == "mma keepma ", "Shift must return to Vietnamese mode")
// A host can cache the prior process's markedRange. It must not reset every new key.
document.text = ""; document.selection = NSRange(location: 0, length: 0)
document.mark = NSRange(location: NSNotFound, length: 0)
controller.activateServer(document)
press(15)
document.mark = NSRange(location: 40, length: 1)
// The cached range is only a reported value: restore it before the mock's replacement operation.
// Validate the selection-based movement decision directly by issuing an unused vowel key first.
press(45)
expect(document.text == "m", "a stale marked range must not discard the new initial")
document.mark = NSRange(location: 0, length: 1)
press(20); press(18); press(18)
expect(document.text == "ma ", "composition must recover after stale marked-range metadata")
document.text = ""; document.selection = NSRange(location: 0, length: 0)
document.mark = NSRange(location: NSNotFound, length: 0)
testProfile.inputType = .asciiPlus
controller.activateServer(document)
asciiKeys("wse")
expect(document.text == "nha" && document.lastMarkedWasUnderlined,
       "third round leaves the complete unaccented syllable underlined until tone selection")
press(53)
expect(document.text.isEmpty, "Cancelling the tone-preview regression restores the empty document")
asciiKeys("mse")
expect(press(1) && document.text == "ma ", "ASCII+ s commits ma after e selects the empty final")
press(117)
expect(document.text == "", "ASCII+ Fn+Backspace clears a completed cycle")
asciiKeys("mse"); press(2)
expect(document.text == "má ", "ASCII+ d selects sắc in the last round")
press(46)
expect(document.text == "má m", "ASCII+ m is a phoneme, not the grid clear key")
press(51)
expect(document.text == "má ", "ASCII+ Backspace cancels a one-component cycle")
asciiKeys("mees")
expect(document.text == "má miê ", "ASCII+ e selects the combined bare iê nucleus")
press(46)
testProfile.inputType = .grid4x8
press(15); press(20); press(18); press(18)
expect(document.text == "má miê ma ", "changing input type cancels partial input and applies the new physical map")
testProfile.inputType = .asciiPlus
press(56, flags: .shift, type: .flagsChanged); press(56, type: .flagsChanged)
press(46, characters: "m")
expect(document.text == "má miê ma m", "ASCII+ retains literal ASCII switching")
press(56, flags: .shift, type: .flagsChanged); press(56, type: .flagsChanged)
asciiKeys("mse"); press(1)
expect(document.text == "má miê ma mma ", "Shift returns to the selected ASCII+ mode")
asciiKeys("mse")
let beforeInvalid = document.text
expect(press(35) && document.text == beforeInvalid, "a modal letter unavailable in the current phase is consumed without advancing")
press(53)
document.text = ""; document.selection = NSRange(location: 0, length: 0)
document.mark = NSRange(location: NSNotFound, length: 0)
controller.activateServer(document)
asciiKeys("mse"); press(38)
expect(document.text == "mả " && document.text.count == 3, "hỏi attaches to the core and adds a separator")
press(117)
expect(document.text == "", "cycle clear includes the tone-bearing vowel and separator")
func asciiKeys(_ keys: String) {
    for key in keys { press(ASCIIKeyboardLayout.keyCodesByLabel[String(key)]!) }
}
func hostKey(_ key: UInt16, _ characters: String) {
    let handled = press(key, characters: characters)
    expect(!handled, "Host key \(key) must pass through")
    if !characters.isEmpty {
        document.insertText(characters, replacementRange: NSRange(location: NSNotFound, length: NSNotFound))
    }
}

// Punctuation, spacing, unused numbers, and function keys remain host input.
let asciiPassThrough: [(UInt16, String)] = [
    (49, " "), (43, ","), (47, "."), (44, "/"), (41, ";"), (39, "'"),
    (33, "["), (30, "]"), (42, "\\"), (50, "`"), (27, "-"), (24, "="),
    (18, "1"), (25, "9"), (29, "0")
]
document.text = ""; document.selection = NSRange(location: 0, length: 0)
document.mark = NSRange(location: NSNotFound, length: 0)
controller.activateServer(document)
for (key, characters) in asciiPassThrough { hostKey(key, characters) }
let asciiHostText = asciiPassThrough.map(\.1).joined()
expect(document.text == asciiHostText, "ASCII+ passes ordinary host characters unchanged")
expect(!press(47, characters: ".", isRepeat: true), "Repeated punctuation continues through ASCII+")
document.insertText(".", replacementRange: NSRange(location: NSNotFound, length: NSNotFound))
asciiKeys("ms")
hostKey(43, ",")
expect(document.text == asciiHostText + ".ma,", "Host punctuation preserves an unfinished ASCII+ syllable before insertion")
asciiKeys("m")
let beforeModalRepeat = document.text
expect(press(46, isRepeat: true) && document.text == beforeModalRepeat, "Repeated modal key does not advance another phase")
expect(!press(96), "Function keys pass through ASCII+")
expect(document.text == asciiHostText + ".ma,m", "A function key preserves unfinished ASCII+ text")

testProfile.inputType = .grid4x8
controller.activateServer(document)
let gridPassThrough = asciiPassThrough.filter { ![18,19,20,21,23,22,26,28].contains($0.0) }
for (key, characters) in gridPassThrough { hostKey(key, characters) }
let gridHostText = gridPassThrough.map(\.1).joined()
expect(document.text == asciiHostText + ".ma,m" + gridHostText, "grid4x8 passes keys outside its physical input grid")
press(15)
hostKey(47, ".")
expect(document.text == asciiHostText + ".ma,m" + gridHostText + "m.", "Host punctuation preserves an unfinished grid syllable before insertion")
testProfile.inputType = .asciiPlus
controller.activateServer(document)
document.text = ""; document.selection = NSRange(location: 0, length: 0)
document.mark = NSRange(location: NSNotFound, length: 0)
testProfile.outputType = .quocNgu
asciiKeys("twis")
expect(document.text == "tay ", "Quốc ngữ spells short ă plus final i as ay")
asciiKeys("iuesaeas")
expect(document.text == "tay khuya nghiêng ", "Standard output handles uia and ngh while separating syllables")
asciiKeys("msej")
expect(document.text == "tay khuya nghiêng mả ", "Standard hỏi attaches to the main vowel")
asciiKeys("chej")
expect(document.text == "tay khuya nghiêng mả quả ", "Completed c + w + a is spelled quả")
asciiKeys("bbis")
expect(document.text == "tay khuya nghiêng mả quả buây ", "Rounded b + â + i preserves its initial in buây")
asciiKeys("bzis")
expect(document.text == "tay khuya nghiêng mả quả buây bây ", "b + â + i displays as bây")
asciiKeys("oved")
expect(document.text == "tay khuya nghiêng mả quả buây bây ý ", "standalone onsetless í displays with y")
press(117)
expect(document.text == "tay khuya nghiêng mả quả buây bây ", "Clear removes a whole standard syllable including its space")
document.text = ""; document.selection = NSRange(location: 0, length: 0)
document.mark = NSRange(location: NSNotFound, length: 0)
controller.activateServer(document)
asciiKeys("twisiuesaeas")
expect(document.text == "tay khuya nghiêng ", "Standard test state restored after c/u regression case")
asciiKeys("mse")
expect(document.text == "tay khuya nghiêng ma", "Marked text stays unaccented until the final tone choice")
press(51)
expect(document.text == "tay khuya nghiêng ma", "Backspace undoes the final while retaining the selected vowel")
press(53)
expect(document.text == "tay khuya nghiêng ", "Escape cancels standard marked text")
asciiKeys("mse")
testProfile.outputType = .sieuviet
asciiKeys("msej")
expect(document.text == "tay khuya nghiêng mả ", "Changing output cancels partial standard text and preserves Sieuviet output")
testProfile.outputType = .quocNgu
testProfile.inputType = .grid4x8
press(15); press(20); press(18); press(19)
expect(document.text == "tay khuya nghiêng mả má ", "Grid input also uses the selected standard formatter")
press(56, flags: .shift, type: .flagsChanged); press(56, type: .flagsChanged)
press(18, characters: "1")
expect(document.text == "tay khuya nghiêng mả má 1", "Literal ASCII bypasses standard syllable formatting and spacing")
document.selection = NSRange(location: 0, length: 3)
press(56, flags: .shift, type: .flagsChanged); press(56, type: .flagsChanged)
press(15); press(19); press(18); press(53)
expect(document.text == "tay khuya nghiêng mả má 1", "Cancelling a standard replacement restores the selected text")

// Shift+Backspace removes the preceding alphabetic cycle, spaces after it, and
// the single separator space immediately before it.
testProfile.inputType = .grid4x8
testProfile.outputType = .sieuviet
persistentASCII = false
document.text = "alpha beta   "; document.selection = NSRange(location: document.text.utf16.count, length: 0)
document.mark = NSRange(location: NSNotFound, length: 0)
controller.activateServer(document)
expect(press(51, flags: .shift), "Shift+Backspace handles a previous grid-mode cycle")
expect(document.text == "alpha", "Previous-cycle deletion removes trailing spaces, beta, and its separator")

document.text = "one   two  "; document.selection = NSRange(location: document.text.utf16.count, length: 0)
expect(press(51, flags: .shift) && document.text == "one  ", "The closest separator space is removed with the cycle")
document.text = " trước"; document.selection = NSRange(location: document.text.utf16.count, length: 0)
expect(press(51, flags: .shift) && document.text.isEmpty, "Unicode Vietnamese cycle and its separator delete together")
document.text = "letters"; document.selection = NSRange(location: document.text.utf16.count, length: 0)
expect(press(51, flags: .shift) && document.text.isEmpty, "A cycle at document start deletes without requiring a separator")
document.text = "   "; document.selection = NSRange(location: document.text.utf16.count, length: 0)
expect(press(51, flags: .shift) && document.text == "   ", "Spaces without a previous cycle are a handled no-op")
document.text = "word!"; document.selection = NSRange(location: document.text.utf16.count, length: 0)
expect(!press(51, flags: .shift) && document.text == "word!", "Punctuation retains ordinary host Backspace behavior")

document.text = "literal mode"; document.selection = NSRange(location: document.text.utf16.count, length: 0)
press(56, flags: .shift, type: .flagsChanged); press(56, type: .flagsChanged)
expect(persistentASCII, "Shift tap enters literal ASCII for deletion coverage")
expect(press(51, flags: .shift) && document.text == "literal", "Shift+Backspace uses the same deletion in literal ASCII")

document.text = "abc nmq   "; document.selection = NSRange(location: document.text.utf16.count, length: 0)
expect(press(51, flags: .shift) && document.text == "abc", "Exact trailing-space example deletes in one action")
document.text = "abc nmq"; document.selection = NSRange(location: document.text.utf16.count, length: 0)
expect(press(117, flags: .shift) && document.text == "abc", "Forward Delete keycode uses the same exact deletion")

document.text = "abc nmq   "; document.selection = NSRange(location: document.text.utf16.count, length: 0)
press(56, flags: .shift, type: .flagsChanged)
expect(press(51) && document.text == "abc", "Tracked physical Shift works when Delete omits its Shift event flag")
press(56, type: .flagsChanged)

document.text = "abc nmq"; document.selection = NSRange(location: document.text.utf16.count, length: 0)
document.attributedAccessEnabled = false
expect(press(51, flags: .shift) && document.text == "abc", "Plain document-string fallback supports real clients without attributed access")
document.attributedAccessEnabled = true

document.text = ""; document.selection = NSRange(location: 0, length: 0)
document.mark = NSRange(location: NSNotFound, length: 0)
for character in "abc nmq" {
    let label = String(character)
    let code: UInt16 = character == " " ? 49 : ASCIIKeyboardLayout.keyCodesByLabel[label]!
    press(code, characters: label)
}
document.attributedAccessEnabled = false
document.plainAccessEnabled = false
expect(press(51, flags: .shift) && document.text == "abc", "Recent committed text supports clients that deny both document-reading APIs")
document.attributedAccessEnabled = true
document.plainAccessEnabled = true

document.text = "prior "; document.selection = NSRange(location: document.text.utf16.count, length: 0)
press(56, flags: .shift, type: .flagsChanged); press(56, type: .flagsChanged)
asciiKeys("m")
expect(press(51, flags: .shift) && document.text.isEmpty, "Shift+Backspace cancels partial input then deletes the previous cycle")

func freshShiftTest() {
    document.text = ""; document.selection = NSRange(location: 0, length: 0)
    document.mark = NSRange(location: NSNotFound, length: 0)
    testProfile.inputType = .asciiPlus
    testProfile.outputType = .sieuviet
    tapThreshold = 0.20
    eventTime = 0
    physicalKeys.removeAll()
    persistentASCII = false
    controller.activateServer(document)
}
func shift(_ down: Bool, at time: TimeInterval) {
    press(56, flags: down ? .shift : [], type: .flagsChanged, at: time)
}
func expectViet(_ message: String) {
    let before = document.text
    expect(press(46) && document.mark.location != NSNotFound, message)
    press(53)
    expect(document.text == before, "Cancelling the mode probe restores text")
}

freshShiftTest()
document.deferNextMarkedSelection = true
asciiKeys("m")
document.staleSelection = nil
expect(press(51, characters: "\u{8}") && document.text.isEmpty,
       "Backspace removes the initial after the host asynchronously acknowledses its marked caret")

freshShiftTest()
shift(true, at: 1); shift(false, at: 1.1)
expect(persistentASCII, "A Shift tap stores literal ASCII as input-method state")
controller.deactivateServer(document)
controller.activateServer(document)
press(46, characters: "m")
expect(document.text == "m", "Literal ASCII survives focus/client deactivation and activation")
shift(true, at: 2); shift(false, at: 2.1)
expect(!persistentASCII, "Another Shift tap stores the return to Vietnamese mode")
expectViet("Vietnamese mode also survives after the stored mode changes back")

freshShiftTest()
asciiKeys("m")
shift(true, at: 1)
expect(document.text == "m", "Shift down must not toggle or cancel a composition")
shift(false, at: 1.1)
expect(document.text == "m", "A short isolated release switches modes and preserves the initial")
press(18, characters: "1")
expect(document.text == "m1", "Short tap enables literal ASCII without dropping the initial")
shift(true, at: 2); shift(false, at: 2.1)
asciiKeys("mses")
expect(document.text == "m1ma ", "A second short tap returns to Vietnamese")

freshShiftTest()
asciiKeys("m")
shift(true, at: 1); shift(false, at: 1.5)
asciiKeys("ses")
expect(document.text == "ma ", "Long hold alone preserves the mode and partial cycle")
freshShiftTest()
shift(true, at: 0); shift(false, at: 0.2)
expectViet("Exactly the threshold is a hold")

freshShiftTest()
shift(true, at: 1)
expect(!press(0, characters: "A", flags: .shift, at: 1.05, autoRelease: false), "Shift+A must pass to the host")
shift(false, at: 1.1)
press(0, type: .keyUp, at: 1.15)
expectViet("Releasing Shift before the letter must not switch")
asciiKeys("mses")
expect(document.text == "ma ", "Vietnamese typing resumes after the shifted chord")

freshShiftTest()
asciiKeys("mse")
shift(true, at: 1)
expect(!press(18, characters: "!", flags: .shift, at: 1.05), "Shift+1 punctuation must pass through")
expect(document.text == "ma", "A normal Shift chord preserves partial text before host handling")
shift(false, at: 1.1)
expectViet("Releasing the letter before Shift must not switch")

freshShiftTest()
press(46, at: 1, autoRelease: false)
shift(true, at: 1.02); shift(false, at: 1.05)
press(46, type: .keyUp, at: 1.1)
asciiKeys("ses")
expect(document.text == "ma ", "A key already held when Shift starts prevents a tap switch")

freshShiftTest()
shift(true, at: 1)
expect(!press(123, flags: .shift, at: 1.05), "Shift+Left remains a selection shortcut")
shift(false, at: 1.1)
expectViet("Selection shortcuts cannot toggle modes")
shift(true, at: 2)
expect(!press(48, flags: .shift, at: 2.05), "Shift+Tab remains backward navigation")
shift(false, at: 2.1)
expectViet("Shift+Tab cannot toggle modes")

freshShiftTest()
shift(true, at: 1)
press(55, flags: [.shift, .command], type: .flagsChanged, at: 1.02)
expect(!press(6, flags: [.shift, .command], at: 1.04), "Command+Shift+Z remains a host shortcut")
press(55, flags: .shift, type: .flagsChanged, at: 1.06)
shift(false, at: 1.1)
expectViet("Other modifiers cancel a tap even if released first")
press(56, flags: [.shift, .option], type: .flagsChanged, at: 2)
press(56, flags: .option, type: .flagsChanged, at: 2.1)
expectViet("Shift with an already-held modifier is not an isolated tap")

freshShiftTest()
press(60, flags: .shift, type: .flagsChanged, at: 1)
press(60, type: .flagsChanged, at: 1.1)
expectViet("Right Shift is always a regular modifier")
let leftFlags = NSEvent.ModifierFlags(rawValue: NSEvent.ModifierFlags.shift.rawValue | 0x2)
let rightFlags = NSEvent.ModifierFlags(rawValue: NSEvent.ModifierFlags.shift.rawValue | 0x4)
let bothFlags = NSEvent.ModifierFlags(rawValue: NSEvent.ModifierFlags.shift.rawValue | 0x6)
press(56, flags: leftFlags, type: .flagsChanged, at: 2)
press(60, flags: bothFlags, type: .flagsChanged, at: 2.02)
press(56, flags: rightFlags, type: .flagsChanged, at: 2.05)
press(60, type: .flagsChanged, at: 2.1)
expectViet("Two Shift keys must not cause a tap when left releases first")
press(60, flags: rightFlags, type: .flagsChanged, at: 3)
press(56, flags: bothFlags, type: .flagsChanged, at: 3.02)
press(60, flags: leftFlags, type: .flagsChanged, at: 3.05)
press(56, type: .flagsChanged, at: 3.1)
expectViet("Two Shift keys must not cause a tap when right releases first")
shift(true, at: 4); shift(false, at: 4.1)
press(0, characters: "A", flags: .capsLock)
expect(document.text == "A", "Literal ASCII preserves capitalization, and Shift tracking recovers")

freshShiftTest()
tapThreshold = 0.5
shift(true, at: 1); shift(false, at: 1.3)
press(18, characters: "1")
expect(document.text == "1", "A custom threshold is used for the next tap")
shift(true, at: 2); shift(false, at: 2.8)
press(19, characters: "2")
expect(document.text == "12", "Long hold in ASCII mode does not switch back")

freshShiftTest()
shift(true, at: 1)
controller.deactivateServer(document)
controller.activateServer(document)
shift(false, at: 1.1)
expectViet("Losing focus while holding Shift cannot leave a pending tap")
shift(true, at: 2)
controller.commitComposition(document)
shift(false, at: 2.1)
press(18, characters: "1")
expect(document.text == "1", "An empty composition callback between Shift events must not cancel an isolated tap")

freshShiftTest()
// The physical key is released, but its key-up never reaches the input method.
press(46, at: 0.1, autoRelease: false)
physicalKeys.remove(46)
controller.commitComposition(document)
shift(true, at: 1)
controller.commitComposition(document)
shift(false, at: 1.1)
press(18, characters: "1")
expect(document.text == "m1", "Missing ordinary key-up must not permanently block Shift taps")
shift(true, at: 2); shift(false, at: 2.1)
asciiKeys("mses")
expect(document.text == "m1ma ", "Mode switching recovers in both directions after a missing key-up")

freshShiftTest()
shift(true, at: 1)
press(0, flags: .shift, at: 1.02, autoRelease: false)
physicalKeys.remove(0)
shift(false, at: 1.1)
expectViet("A missing key-up inside a chord must still suppress that tap")
shift(true, at: 2); shift(false, at: 2.1)
press(18, characters: "1")
expect(document.text == "1", "The next isolated tap recovers after a chord with a missing release")

// Selection deletion must not leave a cached modifier latched for this text client.
for literal in [false, true] {
    for selectingShift: UInt16 in [56, 60] {
        freshShiftTest()
        persistentASCII = literal
        controller.activateServer(document)
        document.text = "keep delete"
        document.selection = NSRange(location: document.text.utf16.count, length: 0)
        press(selectingShift, flags: .shift, type: .flagsChanged, at: 1)
        press(123, flags: .shift, at: 1.05)
        document.selection = NSRange(location: 5, length: 6)
        // Selection/editing clients can swallow the modifier release and Delete key-up.
        physicalKeys.remove(selectingShift)
        expect(!press(51, characters: "\u{8}", at: 1.2, autoRelease: false), "Deleting a selection is owned by the host")
        document.insertText("", replacementRange: document.selection)
        physicalKeys.remove(51)
        expect(document.text == "keep ", "The host deletes only the selected text")
        shift(true, at: 2); shift(false, at: 2.1)
        expect(persistentASCII != literal, "The first tap after selection deletion toggles despite a missing modifier release")
        shift(true, at: 3); shift(false, at: 3.1)
        expect(persistentASCII == literal, "The next tap returns to the original mode in the same field")
    }
}

// Mouse-selected text follows the same native deletion path in both layouts and
// both output modes, including forward Delete and missing host key-up events.
for layout: InputType in [.grid4x8, .asciiPlus] {
    for literal in [false, true] {
        for delete: UInt16 in [51,117] {
            freshShiftTest()
            testProfile.inputType = layout
            persistentASCII = literal
            controller.activateServer(document)
            document.text = "before selected after"
            document.selection = NSRange(location: document.text.utf16.count, length: 0)
            let mouse = NSEvent.mouseEvent(with: .leftMouseDown, location: .zero, modifierFlags: [], timestamp: 1,
                                           windowNumber: 0, context: nil, eventNumber: 1, clickCount: 1, pressure: 1)!
            expect(!controller.handle(mouse, client: document), "Mouse selection remains native")
            document.selection = NSRange(location: 7, length: 8)
            controller.commitComposition(document)
            expect(!press(delete, at: 1.2, autoRelease: false), "Both Delete keys pass selected-text deletion to the host")
            document.insertText("", replacementRange: document.selection)
            physicalKeys.remove(delete)
            controller.commitComposition(document)
            expect(document.text == "before  after", "Deleting selection leaves neighboring text intact")
            for tap in 0..<3 {
                shift(true, at: Double(tap + 2)); shift(false, at: Double(tap + 2) + 0.1)
                expect(persistentASCII == (tap % 2 == 0 ? !literal : literal), "Repeated taps keep working in the same field after mouse deletion")
            }
        }
    }
}

// A side-specific event also clears a stale opposite-side flag even if no
// intermediate unshifted key event arrives at IMK.
freshShiftTest()
press(60, flags: rightFlags, type: .flagsChanged, at: 1)
physicalKeys.remove(60)
press(56, flags: leftFlags, type: .flagsChanged, at: 2)
press(56, type: .flagsChanged, at: 2.1)
expect(persistentASCII, "A fresh left-side snapshot clears a missed Right Shift release")

// Replay the physical trace: a selected-text Delete gets no key-up at IMK,
// then each Shift transition is delivered twice. Hardware Delete is released;
// the native combined logical table can still report it down. The injected
// key provider models hardware, matching the production HID state source.
for literal in [false, true] {
    freshShiftTest()
    persistentASCII = literal
    controller.activateServer(document)
    document.text = "remove"
    document.selection = NSRange(location: 0, length: 6)
    expect(!press(51, characters: "\u{8}", at: 1, autoRelease: false), "Host handles selected-text Delete in trace replay")
    document.insertText("", replacementRange: document.selection)
    physicalKeys.remove(51)
    for tap in 0..<4 {
        let start = Double(tap + 2)
        shift(true, at: start); shift(true, at: start + 0.004)
        shift(false, at: start + 0.1); shift(false, at: start + 0.104)
        expect(persistentASCII == (tap % 2 == 0 ? !literal : literal), "Missing Delete key-up and duplicate modifiers toggle once per hardware tap")
    }
}

// Incomplete syllables/abbreviations are kept on a normal boundary, with no
// fabricated tone or extra separator when entering literal ASCII.
for layout: InputType in [.asciiPlus, .grid4x8] {
    freshShiftTest()
    testProfile.inputType = layout
    controller.activateServer(document)
    let initial: UInt16 = layout == .asciiPlus ? 46 : 15
    press(initial)
    expect(press(49, characters: " ") && document.text == "m ", "m + Space keeps the initial and inserts exactly one space")
    expect(document.mark.location == NSNotFound, "Space ends the composition")
    press(initial)
    shift(true, at: 1); shift(false, at: 1.1)
    expect(persistentASCII && document.text == "m m", "Mode switching preserves the partial initial without adding a space")
    press(16, characters: "y")
    expect(document.text == "m my", "m + Shift tap + y produces my")
    shift(true, at: 2); shift(false, at: 2.1)
    press(initial)
    expect(press(51, characters: "\u{8}") && document.text == "m my", "Backspace immediately deletes the selected initial atom")
}

freshShiftTest()
asciiKeys("ms")
expect(press(49, characters: " ") && document.text == "ma ", "Space preserves a two-round abbreviation")
asciiKeys("msn")
expect(press(49, characters: " ") && document.text == "ma man ", "Space preserves a three-round abbreviation without requiring tone")
asciiKeys("m")
controller.commitComposition(document)
expect(document.text == "ma man m", "A host-requested composition flush keeps a partial initial")
shift(true, at: 3); shift(false, at: 3.1)
press(16, characters: "y")
expect(document.text == "ma man my", "A host flush before the mode switch does not erase or duplicate text")

freshShiftTest()
asciiKeys("m")
expect(controller.command(NSSelectorFromString("deleteBackward:"), client: document) && document.text.isEmpty,
       "Responder-command Backspace deletes an initial when no raw key event is delivered")
expect(!controller.command(NSSelectorFromString("deleteBackward:"), client: document), "Idle responder Backspace remains native")
asciiKeys("msn")
expect(controller.command(NSSelectorFromString("deleteBackward:"), client: document) && document.text == "ma", "Responder Backspace undoes the final")
expect(controller.command(NSSelectorFromString("deleteBackward:"), client: document) && document.text == "m", "Responder Backspace undoes the combined vowel")
expect(controller.command(NSSelectorFromString("deleteBackwardByDecomposingPreviousCharacter:"), client: document) && document.text.isEmpty,
       "Decomposing Backspace also deletes the initial")
asciiKeys("m")
expect(controller.command(NSSelectorFromString("insertSpace:"), client: document) && document.text == "m ", "Responder Space preserves abbreviations")
asciiKeys("m")
expect(controller.command(NSSelectorFromString("cancelOperation:"), client: document) && document.text == "m ", "Explicit Escape still discards progress")
asciiKeys("msn")
controller.deactivateServer(document)
expect(document.text == "m man", "Leaving a field preserves the visible partial word without a separator")

freshShiftTest()
asciiKeys("m")
shift(true, at: 1); shift(false, at: 1.1)
press(16, characters: "y")
expect(document.text == "my" && persistentASCII, "Exact m + isolated Shift tap + y flow keeps both characters")

freshShiftTest()
asciiKeys("j")
expect(controller.compositionText == "ch", "IMK composition mirror contains the whole initial atom")
expect(controller.command(NSSelectorFromString("deleteBackward:"), client: document) && document.text.isEmpty,
       "Backspace removes the whole ch initial, not just its final letter")
asciiKeys("m")
expect(!controller.command(NSSelectorFromString("insertNewline:"), client: document) && document.text == "m", "Responder Return preserves text and leaves newline insertion to the host")
asciiKeys("m")
expect(!press(48, characters: "\t") && document.text == "mm", "Tab preserves the initial before native focus navigation")

freshShiftTest()
shift(true, at: 1)
expect(!controller.command(NSSelectorFromString("noop:"), client: document), "Unrecognized host commands pass through")
shift(false, at: 1.1)
expect(persistentASCII, "A no-op command between modifier events does not suppress an isolated Shift tap")

freshShiftTest()
document.deferNextMarkedSelection = true
asciiKeys("m")
expect(press(51, characters: "\u{8}") && document.text.isEmpty,
       "Backspace works even before the host acknowledses the marked caret")
document.staleSelection = nil

freshShiftTest()
document.text = "keep"; document.selection = NSRange(location: 0, length: 4)
document.deferNextMarkedSelection = true
asciiKeys("m")
expect(controller.command(NSSelectorFromString("deleteBackward:"), client: document) && document.text == "keep",
       "Unacknowledged replacement selection does not divert initial undo to native deletion")
document.staleSelection = nil

freshShiftTest()
document.deferNextMarkedSelection = true
asciiKeys("m")
shift(true, at: 1)
expect(!controller.command(NSSelectorFromString("noop:"), client: document), "No-op does not discard a composition awaiting caret acknowledgement")
shift(false, at: 1.1)
document.staleSelection = nil
press(16, characters: "y")
expect(document.text == "my" && persistentASCII, "Mode switch preserves an initial while its caret acknowledgement is delayed")

// Quốc ngữ renders only a complete four-round basis, including final o.
freshShiftTest()
testProfile.outputType = .quocNgu
asciiKeys("ae")
expect(document.text == "ngiê" && document.lastMarkedWasUnderlined, "Quốc ngữ keeps round-two spelling phonetic")
asciiKeys("a")
expect(document.text == "ngiêng", "Round three remains phonetic")
press(51)
expect(document.text == "ngiê", "Backspace undoes the phonetic final before translation")
asciiKeys("as")
expect(document.text == "nghiêng ", "Tone completion translates the whole marked word exactly once")
asciiKeys("rwos")
expect(document.text == "nghiêng rau ", "Final o becomes u after the short vowel in quốc ngữ")
asciiKeys("tsos")
expect(document.text == "nghiêng rau tao ", "Final o remains o after long a")
asciiKeys("imoj")
expect(document.text == "nghiêng rau tao khuỷu ", "Both glides and tone translate from the completed basis")
asciiKeys("frej")
expect(document.text == "nghiêng rau tao khuỷu phở ", "Completed conversion can expand the initial's text length")
press(117)
expect(document.text == "nghiêng rau tao khuỷu ", "Clear deletes the translated range, including the expanded ph initial")
asciiKeys("jl")
press(49, characters: " ")
expect(document.text == "nghiêng rau tao khuỷu chuô ", "Space preserves partial phonetic spelling in quốc ngữ")
asciiKeys("f")
shift(true, at: eventTime + 1); shift(false, at: eventTime + 0.1)
press(16, characters: "y")
expect(document.text == "nghiêng rau tao khuỷu chuô fy", "ASCII switching preserves an untranslated initial")
testProfile.outputType = .sieuviet

// Initial-round swap: physical z selects z; physical j selects ch. The guide
// and native key routing must agree, while other rounds keep their own bindings.
freshShiftTest()
let initialActions = ASCIIPlusMapping.actions(for: KeyboardEngine())
expect(initialActions[6] == "z" && initialActions[38] == "ch", "Guide labels expose the swapped initial atoms")
asciiKeys("zsesjsos")
expect(document.text == "za chao ", "Native routing uses z for z and j for ch")

// oo is on a; semicolon remains native punctuation in every round.
freshShiftTest()
let initialSemicolonActions = ASCIIPlusMapping.actions(for: KeyboardEngine())
expect(initialSemicolonActions[41] == nil, "Semicolon has no modal action in the initial round")
asciiKeys("xaas")
expect(document.text == "xoong ", "Native a key selects the whole oo nucleus")
asciiKeys("sacd")
expect(document.text == "xoong soóc ", "Tone is applied to the second o of oo")
asciiKeys("x")
expect(press(0, characters: "a", isRepeat: true), "Repeating a vowel atom is consumed without advancing")
expect(document.text == "xoong soóc x", "Repeated modal a leaves composition unchanged")
hostKey(41, ";")
expect(document.text == "xoong soóc x;", "Semicolon finishes a partial vowel round and passes through literally")
var semicolonGuide = KeyboardEngine()
_ = semicolonGuide.selectComponent(0)
expect(ASCIIPlusMapping.actions(for: semicolonGuide)[0] == "oo" && ASCIIPlusMapping.actions(for: semicolonGuide)[41] == nil, "Round-two guide shows oo on a and no semicolon atom")

// Regression: real event payloads for editing commands are never inserted as text.
freshShiftTest()
asciiKeys("mse")
expect(document.text == "ma", "Sieuviet preview remains unaccented before the last tone choice")
expect(press(51, characters: "\u{8}") && document.text == "ma", "Backspace payload undoes a component without emitting U+0008")
expect(press(53, characters: "\u{1B}") && document.text.isEmpty, "Escape payload cancels without emitting U+001B")
expect(!press(51, characters: "\u{8}") && document.text.isEmpty, "Idle Backspace remains a native host command")
expect(!press(53, characters: "\u{1B}") && document.text.isEmpty, "Idle Escape remains a native host command")
for control in ["\u{0}", "\u{8}", "\u{1B}", "\u{9B}"] {
    expect(press(10, characters: control) && document.text.isEmpty, "Unrecognized control payload is consumed without text insertion")
}
expect(!press(36, characters: "\r"), "Return retains native command handling")
expect(!press(48, characters: "\t"), "Tab retains native command handling")
expect(!press(122, characters: "\u{F704}"), "Function keys retain native command handling")
asciiKeys("ms")
expect(document.text == "ma", "Combined vowel preview appears before final and tone choices")
asciiKeys("ek")
expect(document.text == "mã ", "Last tone choice accents the core and commits the word")
asciiKeys("mses")
expect(document.text == "mã ma ", "Repeated cycles retain one separator per syllable")
press(117, characters: "\u{F728}")
expect(document.text == "mã ", "Forward Delete clears the full cycle without inserting its event payload")
press(46); press(53, characters: "\u{1B}")
expect(document.text == "mã ", "Cancelling a later cycle preserves prior text")

// Profile remaps drive event routing and guide labels through the same bindings.
var alternate = ASCIIPlusKeymap.sieuviet
alternate.initials["b"] = "m"; alternate.initials["m"] = "b"
testProfile.asciiPlusKeymap = alternate
asciiKeys("bses")
expect(document.text == "mã ma ", "Controller honors a per-profile physical-key remap")
testProfile.asciiPlusKeymap = nil
shift(true, at: eventTime + 1); shift(false, at: eventTime + 0.1)
expect(persistentASCII, "Enter literal mode for control regression")
for control in ["\u{8}", "\u{1B}"] {
    let before = document.text
    expect(press(10, characters: control) && document.text == before, "Literal mode cannot insert control payloads either")
}

let languageSuite = "com.minh.sieuviet.controller.languages.\(UUID().uuidString)"
let languageDefaults = UserDefaults(suiteName: languageSuite)!
defer { languageDefaults.removePersistentDomain(forName: languageSuite) }
let languageProfiles = KeyboardProfiles(defaults: languageDefaults)
// The default list is [Vietnamese, English]; add Chinese as the third keyboard.
languageProfiles.update(languageProfiles.add(), language: .chinese)
languageProfiles.select(languageProfiles.profiles[1].id)
let multilingual = InputSession(showGuide: false, profileProvider: { languageProfiles.active }, keyIsDown: { _ in false },
    switchKeyboard: { languageProfiles.selectNext() }, chineseDictionary: dictionary,
    submitCompletion: { work, receive in receive(work()); return nil }, englishWords: { _ in ["hello", "help"] })
func multilingualKey(_ code: UInt16, _ value: String = "", type: NSEvent.EventType = .keyDown, flags: NSEvent.ModifierFlags = []) -> Bool {
    eventTime += 0.01
    let event = NSEvent.keyEvent(with: type, location: .zero, modifierFlags: flags, timestamp: eventTime,
        windowNumber: 0, context: nil, characters: value, charactersIgnoringModifiers: value, isARepeat: false, keyCode: code)!
    let handled = multilingual.handle(event, client: document)
    if type == .keyDown { _ = multilingualKey(code, value, type: .keyUp) }
    return handled
}
func multilingualLetters(_ value: String) {
    for key in value { _ = multilingualKey(ASCIIKeyboardLayout.keyCodesByLabel[String(key)]!, String(key)) }
}
document.text = ""; document.selection = NSRange(location: 0, length: 0); document.mark = NSRange(location: NSNotFound, length: 0)
multilingual.activateServer(document)
multilingualLetters("hel")
expect(document.text == "hel", "English typing inserts immediately")
expect(document.text == "hel", "Suggestions never delay typed characters")
expect(!multilingualKey(49, " ") || document.text != "hello ", "Space never accepts an English completion")
document.text = "hel"; document.selection = NSRange(location: 3, length: 0)
expect(multilingualKey(48) && document.text == "hello ", "Tab accepts an English word completion")
func resetDocument(_ text: String) {
    document.text = text; document.selection = NSRange(location: text.utf16.count, length: 0)
    document.mark = NSRange(location: NSNotFound, length: 0)
}
resetDocument("hel")
expect(multilingualKey(19, "2") && document.text == "help ", "A number key picks that suggestion")
resetDocument("hel")
expect(multilingualKey(27, "-") && document.text == "hel", "Minus escapes the next key while suggestions show")
expect(multilingualKey(19, "2") && document.text == "hel2", "Minus then a digit types the digit")
resetDocument("hel")
_ = multilingualKey(27, "-")
expect(multilingualKey(27, "-") && document.text == "hel-", "Minus twice types one minus")
resetDocument("he")
_ = multilingualKey(27, "-")
_ = multilingualKey(ASCIIKeyboardLayout.keyCodesByLabel["l"]!, "l")
expect(document.text == "he-l", "Minus then a letter keeps the minus")
resetDocument("hel")
_ = multilingualKey(27, "-")
expect(multilingualKey(51) && document.text == "hel", "Backspace drops a pending minus without deleting text")
expect(multilingualKey(19, "2") && document.text == "help ", "Number picks resume after a dropped minus")
resetDocument("hello ")
expect(multilingualKey(19, "2") && document.text == "hello 2", "Without suggestions a number key types its digit")
resetDocument("hello ")
languageProfiles.update(languageProfiles.active.id, suggestionsEnabled: false)
multilingualLetters("hel")
expect(!multilingualKey(48) && document.text == "hello hel", "Disabling English completion preserves normal Tab")
languageProfiles.select(languageProfiles.profiles[2].id)
languageProfiles.update(languageProfiles.active.id, suggestionsEnabled: false)
multilingualLetters("nihk")
expect(multilingual.command(NSSelectorFromString("insertSpace:"), client: document) && document.text == "hello hel你好", "Chinese responder Space converts without completion")
multilingualLetters("vsgo")
expect(multilingualKey(18, "1") && document.text == "hello hel你好中国", "Chinese number selection commits a candidate")
_ = multilingualKey(56, type: .flagsChanged, flags: .shift)
_ = multilingualKey(56, type: .flagsChanged)
expect(languageProfiles.active.language == .vietnamese, "Saved keyboard cycling wraps Chinese to the first keyboard")
_ = multilingualKey(56, type: .flagsChanged, flags: .shift)
_ = multilingualKey(56, type: .flagsChanged)
expect(languageProfiles.active.language == .english, "The next Shift tap reaches English")
multilingualLetters("ok")
expect(document.text == "hello hel你好中国ok", "English text remains literal after switching")
let vietnameseID = languageProfiles.profiles.first { $0.language == .vietnamese }!.id
languageProfiles.update(vietnameseID, input: .asciiPlus, suggestionsEnabled: true)
languageProfiles.select(vietnameseID)
document.text = ""; document.selection = NSRange(location: 0, length: 0); document.mark = NSRange(location: NSNotFound, length: 0)
multilingualLetters("x")
let syllable = document.text
expect(!syllable.isEmpty && document.mark.location != NSNotFound, "A Vietnamese initial is marked text")
expect(multilingualKey(48), "Tab accepts a Vietnamese completion")
expect(document.text.hasPrefix(syllable) && document.text.count > syllable.count + 1 && document.text.hasSuffix(" ")
       && document.mark.location == NSNotFound, "The completion follows the typed syllable in one word, not before it")
resetDocument("")
multilingualLetters("x")
expect(multilingualKey(27, "-"), "Minus escapes on ASCII+ while suggestions show")
expect(!multilingualKey(19, "2") && document.mark.location == NSNotFound && document.text == syllable,
       "An escaped digit ends the syllable and reaches the app as a digit")
resetDocument("")
multilingualLetters("x")
expect(multilingualKey(18, "1") && document.text.hasPrefix(syllable) && document.text.hasSuffix(" "), "1 picks the first ASCII+ suggestion")
resetDocument("ab")
multilingualLetters("o")
expect(document.text == "ab", "An empty onset shows nothing")
expect(!multilingualKey(51) && document.mark.location == NSNotFound, "Backspace on an invisible onset drops it and deletes as usual")
resetDocument("ab")
multilingualLetters("os")
expect(multilingualKey(51) && document.text == "ab", "Backspace removes the visible vowel first")
expect(!multilingualKey(51), "then deletes as usual instead of the invisible onset")
multilingual.deactivateServer(document)
print("Passed \(checks) native document-session and Shift interaction checks.")

