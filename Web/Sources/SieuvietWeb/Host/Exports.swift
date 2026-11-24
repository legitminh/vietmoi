// The WebAssembly boundary of the web demo. The page forwards every key, touch and
// textbox snapshot here; MobileInputSession (the same session as the iOS keyboard)
// decides everything, and the page only applies the returned document operations
// and renders the returned keyboard state.
//
// Strings cross as UTF-8 in two buffers: the page writes arguments into the input
// buffer, and results (operations or state JSON) are read from the output buffer.

@MainActor final class WebHost {
    static let shared = WebHost()
    let document = WebDocument()
    /// The page's keyboard list. A box, so the session can read it before `shared` exists.
    private final class Settings { var value = MobileKeyboardSettings.standard }
    private let box = Settings()
    var settings: MobileKeyboardSettings {
        get { box.value }
        set { box.value = newValue }
    }
    private(set) var session: MobileInputSession
    private var chineseDictionary = ShuangpinDictionary.shared
    var currentDictionary: ShuangpinDictionary { chineseDictionary }
    private var dictionaryWaiting = false
    var shiftTap = ShiftTapDetector()
    var shiftTapSeconds = ShiftTapDetector.defaultTapSeconds
    var touchShift = MobileShiftState()
    var symbols = MobileSymbolState()
    var changed = true
    /// A Chinese dictionary being built a slice at a time in idle callbacks.
    var chineseBuilder: ShuangpinDictionaryBuilder?
    var englishBuilder: EnglishWordList.Builder?

    private init() {
        session = Self.session(document: document, settings: box, dictionary: ShuangpinDictionary.shared)
    }
    private static func session(document: WebDocument, settings: Settings, dictionary: ShuangpinDictionary) -> MobileInputSession {
        let session = MobileInputSession(document: document, settingsProvider: { settings.value }, chineseDictionary: dictionary)
        session.onChange = { WebHost.shared.changed = true }
        return session
    }
    private func makeSession() {
        UserDefaults.standard.removeAll()
        session = Self.session(document: document, settings: box, dictionary: chineseDictionary)
        changed = true
    }
    /// Adopt a newly loaded dictionary once no Chinese syllable is being composed.
    func useChineseDictionary(_ dictionary: ShuangpinDictionary) {
        chineseDictionary = dictionary
        dictionaryWaiting = true
        adoptDictionaryIfIdle()
    }
    func adoptDictionaryIfIdle() {
        guard dictionaryWaiting, !session.pending else { return }
        dictionaryWaiting = false
        let active = session.profile.id
        makeSession()
        // Keep the keyboard a Shift tap had moved to.
        if session.profile.id != active, let index = settings.profiles.firstIndex(where: { $0.id == active }) {
            settings.activeID = settings.profiles[index].id
            session.reloadSettings()
        }
    }
}

// MARK: Buffers

private var inputBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 4096)
private var inputCapacity = 4096
private var outputBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 4096)
private var outputCapacity = 4096
private var outputLength = 0

private func input(_ length: Int32) -> String {
    String(decoding: UnsafeBufferPointer(start: inputBuffer, count: Int(max(0, min(Int(length), inputCapacity)))), as: UTF8.self)
}
private func fields(_ length: Int32) -> [String] {
    input(length).split(separator: "\u{0}", omittingEmptySubsequences: false).map { String($0) }
}
private func output(_ text: String) -> Int32 {
    var bytes = Array(text.utf8)
    if bytes.count > outputCapacity {
        outputBuffer.deallocate()
        outputCapacity = bytes.count * 2
        outputBuffer = .allocate(capacity: outputCapacity)
    }
    bytes.withUnsafeMutableBufferPointer { source in
        if let base = source.baseAddress { outputBuffer.update(from: base, count: source.count) }
    }
    outputLength = bytes.count
    return Int32(bytes.count)
}

@_expose(wasm, "sv_input") @_cdecl("sv_input")
func svInput(_ capacity: Int32) -> UnsafeMutablePointer<UInt8> {
    if Int(capacity) > inputCapacity {
        inputBuffer.deallocate()
        inputCapacity = Int(capacity)
        inputBuffer = .allocate(capacity: inputCapacity)
    }
    return inputBuffer
}
@_expose(wasm, "sv_output") @_cdecl("sv_output")
func svOutput() -> UnsafeMutablePointer<UInt8> { outputBuffer }

// MARK: Settings and document

private let languages: [String: KeyboardLanguage] = ["vi": .vietnamese, "en": .english, "zh": .chinese]

/// Lines: "activeID\tinterfaceLanguage\tshiftTapSeconds", then per keyboard
/// "id\tlanguage\tinputType\toutputType\tinputMode\tsuggestions(1/0)\tname[\tadaptivePunctuation(1/0)]".
@_expose(wasm, "sv_configure") @_cdecl("sv_configure")
func svConfigure(_ length: Int32) {
    onMain {
        let host = WebHost.shared
        let lines = input(length).split(separator: "\n").map { $0.split(separator: "\t", omittingEmptySubsequences: false).map { String($0) } }
        guard let header = lines.first, header.count >= 3 else { return }
        var profiles: [KeyboardProfile] = []
        for line in lines.dropFirst() where line.count >= 7 {
            guard let id = UUID(uuidString: line[0]) else { continue }
            let language = languages[line[1]] ?? .vietnamese
            var profile = KeyboardProfile(id: id, name: line[6], language: language,
                                          inputType: InputType(rawValue: line[2]) ?? language.inputs[0],
                                          outputType: OutputType(rawValue: line[3]) ?? language.outputs[0],
                                          suggestionsEnabled: line[5] == "1")
            profile.inputMode = InputMode(rawValue: line[4]) ?? .sieuviet
            profile.adaptivePunctuation = line.count < 8 || line[7] != "0"
            profiles.append(profile)
        }
        guard !profiles.isEmpty else { return }
        let active = UUID(uuidString: header[0]).flatMap { id in profiles.first { $0.id == id }?.id } ?? profiles[0].id
        host.settings = MobileKeyboardSettings(profiles: profiles, activeID: active, language: header[1])
        if let seconds = Double(header[2]), seconds >= 0.01, seconds <= 5 { host.shiftTapSeconds = seconds }
        host.session.reloadSettings()
        host.changed = true
    }
}

/// "identifier\0before\0after\0selected\0markedCount": the text around the caret.
@_expose(wasm, "sv_document") @_cdecl("sv_document")
func svDocument(_ length: Int32) {
    onMain {
        let parts = fields(length)
        guard parts.count >= 5 else { return }
        WebHost.shared.document.update(before: parts[1], after: parts[2], selected: parts[3],
                                       marked: Int(parts[4]) ?? 0, identifier: parts[0])
    }
}

/// Operations, each ended by NUL: M<text> mark, U unmark, I<text> insert, D delete backward, C<n> move caret.
@MainActor private func operations() -> Int32 {
    var text = ""
    for operation in WebHost.shared.document.takeOperations() {
        switch operation {
        case .setMarked(let value): text += "M" + value
        case .unmark: text += "U"
        case .insert(let value): text += "I" + value
        case .deleteBackward: text += "D"
        case .moveCursor(let offset): text += "C" + String(offset)
        }
        text += "\u{0}"
    }
    return output(text)
}

// MARK: Physical keyboard

private func key(_ label: String) -> ASCIIKey? {
    ASCIIKeyboardLayout.keyCodesByLabel[label].map { ASCIIKey(label: label, keyCode: $0) }
}

/// A physical key down. Input: "position\0text" (US position label such as "a", ";" or
/// "Backspace", and the character the key types). Flags: 1 Shift, 2 Caps Lock,
/// 4 Control/Command/Option, 8 repeat. Returns the operations' byte length × 2, plus 1
/// when the session handled the key; otherwise the page keeps the browser's own behavior.
@_expose(wasm, "sv_key") @_cdecl("sv_key")
func svKey(_ length: Int32, _ flags: Int32) -> Int32 {
    onMain {
        let host = WebHost.shared, session = host.session
        host.adoptDictionaryIfIdle()
        let parts = fields(length)
        let position = parts.first ?? "", text = parts.count > 1 ? parts[1] : ""
        let shift = flags & 1 != 0, caps = flags & 2 != 0, command = flags & 4 != 0, repeating = flags & 8 != 0
        if let code = ASCIIKeyboardLayout.keyCodesByLabel[position] { host.shiftTap.keyDown(code) } else { host.shiftTap.interrupt() }
        var handled = true
        let chinese = session.keyboardLanguage == .chinese
        if command {
            session.finish()
            handled = false
        } else {
            switch position {
            case "Backspace": session.backspace()
            case "Space": session.space()
            case "Enter": session.newline()
            case "Escape":
                handled = session.pending
                if handled { session.cancel() }
            case "Tab":
                handled = !shift && !chinese && session.suggestionsEnabled && !session.suggestions.isEmpty
                if handled { session.selectSuggestion(at: 0) } else { session.finish() }
            case "ArrowLeft", "ArrowRight":
                if shift { session.finish(); handled = false } else { session.moveCursor(by: position == "ArrowLeft" ? -1 : 1) }
            case "ArrowUp", "ArrowDown":
                if shift { session.finish(); handled = false } else { session.moveCursorVertically(by: position == "ArrowUp" ? -1 : 1) }
            default:
                let routable = session.rows.contains { row in row.contains { $0.label == position && $0.keyCode != 56 } }
                let digit = Int(position).flatMap { (1...9).contains($0) ? $0 : nil }
                // Shift+digit types its symbol ("!"), never a suggestion.
                if let digit = digit, !shift, chinese ? session.pending : (session.keyboardLanguage == .vietnamese && session.input == .asciiPlus),
                   session.suggestions.indices.contains(digit - 1), !routable || chinese {
                    // Number keys choose a candidate (Chinese) or an ASCII+ suggestion, as on the Mac.
                    session.selectSuggestion(at: digit - 1)
                } else if routable && !session.ascii && !(chinese && !position.allSatisfy({ $0.isLetter || $0 == ";" })),
                          let key = key(position) {
                    // Held keys repeat only as plain text; a modal round must not repeat.
                    if !repeating { session.press(key, letterCase: caps ? .capsLock : shift ? .shifted : .lowercase) }
                } else if text.unicodeScalars.count >= 1, text.count == 1, !text.unicodeScalars.contains(where: { $0.value < 0x20 || $0.value == 0x7f }) {
                    session.literal(text)
                } else {
                    session.finish()
                    handled = false
                }
            }
        }
        host.adoptDictionaryIfIdle()
        return operations() * 2 + (handled ? 1 : 0)
    }
}

/// A physical Shift (or other modifier) change. Returns the operations' byte length × 2,
/// plus 1 when a left Shift tap finished the composition and moved to the next keyboard.
@_expose(wasm, "sv_modifier") @_cdecl("sv_modifier")
func svModifier(_ isShift: Int32, _ left: Int32, _ down: Int32, _ otherModifiers: Int32, _ seconds: Double) -> Int32 {
    onMain {
        let host = WebHost.shared
        if otherModifiers != 0 || isShift == 0 || left == 0 {
            host.shiftTap.interrupt()
            return operations() * 2
        }
        if down != 0 {
            host.shiftTap.press(at: seconds, threshold: host.shiftTapSeconds, isolated: otherModifiers == 0)
            return operations() * 2
        }
        guard host.shiftTap.release(at: seconds) else { return operations() * 2 }
        host.adoptDictionaryIfIdle()
        host.session.press(ASCIIKey(label: "Shift", keyCode: 56))
        return operations() * 2 + 1
    }
}

/// Any key up, so a chord never counts as a Shift tap.
@_expose(wasm, "sv_key_up") @_cdecl("sv_key_up")
func svKeyUp(_ length: Int32) {
    onMain {
        if let code = ASCIIKeyboardLayout.keyCodesByLabel[input(length)] { WebHost.shared.shiftTap.keyUp(code) }
        else { WebHost.shared.shiftTap.interrupt() }
    }
}

// MARK: On-screen keyboard

/// The on-screen keyboard, as KeyboardSurfaceView drives the session on iOS.
/// Actions: 0 key (position label in the input), 1 backspace, 2 space, 3 return,
/// 4 literal text (input), 5 suggestion (argument), 6/7/8 Shift down/up/cancel,
/// 9/10 symbol page down/up (argument 1 numbers, 2 symbols), 11 cursor drag start,
/// 12 move by argument, 13 move lines by argument, 14 drag end, 15 finish, 16 cancel,
/// 17 document changed outside the session, 18 cancel held keys.
@_expose(wasm, "sv_touch") @_cdecl("sv_touch")
func svTouch(_ action: Int32, _ argument: Int32, _ seconds: Double, _ length: Int32) -> Int32 {
    onMain {
        let host = WebHost.shared, session = host.session
        host.adoptDictionaryIfIdle()
        let page: MobileSymbolState.Page = argument == 2 ? .symbols : .numbers
        switch action {
        case 0:
            if let key = key(input(length)) {
                let letterCase = host.touchShift.typed()
                host.symbols.typed()
                session.press(key, letterCase: letterCase)
            }
        case 1: host.touchShift.keyBegan(); host.symbols.typed(); session.backspace()
        case 2: host.touchShift.keyBegan(); host.symbols.typed(); session.space()
        case 3: host.touchShift.keyBegan(); host.symbols.typed(); session.newline()
        case 4: host.touchShift.keyBegan(); host.symbols.typed(); session.literal(input(length))
        case 5: session.selectSuggestion(at: Int(argument))
        case 6: host.touchShift.begin(at: seconds)
        case 7:
            let wasLocked = host.touchShift.capsLock
            host.touchShift.end(at: seconds)
            if host.touchShift.takeModeTap() {
                // The second tap of a double tap restores the first tap's keyboard and locks capitals.
                if host.touchShift.capsLock && !wasLocked { session.selectPreviousKeyboard() }
                else { session.press(ASCIIKey(label: "Shift", keyCode: 56)) }
            }
        case 8: host.touchShift.cancelHold()
        case 9: host.touchShift.keyBegan(); session.finish(); host.symbols.begin(page, at: seconds)
        case 10: host.symbols.end(page, at: seconds)
        case 11: host.touchShift.keyBegan(); host.symbols.typed(); session.beginCursorMovement()
        case 12: session.moveCursor(by: Int(argument))
        case 13: session.moveCursorVertically(by: Int(argument))
        case 14: session.endCursorMovement()
        case 15: session.finish()
        case 16: session.cancel()
        case 17: session.documentDidChange()
        case 18: host.touchShift.cancelHold(); host.symbols.cancelHold(); host.shiftTap.reset()
        default: break
        }
        host.changed = true
        host.adoptDictionaryIfIdle()
        return operations()
    }
}

// MARK: State, idle work and dictionaries

/// The keyboard as the page renders it, as JSON in the output buffer.
@_expose(wasm, "sv_state") @_cdecl("sv_state")
func svState() -> Int32 {
    onMain {
        let host = WebHost.shared, session = host.session
        host.changed = false
        var json = JSONWriter()
        json.raw("{")
        json.key("keyboard"); json.string(session.profile.id.uuidString)
        json.key("language"); json.string(session.keyboardLanguage.rawValue)
        json.key("input"); json.string(session.input.rawValue)
        json.key("ascii"); json.bool(session.ascii)
        json.key("pending"); json.bool(session.pending)
        json.key("preview"); json.string(session.preview)
        json.key("phase"); json.int(session.phase.rawValue)
        json.key("suggestionsEnabled"); json.bool(session.suggestionsEnabled)
        json.key("suggestions"); json.strings(session.suggestions)
        json.key("uppercase"); json.bool(host.touchShift.uppercase)
        json.key("capsLock"); json.bool(host.touchShift.capsLock)
        json.key("page"); json.int(host.symbols.page.rawValue)
        // The letter layer's comma and period for this keyboard (，。 for Chinese).
        json.key("marks"); json.strings([session.letterMark(","), session.letterMark(".")])
        json.key("symbols"); json.raw("[")
        for (index, rows) in TouchKeyboardSymbols.pages.enumerated() {
            if index > 0 { json.raw(",") }
            json.strings(rows)
        }
        json.raw("]")
        json.key("rows"); json.raw("[")
        for (rowIndex, row) in session.rows.enumerated() {
            json.raw(rowIndex > 0 ? ",[" : "[")
            for (index, key) in row.enumerated() {
                json.raw(index > 0 ? ",{" : "{")
                json.key("position"); json.string(key.label)
                json.key("code"); json.int(Int(key.keyCode))
                let title = session.label(for: key)
                json.key("title"); json.string(key.keyCode != 56 && title != "Clear" ? title.map { host.touchShift.letterCase.apply($0) } : title)
                json.raw("}")
            }
            json.raw("]")
        }
        json.raw("]")
        json.key("chineseDictionary"); json.bool(host.currentDictionary.isAvailable)
        json.key("englishWords"); json.bool(EnglishWordList.shared.isAvailable)
        json.raw("}")
        return output(json.text)
    }
}

/// Whether the session changed since the page last read its state (for example a completion arrived).
@_expose(wasm, "sv_changed") @_cdecl("sv_changed")
func svChanged() -> Int32 { onMain { WebHost.shared.changed ? 1 : 0 } }

/// One slice of background work: a queued completion, else part of a dictionary
/// build (a few milliseconds). Returns 1 while more work remains.
@_expose(wasm, "sv_idle") @_cdecl("sv_idle")
func svIdle() -> Int32 {
    onMain {
        let host = WebHost.shared
        if CompletionScheduler.hasWork { _ = CompletionScheduler.runNext() }
        else if let builder = host.englishBuilder {
            if let list = builder.step(2000) {
                EnglishWordList.shared = list
                host.englishBuilder = nil
                host.changed = true
            }
        } else if let builder = host.chineseBuilder, builder.step(400), let dictionary = builder.dictionary {
            host.chineseBuilder = nil
            host.useChineseDictionary(dictionary)
            host.changed = true
        }
        return CompletionScheduler.hasWork || host.chineseBuilder != nil || host.englishBuilder != nil ? 1 : 0
    }
}

/// Load a dictionary from the input buffer: 0 Chinese (pinyin_simp.dict.yaml), 1 English
/// word list. Either is built over later sv_idle calls, a few milliseconds at a time.
@_expose(wasm, "sv_load") @_cdecl("sv_load")
func svLoad(_ kind: Int32, _ length: Int32) {
    onMain {
        let text = input(length)
        if kind == 0 { WebHost.shared.chineseBuilder = ShuangpinDictionaryBuilder(contents: text) }
        else { WebHost.shared.englishBuilder = EnglishWordList.Builder(contents: text) }
        WebHost.shared.changed = true
    }
}

/// The page calls in on its only thread, which is the main actor's. Embedded Swift
/// has no executor to check that against, so run the main-actor body directly.
private func onMain<T>(_ body: @MainActor () -> T) -> T {
    withoutActuallyEscaping(body) { escapable in
        unsafeBitCast(escapable, to: (() -> T).self)()
    }
}
