import AppKit
import InputMethodKit

// InputMethodKit may create a controller for each text client. Literal ASCII is
// an input-method mode, not document state, so share it across those clients.
private enum ProcessInputMode {
    static var ascii = false
}

@objc(VietMoiInputController)
final class VietMoiInputController: IMKInputController {
    private let session = InputSession()
    override func recognizedEvents(_ sender: Any!) -> Int { session.recognizedEvents(sender) }
    override func activateServer(_ sender: Any!) {
        super.activateServer(sender)
        session.activateServer(sender)
    }
    override func deactivateServer(_ sender: Any!) {
        session.deactivateServer(sender)
        super.deactivateServer(sender)
    }
    override func commitComposition(_ sender: Any!) { session.commitComposition(sender) }
    override func hidePalettes() { session.hidePalettes() }
    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool { session.handle(event, client: sender) }
    override func mouseDown(onCharacterIndex index: Int, coordinate point: NSPoint,
                            withModifier flags: Int, continueTracking keepTracking: UnsafeMutablePointer<ObjCBool>!,
                            client sender: Any!) -> Bool {
        session.mouseDown(onCharacterIndex: index, coordinate: point, withModifier: flags, continueTracking: keepTracking, client: sender)
    }
}

// Document operations live outside IMKInputController so they can be tested with a
// protocol-conforming document; IMK itself only accepts its private client proxies.
final class InputSession {
    private let showGuide: Bool
    private let profileProvider: () -> KeyboardProfile
    private let shiftTapThreshold: () -> TimeInterval
    private let keyIsDown: (UInt16) -> Bool
    private let asciiMode: () -> Bool
    private let setASCIIMode: (Bool) -> Void
    private var currentProfile: KeyboardProfile?
    init(showGuide: Bool = true, profileProvider: @escaping () -> KeyboardProfile = { KeyboardProfiles.shared.active },
         shiftTapThreshold: @escaping () -> TimeInterval = { KeyboardPreferences.shared.shiftTapSeconds },
         keyIsDown: @escaping (UInt16) -> Bool = { CGEventSource.keyState(.combinedSessionState, key: $0) },
         asciiMode: @escaping () -> Bool = { ProcessInputMode.ascii },
         setASCIIMode: @escaping (Bool) -> Void = { ProcessInputMode.ascii = $0 }) {
        self.showGuide = showGuide
        self.profileProvider = profileProvider
        self.shiftTapThreshold = shiftTapThreshold
        self.keyIsDown = keyIsDown
        self.asciiMode = asciiMode
        self.setASCIIMode = setASCIIMode
    }
    private var engine = KeyboardEngine()
    private var history: [CommittedCycle] = []
    private var origin: NSRange?
    private var expectedSelection: NSRange?
    private var originalSelection: String = ""
    private var marked = false
    private var leftShiftDown = false
    private var rightShiftDown = false
    private var shiftTap = ShiftTapDetector()
    private var notice: String?
    private let unspecified = NSRange(location: NSNotFound, length: NSNotFound)

    func recognizedEvents(_ sender: Any!) -> Int {
        Int(NSEvent.EventTypeMask.keyDown.rawValue | NSEvent.EventTypeMask.keyUp.rawValue |
            NSEvent.EventTypeMask.flagsChanged.rawValue | NSEvent.EventTypeMask.leftMouseDown.rawValue)
    }

    func activateServer(_ sender: Any!) {
        currentProfile = profileProvider()
        engine = KeyboardEngine(outputType: currentProfile!.outputType, ascii: asciiMode())
        history.removeAll()
        origin = nil
        expectedSelection = nil
        marked = false
        resetShiftTracking()
        refresh(sender)
    }

    func deactivateServer(_ sender: Any!) {
        resetShiftTracking()
        apply(engine.cancel(), sender: sender)
        history.removeAll()
        if showGuide { KeyboardPanel.shared.hide() }
    }

    func hidePalettes() { if showGuide { KeyboardPanel.shared.hide() } }

    func commitComposition(_ sender: Any!) {
        // A host may request a composition flush between modifier events even
        // when nothing is being composed. Actual deactivation resets Shift tracking.
        // Incomplete four-key cycles are cancelled on focus/caret changes, never emitted as words.
        apply(engine.cancel(), sender: sender)
    }

    func mouseDown(onCharacterIndex index: Int, coordinate point: NSPoint,
                            withModifier flags: Int, continueTracking keepTracking: UnsafeMutablePointer<ObjCBool>!,
                            client sender: Any!) -> Bool {
        shiftTap.interrupt()
        apply(engine.cancel(), sender: sender)
        history.removeAll()
        return false
    }

    func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        guard let event = event, let client = sender as? IMKTextInput else { return false }
        if let ownID = Bundle.main.bundleIdentifier, client.bundleIdentifier() == ownID { return false }
        syncProfile(sender)
        if event.type == .leftMouseDown {
            shiftTap.interrupt()
            apply(engine.cancel(), sender: sender)
            history.removeAll()
            return false
        }
        if event.type == .keyUp {
            shiftTap.keyUp(event.keyCode)
            return false
        }
        if event.type == .keyDown { shiftTap.keyDown(event.keyCode) }
        if !marked && !engine.isPending { invalidateHistoryIfMoved(client) }
        if marked && compositionMoved(client) {
            shiftTap.interrupt()
            _ = engine.cancel()
            marked = false
            origin = nil
            expectedSelection = nil
            originalSelection = ""
            history.removeAll()
        }
        let shortcuts = event.modifierFlags.intersection([.command, .control, .option])
        if event.type == .flagsChanged {
            handleModifiers(event, sender: sender)
            // Always let the host see modifier transitions, including release.
            return false
        }
        guard event.type == .keyDown else { return false }
        let shiftHeld = event.modifierFlags.contains(.shift) || leftShiftDown || rightShiftDown
        if [51, 117].contains(event.keyCode) && shiftHeld && shortcuts.isEmpty {
            apply(engine.cancel(), sender: sender)
            history.removeAll()
            let handled = deletePreviousCycle(client)
            refresh(sender)
            return handled
        }
        if !shortcuts.isEmpty || shiftHeld {
            apply(engine.cancel(), sender: sender)
            history.removeAll()
            refresh(sender)
            return false
        }
        if event.keyCode == 53 {
            let pending = engine.isPending
            apply(engine.cancel(), sender: sender)
            refresh(sender)
            return pending
        }
        if event.keyCode == 51 {
            if engine.isPending {
                apply(engine.backspace(), sender: sender)
                refresh(sender)
                return true
            }
            history.removeAll()
            return false
        }
        if currentProfile?.inputType == .asciiPlus && event.keyCode == 117 && !engine.ascii {
            apply(engine.clearCycle(), sender: sender)
            refresh(sender)
            return true
        }
        if [36,48,76,117,123,124,125,126,115,119,116,121].contains(event.keyCode) {
            apply(engine.cancel(), sender: sender)
            history.removeAll()
            refresh(sender)
            return false
        }
        if engine.ascii {
            guard let text = event.characters,
                  !text.isEmpty, text.unicodeScalars.allSatisfy({ $0.value >= 32 && $0.value <= 126 }) else { return false }
            commit(text, client: client)
            refresh(sender)
            return true
        }
        let asciiPlusMode = currentProfile?.inputType == .asciiPlus
        if asciiPlusMode {
            guard ASCIIPlusMapping.inputKeyCodes.contains(event.keyCode) else {
                passThrough(sender)
                return false
            }
        } else if GridKey.index(keyCode: event.keyCode) == nil {
            passThrough(sender)
            return false
        }
        if event.isARepeat { return true }
        let wasPending = engine.isPending
        let effect: EngineEffect
        if asciiPlusMode {
            guard let value = ASCIIPlusMapping.bindings(for: engine.phase)[event.keyCode] else {
                refresh(sender, message: "Choose a highlighted key, or tap Shift for literal ASCII")
                return true
            }
            effect = engine.selectComponent(value)
        } else {
            let index = GridKey.index(keyCode: event.keyCode)!
            guard index != 24 else {
                refresh(sender, message: "Choose a highlighted key, or tap Shift for ASCII")
                return true
            }
            effect = engine.press(index)
        }
        if !wasPending && engine.isPending { beginComposition(client) }
        apply(effect, sender: sender)
        refresh(sender)
        return true
    }

    private func passThrough(_ sender: Any!) {
        apply(engine.cancel(), sender: sender)
        history.removeAll()
        refresh(sender)
    }

    private func resetShiftTracking() {
        leftShiftDown = false
        rightShiftDown = false
        shiftTap.reset()
    }

    private func handleModifiers(_ event: NSEvent, sender: Any!) {
        // Device-dependent flags from IOLLEvent.h: NX_DEVICELSHIFTKEYMASK (2)
        // and NX_DEVICERSHIFTKEYMASK (4). Aggregate .shift stays set when one
        // Shift is released while the other is held.
        let sideFlags = event.modifierFlags.rawValue & 0x6
        let anyShift = event.modifierFlags.contains(.shift)
        if event.keyCode == 60 {
            rightShiftDown = sideFlags != 0 ? sideFlags & 0x4 != 0 : anyShift && !rightShiftDown
            shiftTap.interrupt()
            return
        }
        guard event.keyCode == 56 else { shiftTap.interrupt(); return }
        let down = sideFlags != 0 ? sideFlags & 0x2 != 0 : anyShift && (!rightShiftDown || !leftShiftDown)
        let otherModifiers = !event.modifierFlags.intersection([.command, .control, .option, .function]).isEmpty
        if otherModifiers || rightShiftDown { shiftTap.interrupt() }
        if down && !leftShiftDown {
            shiftTap.press(at: event.timestamp, threshold: shiftTapThreshold(),
                           isolated: !otherModifiers && !rightShiftDown, isKeyDown: keyIsDown)
        } else if !down && leftShiftDown {
            if shiftTap.release(at: event.timestamp) {
                apply(engine.press(24), sender: sender)
                setASCIIMode(engine.ascii)
                refresh(sender)
            }
        }
        leftShiftDown = down
    }

    private func beginComposition(_ client: IMKTextInput) {
        let selection = client.selectedRange()
        origin = selection.location == NSNotFound ? nil : selection
        expectedSelection = origin
        originalSelection = selection.length > 0 ? client.attributedSubstring(from: selection)?.string ?? "" : ""
    }

    private func syncProfile(_ sender: Any!) {
        let profile = profileProvider()
        guard profile != currentProfile else { return }
        apply(engine.cancel(), sender: sender)
        shiftTap.interrupt()
        engine = KeyboardEngine(outputType: profile.outputType, ascii: engine.ascii)
        history.removeAll()
        currentProfile = profile
    }

    private func compositionMoved(_ client: IMKTextInput) -> Bool {
        // Some clients cache markedRange across IME restarts. Compare our last observed
        // selection instead; unavailable document access is not evidence of movement.
        guard let expected = expectedSelection else { return false }
        let selection = client.selectedRange()
        guard selection.location != NSNotFound else { return false }
        return selection != expected
    }

    private func apply(_ effect: EngineEffect, sender: Any!) {
        guard let client = sender as? IMKTextInput else { return }
        switch effect {
        case .marked(let text):
            // Avoid replacing a selection merely to display an empty onset.
            if !text.isEmpty || marked {
                let visible = text.isEmpty ? originalSelection : text
                client.setMarkedText(visible, selectionRange: NSRange(location: visible.utf16.count, length: 0), replacementRange: unspecified)
                marked = !visible.isEmpty
                expectedSelection = client.selectedRange()
            }
        case .commit(let text): commit(text, client: client)
        case .cancel:
            if marked && !compositionMoved(client) {
                client.insertText(originalSelection, replacementRange: unspecified)
            }
            marked = false
            origin = nil
            expectedSelection = nil
            originalSelection = ""
        case .deleteCycle:
            guard let cycle = history.last,
                  cycle.canDelete(selection: client.selectedRange(), actualText: client.attributedSubstring(from: cycle.range)?.string) else {
                history.removeAll()
                notice = "No recent cycle at this caret · use Backspace for ordinary text"
                return
            }
            client.insertText("", replacementRange: cycle.range)
            history.removeLast()
        case .none: break
        }
    }

    private func commit(_ text: String, client: IMKTextInput) {
        let start = origin?.location ?? client.selectedRange().location
        client.insertText(text, replacementRange: unspecified)
        marked = false
        origin = nil
        expectedSelection = nil
        originalSelection = ""
        let range = NSRange(location: start, length: text.utf16.count)
        // IMK may acknowledge insertText before selectedRange reflects the commit.
        // Record a candidate now; validate both its caret and text on the next action.
        if start != NSNotFound {
            history.append(CommittedCycle(text: text, range: range))
            if history.count > 128 { history.removeFirst() }
        } else { history.removeAll() }
    }

    private func invalidateHistoryIfMoved(_ client: IMKTextInput) {
        guard let last = history.last else { return }
        if client.selectedRange() != NSRange(location: NSMaxRange(last.range), length: 0) {
            history.removeAll()
        }
    }

    private func deletePreviousCycle(_ client: IMKTextInput) -> Bool {
        let selection = client.selectedRange()
        guard selection.location != NSNotFound, selection.length == 0, selection.location > 0 else { return false }
        let caret = selection.location
        var window = min(caret, 64)

        while true {
            let start = caret - window
            guard let text = documentText(client, range: NSRange(location: start, length: window)) else {
                return false
            }
            let characters = Array(text)
            var cursor = characters.count
            while cursor > 0 && characters[cursor - 1] == " " { cursor -= 1 }
            let alphaEnd = cursor
            while cursor > 0 && characters[cursor - 1].unicodeScalars.contains(where: { $0.properties.isAlphabetic }) {
                cursor -= 1
            }

            // Shift+Backspace only owns the event when the immediate left side
            // is a word or spaces that trail a word. Otherwise macOS retains its
            // ordinary Backspace behavior.
            let immediateIsSpace = characters.last == " "
            let immediateIsAlpha = characters.last?.unicodeScalars.contains(where: { $0.properties.isAlphabetic }) == true
            guard immediateIsSpace || immediateIsAlpha else { return false }

            if cursor < alphaEnd {
                // If the potential left boundary is exactly the first character
                // in this window, expand once so a split composed character or a
                // longer word cannot be mistaken for the boundary.
                if cursor == 0 && start > 0 {
                    window = min(caret, window * 2)
                    continue
                }
                // Include the single separator space immediately before the
                // cycle, matching "abc nmq   |" -> "abc|".
                if cursor > 0 && characters[cursor - 1] == " " { cursor -= 1 }
                let removed = String(characters[cursor...]).utf16.count
                client.insertText("", replacementRange: NSRange(location: caret - removed, length: removed))
                return true
            }

            // Spaces without a reachable word are still a handled no-op: there
            // is no previous cycle, so do not let the host erase one space.
            if start == 0 { return true }
            if cursor == 0 {
                window = min(caret, window * 2)
                continue
            }
            return true
        }
    }

    private func documentText(_ client: IMKTextInput, range: NSRange) -> String? {
        if let text = client.attributedSubstring(from: range)?.string { return text }
        var actual = NSRange(location: NSNotFound, length: 0)
        guard let text = client.string(from: range, actualRange: &actual), actual == range else { return nil }
        return text
    }

    private func refresh(_ sender: Any!, message: String? = nil) {
        guard showGuide else { return }
        // Literal ASCII needs no guide. Keep the screen completely clear until
        // the next isolated Shift tap returns to Vietnamese input.
        if engine.ascii {
            KeyboardPanel.shared.hide()
            notice = nil
            return
        }
        var rect = NSRect.zero
        if let client = sender as? IMKTextInput {
            _ = client.attributes(forCharacterIndex: 0, lineHeightRectangle: &rect)
        }
        KeyboardPanel.shared.show(engine: engine, caret: rect.height > 0 ? rect : nil, message: message ?? notice,
                                  inputType: (currentProfile ?? profileProvider()).inputType,
                                  asciiActions: ASCIIPlusMapping.actions(for: engine),
                                  showKeyboard: (currentProfile ?? profileProvider()).showVirtualKeyboard)
        notice = nil
    }
}
