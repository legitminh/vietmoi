import AppKit
import InputMethodKit

// A document-side protocol implementation exercises native controller behavior without
// posting system keyboard events or modifying an external application.
final class TestDocument: NSObject, IMKTextInput {
    var text = ""
    var selection = NSRange(location: 0, length: 0)
    var mark = NSRange(location: NSNotFound, length: 0)
    var deferNextCommitSelection = false
    var staleSelection: NSRange?
    var attributedAccessEnabled = true
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
        let value = (string as? String) ?? ""
        let target = range.location != NSNotFound ? range : (mark.location != NSNotFound ? mark : selection)
        replace(value, range: target)
        mark = NSRange(location: target.location, length: value.utf16.count)
        selection = NSRange(location: target.location + relative.location, length: relative.length)
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
        actualRange?.pointee = range
        guard range.location != NSNotFound, NSMaxRange(range) <= text.utf16.count else { return nil }
        return (text as NSString).substring(with: range)
    }
    func firstRect(forCharacterRange range: NSRange, actualRange: NSRangePointer!) -> NSRect { .zero }
}

let document = TestDocument()
var testProfile = KeyboardProfile.makeDefault()
var tapThreshold = 0.20
var eventTime: TimeInterval = 1
var checks = 0
var physicalKeys: Set<UInt16> = []
var persistentASCII = false
let controller = InputSession(showGuide: false, profileProvider: { testProfile }, shiftTapThreshold: { tapThreshold },
                              keyIsDown: { physicalKeys.contains($0) },
                              asciiMode: { persistentASCII },
                              setASCIIMode: { persistentASCII = $0 })
@discardableResult func press(_ key: UInt16, characters: String = "", flags: NSEvent.ModifierFlags = [], type: NSEvent.EventType = .keyDown, at time: TimeInterval? = nil, autoRelease: Bool = true, isRepeat: Bool = false) -> Bool {
    eventTime = time ?? eventTime + 0.01
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
func ma() { for key: UInt16 in [15,18,18,18] { press(key) } }
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
press(15); press(18); press(18); press(51)
expect(document.text == "m", "Backspace must remove only the nucleus")
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
// Validate the selection-based movement decision directly by issuing an unused tone key first.
press(26)
expect(document.text == "m", "a stale marked range must not discard the new initial")
document.mark = NSRange(location: 0, length: 1)
press(18); press(18); press(18)
expect(document.text == "ma ", "composition must recover after stale marked-range metadata")
document.text = ""; document.selection = NSRange(location: 0, length: 0)
document.mark = NSRange(location: NSNotFound, length: 0)
testProfile.inputType = .asciiPlus
controller.activateServer(document)
press(46); press(13); press(0)
expect(press(14) && document.text == "ma ", "ASCII+ consumes e as the empty final and commits ma")
press(117)
expect(document.text == "", "ASCII+ Fn+Backspace clears a completed cycle")
press(46); press(14); press(0); press(14)
expect(document.text == "ma´", "ASCII+ e selects sắc")
press(46)
expect(document.text == "ma´m", "ASCII+ m is a phoneme, not the grid clear key")
press(51)
expect(document.text == "ma´", "ASCII+ Backspace cancels a one-component cycle")
press(46); press(13); press(32); press(14)
expect(document.text == "ma´mia ", "ASCII+ u selects ia at nucleus phase")
press(46)
testProfile.inputType = .grid4x8
press(15); press(18); press(18); press(18)
expect(document.text == "ma´mia ma ", "changing input type cancels partial input and applies the new physical map")
testProfile.inputType = .asciiPlus
press(56, flags: .shift, type: .flagsChanged); press(56, type: .flagsChanged)
press(46, characters: "m")
expect(document.text == "ma´mia ma m", "ASCII+ retains literal ASCII switching")
press(56, flags: .shift, type: .flagsChanged); press(56, type: .flagsChanged)
press(46); press(13); press(0); press(14)
expect(document.text == "ma´mia ma mma ", "Shift returns to the selected ASCII+ mode")
press(46)
let beforeInvalid = document.text
expect(press(35) && document.text == beforeInvalid, "a modal letter unavailable in the current phase is consumed without advancing")
press(53)
document.text = ""; document.selection = NSRange(location: 0, length: 0)
document.mark = NSRange(location: NSNotFound, length: 0)
controller.activateServer(document)
press(46); press(16); press(0); press(14)
expect(document.text == "ma?" && document.text.count == 3, "hỏi must commit as its own character after the syllable")
press(117)
expect(document.text == "", "cycle clear includes the standalone hỏi suffix")
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
asciiKeys("m")
hostKey(43, ",")
expect(document.text == asciiHostText + ".,", "Host punctuation cancels an unfinished ASCII+ syllable before insertion")
asciiKeys("m")
let beforeModalRepeat = document.text
expect(press(46, isRepeat: true) && document.text == beforeModalRepeat, "Repeated modal key does not advance another phase")
expect(!press(96), "Function keys pass through ASCII+")
expect(document.text == asciiHostText + ".,", "A function key cancels unfinished ASCII+ composition")

testProfile.inputType = .grid4x8
controller.activateServer(document)
let gridPassThrough = asciiPassThrough.filter { ![18,19,20,21,23,22,26,28].contains($0.0) }
for (key, characters) in gridPassThrough { hostKey(key, characters) }
let gridHostText = gridPassThrough.map(\.1).joined()
expect(document.text == asciiHostText + ".," + gridHostText, "grid4x8 passes keys outside its physical input grid")
press(15)
hostKey(47, ".")
expect(document.text == asciiHostText + ".," + gridHostText + ".", "Host punctuation cancels an unfinished grid syllable before insertion")
testProfile.inputType = .asciiPlus
controller.activateServer(document)
document.text = ""; document.selection = NSRange(location: 0, length: 0)
document.mark = NSRange(location: NSNotFound, length: 0)
testProfile.outputType = .vietstandard
asciiKeys("twei")
expect(document.text == "tay ", "Selecting standard output must apply ei to ay conversion")
asciiKeys("isueqwkq")
expect(document.text == "tay khuya nghiêng ", "Standard output handles uia and ngh while separating syllables")
asciiKeys("myae")
expect(document.text == "tay khuya nghiêng mả ", "Standard hỏi attaches to the main vowel")
asciiKeys("chae")
expect(document.text == "tay khuya nghiêng mả cuả ", "c + u medial stays cuả rather than being rewritten as quả")
asciiKeys("bsri")
expect(document.text == "tay khuya nghiêng mả cuả uây ", "buêi displays as the requested uây exception")
asciiKeys("bwri")
expect(document.text == "tay khuya nghiêng mả cuả uây bây ", "bêi displays as bây")
asciiKeys("eeie")
expect(document.text == "tay khuya nghiêng mả cuả uây bây ý ", "standalone onsetless í displays with y")
press(117)
expect(document.text == "tay khuya nghiêng mả cuả uây bây ", "Clear removes a whole standard syllable including its space")
document.text = ""; document.selection = NSRange(location: 0, length: 0)
document.mark = NSRange(location: NSNotFound, length: 0)
controller.activateServer(document)
asciiKeys("tweiisueqwkq")
expect(document.text == "tay khuya nghiêng ", "Standard test state restored after c/u regression case")
asciiKeys("mea")
expect(document.text == "tay khuya nghiêng má", "Marked text shows the standard tone before final selection")
press(51)
expect(document.text == "tay khuya nghiêng m", "Backspace undoes the toned nucleus")
press(53)
expect(document.text == "tay khuya nghiêng ", "Escape cancels standard marked text")
asciiKeys("mea")
testProfile.outputType = .vietmoi
asciiKeys("myae")
expect(document.text == "tay khuya nghiêng ma?", "Changing output cancels partial standard text and preserves custom suffix output")
testProfile.outputType = .vietstandard
testProfile.inputType = .grid4x8
press(15); press(19); press(18); press(18)
expect(document.text == "tay khuya nghiêng ma?má ", "Grid input also uses the selected standard formatter")
press(56, flags: .shift, type: .flagsChanged); press(56, type: .flagsChanged)
press(18, characters: "1")
expect(document.text == "tay khuya nghiêng ma?má 1", "Literal ASCII bypasses standard syllable formatting and spacing")
document.selection = NSRange(location: 0, length: 3)
press(56, flags: .shift, type: .flagsChanged); press(56, type: .flagsChanged)
press(15); press(19); press(18); press(53)
expect(document.text == "tay khuya nghiêng ma?má 1", "Cancelling a standard replacement restores the selected text")

// Shift+Backspace removes the preceding alphabetic cycle, spaces after it, and
// the single separator space immediately before it.
testProfile.inputType = .grid4x8
testProfile.outputType = .vietmoi
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

document.text = "prior "; document.selection = NSRange(location: document.text.utf16.count, length: 0)
press(56, flags: .shift, type: .flagsChanged); press(56, type: .flagsChanged)
asciiKeys("m")
expect(press(51, flags: .shift) && document.text.isEmpty, "Shift+Backspace cancels partial input then deletes the previous cycle")

func freshShiftTest() {
    document.text = ""; document.selection = NSRange(location: 0, length: 0)
    document.mark = NSRange(location: NSNotFound, length: 0)
    testProfile.inputType = .asciiPlus
    testProfile.outputType = .vietmoi
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
expect(document.text == "", "A short isolated release switches and cancels the partial cycle")
press(18, characters: "1")
expect(document.text == "1", "Short tap enables literal ASCII")
shift(true, at: 2); shift(false, at: 2.1)
asciiKeys("mwae")
expect(document.text == "1ma ", "A second short tap returns to Vietnamese")

freshShiftTest()
asciiKeys("m")
shift(true, at: 1); shift(false, at: 1.5)
asciiKeys("wae")
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
asciiKeys("mwae")
expect(document.text == "ma ", "Vietnamese typing resumes after the shifted chord")

freshShiftTest()
asciiKeys("mwa")
shift(true, at: 1)
expect(!press(18, characters: "!", flags: .shift, at: 1.05), "Shift+1 punctuation must pass through")
expect(document.text == "", "A normal Shift chord cancels partial composition before host handling")
shift(false, at: 1.1)
expectViet("Releasing the letter before Shift must not switch")

freshShiftTest()
press(46, at: 1, autoRelease: false)
shift(true, at: 1.02); shift(false, at: 1.05)
press(46, type: .keyUp, at: 1.1)
asciiKeys("wae")
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
expect(document.text == "1", "Missing ordinary key-up must not permanently block Shift taps")
shift(true, at: 2); shift(false, at: 2.1)
asciiKeys("mwae")
expect(document.text == "1ma ", "Mode switching recovers in both directions after a missing key-up")

freshShiftTest()
shift(true, at: 1)
press(0, flags: .shift, at: 1.02, autoRelease: false)
physicalKeys.remove(0)
shift(false, at: 1.1)
expectViet("A missing key-up inside a chord must still suppress that tap")
shift(true, at: 2); shift(false, at: 2.1)
press(18, characters: "1")
expect(document.text == "1", "The next isolated tap recovers after a chord with a missing release")

print("Passed \(checks) native document-session and Shift interaction checks.")

