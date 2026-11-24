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
    private let switchKeyboard: () -> Void
    private let englishWords: (String) -> [String]
    private var chinese: ShuangpinEngine
    private var currentProfile: KeyboardProfile?
    private var predictionRequest: Operation?
    private var chineseRequest: Operation?
    private var predictionKey: String?
    private var chinesePredictionKey: String?
    private var cachedSuggestions: [String] = []
    private let submitCompletion: CompletionSubmit
    init(showGuide: Bool = true, profileProvider: @escaping () -> KeyboardProfile = { KeyboardProfiles.shared.active },
         shiftTapThreshold: @escaping () -> TimeInterval = { KeyboardPreferences.shared.shiftTapSeconds },
         // The combined table includes synthetic/TSM events: selection deletion can
         // leave Delete logically down there long after the hardware released it.
         keyIsDown: @escaping (UInt16) -> Bool = { CGEventSource.keyState(.hidSystemState, key: $0) },
         switchKeyboard: @escaping () -> Void = { KeyboardProfiles.shared.selectNext() },
         chineseDictionary: ShuangpinDictionary = .shared,
         submitCompletion: @escaping CompletionSubmit = CompletionScheduler.submit,
         englishWords: @escaping (String) -> [String] = { prefix in
             NSSpellChecker.shared.completions(forPartialWordRange: NSRange(location: 0, length: prefix.utf16.count),
                                               in: prefix, language: "en_US", inSpellDocumentWithTag: 0) ?? []
         }) {
        self.showGuide = showGuide
        self.profileProvider = profileProvider
        self.shiftTapThreshold = shiftTapThreshold
        self.keyIsDown = keyIsDown
        self.switchKeyboard = switchKeyboard
        self.englishWords = englishWords
        self.submitCompletion = submitCompletion
        self.chinese = ShuangpinEngine(dictionary: chineseDictionary)
    }
    private var engine = KeyboardEngine()
    private var history: [CommittedCycle] = []
    /// The automatic Vietnamese block (or adaptive rewrite) just committed; see AdaptivePunctuation.
    private var adaptiveTail: String?
    private var adaptive: Bool {
        currentProfile?.language == .vietnamese && !engine.ascii && currentProfile?.adaptivePunctuation != false
    }
    private var keymap: ASCIIPlusKeymap { engine.inputMode == .sieuviet ? (currentProfile?.asciiPlusKeymap ?? .sieuviet) : engine.keymap }
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
        engine = KeyboardEngine(outputType: currentProfile!.outputType, ascii: currentProfile!.language == .english, inputMode: currentProfile!.inputMode)
        _ = chinese.cancel()
        chinese.completionsEnabled = currentProfile?.suggestionsEnabled == true
        history.removeAll()
        origin = nil
        expectedSelection = nil
        originalSelection = ""
        marked = false
        resetShiftTracking()
        refresh(sender)
    }

    func deactivateServer(_ sender: Any!) {
        invalidateSuggestions()
        traceShift("deactivate", sender: sender)
        resetShiftTracking()
        finishComposition(sender)
        history.removeAll()
        if showGuide { KeyboardPanel.shared.hide() }
    }

    func hidePalettes() { invalidateSuggestions(); if showGuide { KeyboardPanel.shared.hide() } }

    func commitComposition(_ sender: Any!) {
        traceShift("commit", sender: sender)
        // A host may request a composition flush between modifier events even
        // when nothing is being composed. Actual deactivation resets Shift tracking.
        // A host-requested flush preserves abbreviations, without adding a space.
        finishComposition(sender)
    }

    func mouseDown(onCharacterIndex index: Int, coordinate point: NSPoint,
                            withModifier flags: Int, continueTracking keepTracking: UnsafeMutablePointer<ObjCBool>!,
                            client sender: Any!) -> Bool {
        shiftTap.interrupt()
        finishComposition(sender)
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
            finishComposition(sender)
            history.removeAll()
            return false
        }
        if event.type == .keyUp {
            shiftTap.keyUp(event.keyCode)
            return false
        }
        if event.type == .keyDown { shiftTap.keyDown(event.keyCode) }
        if !marked && !isPending { invalidateHistoryIfMoved(client) }
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
        // Adaptive punctuation: any key ends the automatic block; a phrase mark that the
        // keyboard would pass through to the app replaces its space ("quá " + "!" → "quá! ").
        let tail = adaptiveTail
        adaptiveTail = nil
        if let tail = tail, shortcuts.isEmpty, !engine.isPending, let text = event.characters,
           let rewrite = AdaptivePunctuation.rewrite(tail: tail, typing: text),
           shiftHeld || !routesToEngine(event.keyCode), replaceAdaptiveTail(tail, with: rewrite, client: client) {
            refresh(sender)
            return true
        }
        if [51, 117].contains(event.keyCode) && client.selectedRange().length > 0 &&
           !ownsCompositionSelection(client) && shortcuts.isEmpty {
            // An explicit selection belongs to the host, including forward Delete
            // in ASCII+. Cycle clearing must never swallow selected-text deletion.
            cancelComposition(sender)
            history.removeAll()
            refresh(sender)
            return false
        }
        if [51, 117].contains(event.keyCode) && shiftHeld && shortcuts.isEmpty {
            cancelComposition(sender)
            let handled = deletePreviousCycle(client)
            history.removeAll()
            refresh(sender)
            return handled
        }
        if !shortcuts.isEmpty || shiftHeld {
            finishComposition(sender)
            history.removeAll()
            refresh(sender)
            return false
        }
        if currentProfile?.language == .chinese { return handleChinese(event, client: client) }
        // Tab (or a number key on ASCII+) accepts a suggestion; Space only types a space.
        if event.keyCode == 48, currentProfile?.language != .chinese, event.modifierFlags.intersection([.shift, .command, .control, .option]).isEmpty,
           !suggestions(client).isEmpty {
            return acceptSuggestion(0, client: client)
        }
        if currentProfile?.suggestionsEnabled == true, currentProfile?.language == .vietnamese, currentProfile?.inputType == .asciiPlus, !engine.ascii,
           let index = [18,19,20,21,23,22,26,28,25].firstIndex(of: Int(event.keyCode)),
           suggestions(client).indices.contains(index) {
            return acceptSuggestion(index, client: client)
        }
        if event.keyCode == 49 && !engine.ascii && engine.isPending {
            return finishWithSpace(sender)
        }
        if event.keyCode == 53 {
            let pending = engine.isPending
            cancelComposition(sender)
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
            finishComposition(sender)
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

    private func finishComposition(_ sender: Any!) {
        if currentProfile?.language == .chinese { cancelComposition(sender) }
        else { apply(engine.finishPartial(), sender: sender) }
    }

    private var isPending: Bool { engine.isPending || chinese.isPending }

    private func cancelComposition(_ sender: Any!) {
        let pending = isPending
        _ = engine.cancel()
        _ = chinese.cancel()
        if pending || marked { apply(.cancel, sender: sender) }
    }

    private func handleChinese(_ event: NSEvent, client: IMKTextInput) -> Bool {
        let key = event.keyCode
        if key == 53 {
            let pending = chinese.isPending
            cancelComposition(client)
            refresh(client)
            return pending
        }
        if key == 51 {
            guard chinese.isPending else { history.removeAll(); return false }
            apply(chinese.backspace(), sender: client)
            refresh(client)
            return true
        }
        if chinese.isPending {
            if [125, 126, 116, 121].contains(key) {
                let delta = key == 125 ? 1 : key == 126 ? -1 : key == 121 ? 9 : -9
                chinese.moveSelection(delta)
                refresh(client)
                return true
            }
            if let digit = ASCIIKeyboardLayout.keys.first(where: { $0.keyCode == key })?.label,
               let number = Int(digit), (1...9).contains(number) {
                apply(chinese.choose(number), sender: client)
                refresh(client)
                return true
            }
            if key == 49 || key == 36 || key == 76 {
                // Return explicitly preserves raw input when no candidate exists.
                apply(chinese.choose(literal: (key == 36 || key == 76) && chinese.selected == nil), sender: client)
                refresh(client)
                return true
            }
        }
        if let label = ASCIIKeyboardLayout.keys.first(where: { $0.keyCode == key })?.label,
           label.count == 1, "abcdefghijklmnopqrstuvwxyz;".contains(label),
           label != ";" || chinese.code.count % 2 == 1 {
            if event.isARepeat { return true }
            let pending = chinese.isPending
            let effect = chinese.append(label)
            if !pending && chinese.isPending { beginComposition(client) }
            apply(effect, sender: client)
            refresh(client)
            return true
        }
        if [48, 117, 123, 124, 115, 119].contains(key) {
            passThrough(client)
            return false
        }
        // Punctuation commits the current candidate and then reaches the host.
        if chinese.isPending {
            apply(chinese.choose(literal: chinese.selected == nil), sender: client)
        }
        history.removeAll()
        refresh(client)
        return false
    }

    /// Whether a key types into the Vietnamese engine (otherwise it reaches the app).
    private func routesToEngine(_ keyCode: UInt16) -> Bool {
        if currentProfile?.inputType == .asciiPlus {
            return ASCIIPlusMapping.inputKeyCodes(for: engine.phase, inventory: engine.inventory, keymap: keymap).contains(keyCode)
        }
        return GridKey.index(keyCode: keyCode) != nil
    }
    /// Replace the verified block before the caret with its adaptive rewrite.
    private func replaceAdaptiveTail(_ tail: String, with text: String, client: IMKTextInput) -> Bool {
        let selection = client.selectedRange(), length = tail.utf16.count
        guard selection.location != NSNotFound, selection.length == 0, selection.location >= length else { return false }
        let range = NSRange(location: selection.location - length, length: length)
        guard client.attributedSubstring(from: range)?.string == tail else { return false }
        client.insertText(text, replacementRange: range)
        history.removeAll()
        adaptiveTail = text
        return true
    }

    private func finishWithSpace(_ sender: Any!) -> Bool {
        guard engine.isPending else { return false }
        let hasText = !engine.preview.isEmpty
        apply(engine.finishPartial(suffix: " "), sender: sender)
        // A typed space is the writer's own: only a completed block's automatic space adapts.
        adaptiveTail = nil
        refresh(sender)
        // Empty optional initials leave ordinary Space/selection behavior to the host.
        return hasText
    }

    private func invalidateSuggestions() {
        predictionRequest?.cancel(); chineseRequest?.cancel()
        predictionKey = nil; chinesePredictionKey = nil
        cachedSuggestions = []
    }

    private func suggestions(_ client: IMKTextInput) -> [String] {
        guard currentProfile?.suggestionsEnabled == true, currentProfile?.language != .chinese else {
            predictionRequest?.cancel(); predictionKey = nil; cachedSuggestions = []
            return []
        }
        let selection = client.selectedRange()
        guard selection.location != NSNotFound, selection.length == 0 else { return [] }
        let count = min(256, selection.location)
        let context = documentText(client, range: NSRange(location: selection.location - count, length: count)) ?? ""
        let prefix = engine.preview
        let language = currentProfile!.language
        let key = "\(currentProfile!.id):\(selection.location):\(prefix):\(context)"
        guard key != predictionKey else { return cachedSuggestions }
        predictionRequest?.cancel()
        predictionKey = key
        cachedSuggestions = []
        let complete = englishWords
        predictionRequest = submitCompletion({
            language == .english ? EnglishCompletion.suffixes(context: context, complete: complete)
                : VietnamesePredictionEngine.suggestions(context: context, prefix: prefix, limit: 9).map(\.suffix)
        }, { [weak self] values in
            guard let self = self, self.predictionKey == key else { return }
            self.cachedSuggestions = values
            self.refresh(client)
        })
        return cachedSuggestions
    }

    private func scheduleChineseCompletions(_ sender: Any!) {
        guard chinese.completionsEnabled, chinese.isPending else {
            chineseRequest?.cancel(); chinesePredictionKey = nil; return
        }
        let code = chinese.code
        let key = "\(currentProfile!.id):\(code)"
        guard chinesePredictionKey != key else { return }
        chineseRequest?.cancel()
        chinesePredictionKey = key
        let dictionary = chinese.dictionary
        chineseRequest = CompletionScheduler.submit({ dictionary.candidates(for: code, completing: true) }, receive: { [weak self] values in
            guard let self = self, self.chinesePredictionKey == key else { return }
            self.chinese.applyCompletions(values, for: code)
            self.refresh(sender)
        })
    }

    private func acceptSuggestion(_ index: Int, client: IMKTextInput) -> Bool {
        let values = suggestions(client)
        guard values.indices.contains(index) else { return false }
        // Replace the marked syllable with the whole word in one insertion. Committing
        // the syllable and then inserting the suffix let some hosts place the suffix
        // before the syllable ("in x" instead of "xin").
        var word = values[index] + " "
        if currentProfile?.language == .vietnamese, case .commit(let syllable) = engine.finishPartial() {
            word = (syllable + word).precomposedStringWithCanonicalMapping
        }
        commit(word, client: client)
        adaptiveTail = adaptive ? word : nil
        refresh(client)
        return true
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

    private func chineseCommand(_ command: EditingCommand, client: IMKTextInput) -> Bool {
        shiftTap.interrupt()
        switch command {
        case .backward, .decomposingBackward:
            guard chinese.isPending else { return false }
            apply(chinese.backspace(), sender: client)
        case .space:
            guard chinese.isPending else { return false }
            apply(chinese.choose(), sender: client)
        case .newline, .lineBreak:
            guard chinese.isPending else { return false }
            apply(chinese.choose(literal: chinese.selected == nil), sender: client)
        case .up, .down:
            guard chinese.isPending else { return false }
            chinese.moveSelection(command == .up ? -1 : 1)
        case .cancel:
            guard chinese.isPending else { return false }
            cancelComposition(client)
        default:
            cancelComposition(client)
            refresh(client)
            return false
        }
        refresh(client)
        return true
    }

    func command(_ selector: Selector, client sender: Any!) -> Bool {
        guard let client = sender as? IMKTextInput,
              let command = EditingCommand(rawValue: NSStringFromSelector(selector)) else { return false }
        if let ownID = Bundle.main.bundleIdentifier, client.bundleIdentifier() == ownID { return false }
        syncProfile(sender)
        discardMovedComposition(client)
        if currentProfile?.language == .chinese {
            return chineseCommand(command, client: client)
        }
        if command == .tab, currentProfile?.language != .chinese, !suggestions(client).isEmpty {
            return acceptSuggestion(0, client: client)
        }
        switch command {
        case .backward, .decomposingBackward:
            shiftTap.interrupt()
            if marked && compositionMoved(client) { return false }
            if client.selectedRange().location != NSNotFound && client.selectedRange().length > 0 && !ownsCompositionSelection(client) { return false }
            if keyIsDown(56) || keyIsDown(60) {
                cancelComposition(sender)
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
            finishComposition(sender)
            refresh(sender)
            return false
        case .cancel:
            shiftTap.interrupt()
            let pending = engine.isPending
            cancelComposition(sender)
            refresh(sender)
            return pending
        }
    }

    private func passThrough(_ sender: Any!) {
        finishComposition(sender)
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
                finishComposition(sender)
                history.removeAll()
                switchKeyboard()
                syncProfile(sender)
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
        invalidateSuggestions()
        cancelComposition(sender)
        shiftTap.interrupt()
        engine = KeyboardEngine(outputType: profile.outputType, ascii: profile.language == .english, inputMode: profile.inputMode)
        chinese.completionsEnabled = profile.suggestionsEnabled
        history.removeAll()
        currentProfile = profile
    }

    private func discardMovedComposition(_ client: IMKTextInput) {
        guard marked && compositionMoved(client) else { return }
        shiftTap.interrupt()
        _ = engine.cancel()
        _ = chinese.cancel()
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
                cancelComposition(sender)
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
        case .commit(let text): commit(text, client: client); adaptiveTail = adaptive ? text : nil
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
        var rect = NSRect.zero
        if let client = sender as? IMKTextInput {
            _ = client.attributes(forCharacterIndex: 0, lineHeightRectangle: &rect)
        }
        if currentProfile?.language == .chinese {
            scheduleChineseCompletions(sender)
            KeyboardPanel.shared.show(chinese: chinese, caret: rect.height > 0 ? rect : nil,
                                      showKeyboard: currentProfile?.showVirtualKeyboard ?? true, onChoose: { [weak self] index in
                                          guard let self = self, let client = sender as? IMKTextInput else { return }
                                          self.apply(self.chinese.choose(index + 1), sender: client)
                                          self.refresh(client)
                                      })
            return
        }
        let candidates = (sender as? IMKTextInput).map(suggestions) ?? []
        KeyboardPanel.shared.show(engine: engine, caret: rect.height > 0 ? rect : nil, message: message ?? notice,
                                  inputType: (currentProfile ?? profileProvider()).inputType,
                                  asciiActions: ASCIIPlusMapping.actions(for: engine, keymap: keymap),
                                  showKeyboard: (currentProfile ?? profileProvider()).showVirtualKeyboard,
                                  suggestions: candidates, onChoose: { [weak self] index in
                                      guard let client = sender as? IMKTextInput else { return }
                                      _ = self?.acceptSuggestion(index, client: client)
                                  })
        notice = nil
    }
}
