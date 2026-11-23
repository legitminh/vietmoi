import AppKit
import InputMethodKit
import os

// InputMethodKit may create a controller for each text client. The selected
// keyboard is shared app state (KeyboardProfiles), not document state.

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
    override func didCommand(by selector: Selector!, client sender: Any!) -> Bool {
        guard let selector = selector else { return false }
        return session.command(selector, client: sender)
    }
    override func composedString(_ sender: Any!) -> Any! { session.compositionText }
    override func originalString(_ sender: Any!) -> NSAttributedString! { session.originalText }
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
    private let literalMode: () -> Bool
    private let nextKeyboard: () -> Void
    private var currentProfile: KeyboardProfile?
    init(showGuide: Bool = true, profileProvider: @escaping () -> KeyboardProfile = { KeyboardProfiles.shared.active },
         shiftTapThreshold: @escaping () -> TimeInterval = { KeyboardPreferences.shared.shiftTapSeconds },
         // The combined table includes synthetic/TSM events: selection deletion can
         // leave Delete logically down there long after the hardware released it.
         keyIsDown: @escaping (UInt16) -> Bool = { CGEventSource.keyState(.hidSystemState, key: $0) },
         // An English keyboard types literal text through the engine's literal mode.
         literalMode: @escaping () -> Bool = { KeyboardProfiles.shared.active.isLiteral },
         // A left Shift tap moves to the next keyboard in the list.
         nextKeyboard: @escaping () -> Void = { KeyboardProfiles.shared.selectNext() }) {
        self.showGuide = showGuide
        self.profileProvider = profileProvider
        self.shiftTapThreshold = shiftTapThreshold
        self.keyIsDown = keyIsDown
        self.literalMode = literalMode
        self.nextKeyboard = nextKeyboard
    }
    private var engine = KeyboardEngine()
    private var history: [CommittedCycle] = []
    private var keymap: ASCIIPlusKeymap { currentProfile?.asciiPlusKeymap ?? .sieuviet }
    private var origin: NSRange?
    private var expectedSelection: NSRange?
    private var originalSelection: String = ""
    var compositionText: String { engine.preview }
    var originalText: NSAttributedString { NSAttributedString(string: originalSelection) }
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
        traceShift("activate", sender: sender)
        currentProfile = profileProvider()
        engine = KeyboardEngine(outputType: currentProfile!.outputType, ascii: literalMode())
        history.removeAll()
        origin = nil
        expectedSelection = nil
        originalSelection = ""
        marked = false
        resetShiftTracking()
        refresh(sender)
    }

    func deactivateServer(_ sender: Any!) {
        traceShift("deactivate", sender: sender)
        resetShiftTracking()
        apply(engine.finishPartial(), sender: sender)
        history.removeAll()
        if showGuide { KeyboardPanel.shared.hide() }
    }

    func hidePalettes() { if showGuide { KeyboardPanel.shared.hide() } }

    func commitComposition(_ sender: Any!) {
        traceShift("commit", sender: sender)
        // A host may request a composition flush between modifier events even
        // when nothing is being composed. Actual deactivation resets Shift tracking.
        // A host-requested flush preserves abbreviations, without adding a space.
        apply(engine.finishPartial(), sender: sender)
    }

    func mouseDown(onCharacterIndex index: Int, coordinate point: NSPoint,
                            withModifier flags: Int, continueTracking keepTracking: UnsafeMutablePointer<ObjCBool>!,
                            client sender: Any!) -> Bool {
        shiftTap.interrupt()
        apply(engine.finishPartial(), sender: sender)
        history.removeAll()
        return false
    }

    func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        guard let event = event, let client = sender as? IMKTextInput else { return false }
        if let ownID = Bundle.main.bundleIdentifier, client.bundleIdentifier() == ownID { return false }
        if event.type == .flagsChanged || event.type == .leftMouseDown ||
           ([51,117,123,124,125,126].contains(event.keyCode) && (event.type == .keyDown || event.type == .keyUp)) {
            traceShift("event", event: event, sender: sender)
        }
        syncProfile(sender)
        reconcileShiftState(event)
        if event.type == .leftMouseDown {
            shiftTap.interrupt()
            apply(engine.finishPartial(), sender: sender)
            history.removeAll()
            return false
        }
        if event.type == .keyUp {
            shiftTap.keyUp(event.keyCode)
            return false
        }
        if event.type == .keyDown { shiftTap.keyDown(event.keyCode) }
        if !marked && !engine.isPending { invalidateHistoryIfMoved(client) }
        let shortcuts = event.modifierFlags.intersection([.command, .control, .option])
        if event.type == .flagsChanged {
            handleModifiers(event, sender: sender)
            // Always let the host see modifier transitions, including release.
            return false
        }
        guard event.type == .keyDown else { return false }
        discardMovedComposition(client)
        let shiftHeld = event.modifierFlags.contains(.shift) || leftShiftDown || rightShiftDown ||
                        keyIsDown(56) || keyIsDown(60)
        if [51, 117].contains(event.keyCode) && client.selectedRange().length > 0 &&
           !ownsCompositionSelection(client) && shortcuts.isEmpty {
            // An explicit selection belongs to the host, including forward Delete
            // in ASCII+. Cycle clearing must never swallow selected-text deletion.
            apply(engine.cancel(), sender: sender)
            history.removeAll()
            refresh(sender)
            return false
        }
        if [51, 117].contains(event.keyCode) && shiftHeld && shortcuts.isEmpty {
            apply(engine.cancel(), sender: sender)
            let handled = deletePreviousCycle(client)
            history.removeAll()
            refresh(sender)
            return handled
        }
        if !shortcuts.isEmpty || shiftHeld {
            apply(engine.finishPartial(), sender: sender)
            history.removeAll()
            refresh(sender)
            return false
        }
        if event.keyCode == 49 && !engine.ascii && engine.isPending {
            return finishWithSpace(sender)
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
            apply(engine.finishPartial(), sender: sender)
            history.removeAll()
            refresh(sender)
            return false
        }
        // Command keycodes above retain native command handling. A malformed or
        // remapped non-command event must never fall through as literal C0/C1 text.
        if let text = event.characters, text.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) {
            passThrough(sender)
            return true
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
            guard ASCIIPlusMapping.inputKeyCodes(for: engine.phase, inventory: engine.inventory, keymap: keymap).contains(event.keyCode) else {
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
            guard let value = ASCIIPlusMapping.bindings(for: engine.phase, inventory: engine.inventory, keymap: keymap)[event.keyCode] else {
                refresh(sender, message: AppCopy.text("unmappedKeyHelp"))
                return true
            }
            effect = engine.selectComponent(value)
        } else {
            let index = GridKey.index(keyCode: event.keyCode)!
            guard index != 24 else {
                refresh(sender, message: AppCopy.text("unmappedKeyHelp"))
                return true
            }
            effect = engine.press(index)
        }
        if !wasPending && engine.isPending { beginComposition(client) }
        apply(effect, sender: sender)
        refresh(sender)
        return true
    }

    private func finishWithSpace(_ sender: Any!) -> Bool {
        guard engine.isPending else { return false }
        let hasText = !engine.preview.isEmpty
        apply(engine.finishPartial(suffix: " "), sender: sender)
        refresh(sender)
        // Empty optional initials leave ordinary Space/selection behavior to the host.
        return hasText
    }

    // Some hosts deliver responder commands instead of raw editing key events.
    // Own Backspace while composing so it always undoes the current round.
    private enum EditingCommand: String {
        case backward = "deleteBackward:", decomposingBackward = "deleteBackwardByDecomposingPreviousCharacter:"
        case space = "insertSpace:", cancel = "cancelOperation:"
        case newline = "insertNewline:", lineBreak = "insertLineBreak:", tab = "insertTab:", backtab = "insertBacktab:"
        case left = "moveLeft:", right = "moveRight:", up = "moveUp:", down = "moveDown:"
        case selectLeft = "moveLeftAndModifySelection:", selectRight = "moveRightAndModifySelection:"
        case selectUp = "moveUpAndModifySelection:", selectDown = "moveDownAndModifySelection:"
    }

    func command(_ selector: Selector, client sender: Any!) -> Bool {
        guard let client = sender as? IMKTextInput,
              let command = EditingCommand(rawValue: NSStringFromSelector(selector)) else { return false }
        if let ownID = Bundle.main.bundleIdentifier, client.bundleIdentifier() == ownID { return false }
        syncProfile(sender)
        discardMovedComposition(client)
        switch command {
        case .backward, .decomposingBackward:
            shiftTap.interrupt()
            if marked && compositionMoved(client) { return false }
            if client.selectedRange().location != NSNotFound && client.selectedRange().length > 0 && !ownsCompositionSelection(client) { return false }
            if keyIsDown(56) || keyIsDown(60) {
                apply(engine.cancel(), sender: sender)
                let handled = deletePreviousCycle(client)
                history.removeAll()
                refresh(sender)
                return handled
            }
            guard engine.isPending else { return false }
            apply(engine.backspace(), sender: sender)
            refresh(sender)
            return true
        case .space:
            shiftTap.interrupt()
            return finishWithSpace(sender)
        case .newline, .lineBreak, .tab, .backtab, .left, .right, .up, .down,
             .selectLeft, .selectRight, .selectUp, .selectDown:
            shiftTap.interrupt()
            apply(engine.finishPartial(), sender: sender)
            refresh(sender)
            return false
        case .cancel:
            shiftTap.interrupt()
            let pending = engine.isPending
            apply(engine.cancel(), sender: sender)
            refresh(sender)
            return pending
        }
    }

    private func passThrough(_ sender: Any!) {
        apply(engine.finishPartial(), sender: sender)
        history.removeAll()
        refresh(sender)
    }

    // Opt-in diagnostics contain only editing/modifier metadata, never text or printable keycodes.
    private static let shiftLogger = Logger(subsystem: "com.minh.inputmethod.VietMoi", category: "ShiftDiagnostics")
    private func traceShift(_ reason: String, event: NSEvent? = nil, sender: Any!) {
        guard UserDefaults.standard.bool(forKey: "shiftDiagnostics") else { return }
        let type = event.map { Int($0.type.rawValue) } ?? -1
        let key = event.map { Int($0.keyCode) } ?? -1
        let flags = event?.modifierFlags.rawValue ?? 0
        let selectionLength = (sender as? IMKTextInput)?.selectedRange().length ?? 0
        let logicalDelete = CGEventSource.keyState(.combinedSessionState, key: 51)
        let hardwareDelete = CGEventSource.keyState(.hidSystemState, key: 51)
        Self.shiftLogger.notice("logicalDelete=\(logicalDelete) hardwareDelete=\(hardwareDelete) reason=\(reason, privacy: .public) type=\(type) key=\(key) flags=\(flags) cachedL=\(self.leftShiftDown) cachedR=\(self.rightShiftDown) physicalL=\(self.keyIsDown(56)) physicalR=\(self.keyIsDown(60)) ascii=\(self.engine.ascii) marked=\(self.marked) selected=\(selectionLength)")
    }

    private func resetShiftTracking() {
        leftShiftDown = false
        rightShiftDown = false
        shiftTap.reset()
    }

    private func reconcileShiftState(_ event: NSEvent) {
        guard event.type == .keyDown || event.type == .keyUp || event.type == .leftMouseDown else { return }
        // Selection/deletion clients may omit flagsChanged releases. A later
        // unshifted event plus released physical keys is evidence that cached
        // modifier state is stale, not that Shift is still being held.
        if !event.modifierFlags.contains(.shift) && !keyIsDown(56) && !keyIsDown(60) &&
           (leftShiftDown || rightShiftDown) {
            resetShiftTracking()
        }
    }

    private func handleModifiers(_ event: NSEvent, sender: Any!) {
        let wasLeftDown = leftShiftDown
        // Device-dependent flags identify BOTH sides, not just the key named by
        // this event. Always reconcile the other side too after a missed release.
        let sideFlags = event.modifierFlags.rawValue & 0x6
        let anyShift = event.modifierFlags.contains(.shift)
        if sideFlags != 0 {
            leftShiftDown = sideFlags & 0x2 != 0
            rightShiftDown = sideFlags & 0x4 != 0
        } else if !anyShift {
            leftShiftDown = false
            rightShiftDown = false
        } else if event.keyCode == 56 {
            rightShiftDown = keyIsDown(60)
            leftShiftDown = keyIsDown(56) || !rightShiftDown
        } else if event.keyCode == 60 {
            leftShiftDown = keyIsDown(56)
            rightShiftDown = keyIsDown(60) || !leftShiftDown
        }
        let otherModifiers = !event.modifierFlags.intersection([.command, .control, .option, .function]).isEmpty
        if otherModifiers || rightShiftDown || event.keyCode != 56 { shiftTap.interrupt() }
        if leftShiftDown && !wasLeftDown {
            shiftTap.press(at: event.timestamp, threshold: shiftTapThreshold(),
                           isolated: event.keyCode == 56 && !otherModifiers && !rightShiftDown, isKeyDown: keyIsDown)
        } else if !leftShiftDown && wasLeftDown {
            if shiftTap.release(at: event.timestamp) {
                apply(engine.finishPartial(), sender: sender)
                nextKeyboard()
                currentProfile = profileProvider()
                engine = KeyboardEngine(outputType: currentProfile!.outputType, ascii: literalMode())
                refresh(sender)
            }
        }
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
        engine = KeyboardEngine(outputType: profile.outputType, ascii: literalMode())
        history.removeAll()
        currentProfile = profile
    }

    private func discardMovedComposition(_ client: IMKTextInput) {
        guard marked && compositionMoved(client) else { return }
        shiftTap.interrupt()
        _ = engine.cancel()
        marked = false
        origin = nil
        expectedSelection = nil
        originalSelection = ""
        history.removeAll()
    }

    private func ownsCompositionSelection(_ client: IMKTextInput) -> Bool {
        guard marked, let origin = origin, let expected = expectedSelection,
              expected.location >= origin.location else { return false }
        let owned = NSRange(location: origin.location, length: expected.location - origin.location)
        guard client.markedRange() == owned else { return false }
        let selection = client.selectedRange()
        // The host may still report the selection from before setMarkedText.
        // Accept it only when its live marked range confirms ownership.
        return selection == origin || (selection.length == 0 && selection.location >= owned.location && selection.location <= NSMaxRange(owned))
    }

    private func compositionMoved(_ client: IMKTextInput) -> Bool {
        // Some clients cache markedRange across IME restarts. Compare our last observed
        // selection instead; unavailable document access is not evidence of movement.
        guard let expected = expectedSelection else { return false }
        let selection = client.selectedRange()
        guard selection.location != NSNotFound else { return false }
        return selection != expected && !ownsCompositionSelection(client)
    }

    private func apply(_ effect: EngineEffect, sender: Any!) {
        guard let client = sender as? IMKTextInput else { return }
        switch effect {
        case .marked(let text):
            guard CompositionText.isSafe(text) else {
                apply(engine.cancel(), sender: sender)
                return
            }
            // Avoid replacing a selection merely to display an empty onset.
            if !text.isEmpty || marked {
                let visible = text.isEmpty ? originalSelection : text
                let underlined = NSAttributedString(string: visible, attributes: [
                    .underlineStyle: NSUnderlineStyle.single.rawValue
                ])
                client.setMarkedText(underlined, selectionRange: NSRange(location: visible.utf16.count, length: 0), replacementRange: unspecified)
                marked = !visible.isEmpty
                // IMK can return the old caret immediately after setMarkedText.
                // Predict the caret from the range we just sent, rather than
                // mistaking the later acknowledgement for a user selection move.
                expectedSelection = origin.map { NSRange(location: $0.location + visible.utf16.count, length: 0) }
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
        guard CompositionText.isSafe(text) else { return }
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
            history.append(CommittedCycle(text: text, range: range, basis: engine.ascii ? nil : engine.lastCommittedBasis))
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
        guard selection.location != NSNotFound, selection.length == 0, selection.location > 0 else {
            return deletePreviousCycleFromHistory(client, caret: history.last.map { NSMaxRange($0.range) })
        }
        let caret = selection.location
        var window = min(caret, 64)

        while true {
            let start = caret - window
            guard let text = documentText(client, range: NSRange(location: start, length: window)) else {
                return deletePreviousCycleFromHistory(client, caret: caret)
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

    private func deletePreviousCycleFromHistory(_ client: IMKTextInput, caret: Int?) -> Bool {
        guard let caret = caret, caret > 0 else { return false }
        var expectedEnd = caret
        var pieces: [String] = []
        for cycle in history.reversed() {
            guard NSMaxRange(cycle.range) == expectedEnd else { break }
            pieces.append(cycle.text)
            expectedEnd = cycle.range.location
        }
        let text = pieces.reversed().joined()
        guard !text.isEmpty else { return false }
        let characters = Array(text)
        var cursor = characters.count
        while cursor > 0 && characters[cursor - 1] == " " { cursor -= 1 }
        let alphaEnd = cursor
        while cursor > 0 && characters[cursor - 1].unicodeScalars.contains(where: { $0.properties.isAlphabetic }) {
            cursor -= 1
        }
        let immediateIsSpace = characters.last == " "
        let immediateIsAlpha = characters.last?.unicodeScalars.contains(where: { $0.properties.isAlphabetic }) == true
        guard immediateIsSpace || immediateIsAlpha else { return false }
        guard cursor < alphaEnd else { return true }
        if cursor > 0 && characters[cursor - 1] == " " { cursor -= 1 }
        let removed = String(characters[cursor...]).utf16.count
        client.insertText("", replacementRange: NSRange(location: caret - removed, length: removed))
        return true
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
                                  asciiActions: ASCIIPlusMapping.actions(for: engine, keymap: keymap),
                                  showKeyboard: (currentProfile ?? profileProvider()).showVirtualKeyboard)
        notice = nil
    }
}
