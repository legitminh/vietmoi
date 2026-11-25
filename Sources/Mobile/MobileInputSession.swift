#if !hasFeature(Embedded)
import Foundation
#endif

// Small document boundary shared by the in-app editor and the keyboard extension.
// UIKit lives in adapters; phonetic construction remains in the existing engine.
@MainActor protocol MobileTextDocument: AnyObject {
    var identifier: String { get }
    var beforeInput: String? { get }
    var afterInput: String? { get }
    var selectedText: String? { get }
    func setMarkedText(_ text: String)
    func unmarkText()
    func insertText(_ text: String)
    func deleteBackward()
    func moveCursor(by offset: Int)
    func moveCursorVertically(by lines: Int)
}

extension MobileTextDocument {
    func moveCursorVertically(by lines: Int) {
        let offset = KeyboardCursorMovement.verticalOffset(before: beforeInput ?? "", after: afterInput ?? "", lines: lines)
        if offset != 0 { moveCursor(by: offset) }
    }
}

@MainActor final class MobileInputSession {
    private struct Position: Equatable {
        var identifier: String
        var before: String?
        var after: String?
        var selection: String?
        @MainActor init(_ document: MobileTextDocument) {
            identifier = document.identifier
            before = document.beforeInput.map { String($0.suffix(64)) }
            after = document.afterInput.map { String($0.prefix(64)) }
            selection = document.selectedText.flatMap { $0.isEmpty ? nil : $0 }
        }
        func inserting(_ text: String) -> Position {
            var result = self
            result.before = before.map { String(($0 + text).suffix(64)) }
            result.selection = nil
            return result
        }
    }
    private let document: MobileTextDocument
    private let settingsProvider: () -> MobileKeyboardSettings
    // App/extension-local preferences keep mode across text fields and
    // controller recreation without writing to the read-only App Group snapshot.
    private let defaults: UserDefaults
    // The keyboard's current list position. A Shift tap moves it without writing
    // the app's snapshot; a new selection made in the app is adopted.
    private static let activeKey = "mobile.activeKeyboard.v1"
    private static let seenKey = "mobile.appActiveKeyboard.v1"
    private static let legacyASCIIKey = "mobile.asciiMode.v1"
    private var settings: MobileKeyboardSettings
    private(set) var profile: KeyboardProfile
    var keyboardLanguage: KeyboardLanguage { profile.language }
    private var chinese: ShuangpinEngine
    private var predictionRequest: Operation?
    private var chineseRequest: Operation?
    private var predictionKey: String?
    private var chinesePredictionKey: String?
    private var cachedSuggestions: [String] = []
    /// The English word the cached suggestions complete; see scheduleSuggestions.
    private var englishPrefix = ""
    private let submitCompletion: CompletionSubmit
    private let englishWords: (String) -> [String]
    private var recentCommit: String?
    /// The automatic Vietnamese block (or adaptive rewrite) just before the caret; see AdaptivePunctuation.
    private var adaptiveTail: String?
    private var engine: KeyboardEngine
    private var expected: Position?
    private var origin: Position?
    private var originalSelection = ""
    private var componentCases: [MobileLetterCase] = []
    private var compositionParts: [String] = []
    private var marked = false
    private var editing = false
    private var movingCursor = false
    var onChange: (() -> Void)?
    var output: OutputType { profile.language == .vietnamese ? engine.outputType : profile.outputType }
    var input: InputType { profile.isLiteral ? .asciiPlus : profile.inputType }
    var rows: [[ASCIIKey]] {
        guard input == .grid4x8 && !ascii else { return ASCIIKeyboardLayout.guideRows }
        return stride(from: 0, to: GridKey.all.count, by: 8).map { start in
            GridKey.all[start..<start+8].map { ASCIIKey(label: $0.keyCode == 56 ? "Shift" : $0.label, keyCode: $0.keyCode) }
        }
    }
    var ascii: Bool { keyboardLanguage == .english }
    var phase: Phase { engine.phase }
    var preview: String { keyboardLanguage == .chinese ? chinese.preview : cased(compositionParts) }
    var pending: Bool { engine.isPending || chinese.isPending }
    var suggestionsEnabled: Bool { keyboardLanguage == .chinese || profile.suggestionsEnabled }
    var suggestions: [String] {
        keyboardLanguage == .chinese ? chinese.visibleCandidates.map({ $0.text }) : suggestionsEnabled ? cachedSuggestions : []
    }
    var completedBasis: VietnamesePhoneticBasis? { engine.lastCommittedBasis }
    init(document: MobileTextDocument, defaults: UserDefaults = .standard,
         settingsProvider: @escaping () -> MobileKeyboardSettings = { .standard },
         chineseDictionary: ShuangpinDictionary = .shared,
         submitCompletion: @escaping CompletionSubmit = CompletionScheduler.submit,
         englishWords: @escaping (String) -> [String] = MobileEnglishCompletion.words) {
        self.document = document
        self.submitCompletion = submitCompletion
        self.englishWords = englishWords
        self.chinese = ShuangpinEngine(dictionary: chineseDictionary)
        self.defaults = defaults
        self.settingsProvider = settingsProvider
        let initial = settingsProvider().supported
        settings = initial
        profile = Self.resolve(initial, defaults: defaults)
        engine = Self.engine(for: profile)
        chinese.completionsEnabled = profile.language == .chinese && profile.suggestionsEnabled
    }
    private static func engine(for profile: KeyboardProfile) -> KeyboardEngine {
        KeyboardEngine(outputType: profile.language == .vietnamese ? profile.outputType : .sieuviet,
                       ascii: profile.isLiteral, inputMode: profile.inputMode)
    }
    private static func resolve(_ settings: MobileKeyboardSettings, defaults: UserDefaults) -> KeyboardProfile {
        let appActive = settings.activeID.uuidString
        if defaults.string(forKey: seenKey) != appActive {
            defaults.set(appActive, forKey: seenKey)
            // Older keyboards kept only a literal ASCII flag; keep its mode once.
            if defaults.string(forKey: activeKey) == nil, defaults.bool(forKey: legacyASCIIKey),
               let english = settings.profiles.first(where: { $0.isLiteral }) {
                defaults.set(english.id.uuidString, forKey: activeKey)
                return english
            }
            defaults.set(appActive, forKey: activeKey)
            return settings.active
        }
        let local = defaults.string(forKey: activeKey).flatMap(UUID.init(uuidString:))
        return settings.profiles.first { $0.id == local } ?? settings.active
    }
    func reloadSettings() {
        guard !pending else { return }
        let latest = settingsProvider().supported
        guard latest != settings else { return }
        settings = latest
        useProfile(Self.resolve(latest, defaults: defaults))
    }
    private func useProfile(_ next: KeyboardProfile) {
        guard next != profile || engine.ascii != next.isLiteral else { return }
        profile = next
        engine = Self.engine(for: next)
        chinese.completionsEnabled = next.language == .chinese && next.suggestionsEnabled
        invalidateSuggestions()
        recentCommit = nil; adaptiveTail = nil
        scheduleSuggestions()
        onChange?()
    }
    /// The keyboard a Shift tap moves to.
    var nextProfile: KeyboardProfile {
        let index = settings.profiles.firstIndex { $0.id == profile.id } ?? -1
        return settings.profiles[(index + 1) % settings.profiles.count]
    }
    func selectPreviousKeyboard() {
        edit {
            let index = settings.profiles.firstIndex { $0.id == profile.id } ?? 0
            select(settings.profiles[(index - 1 + settings.profiles.count) % settings.profiles.count])
        }
    }
    private func selectNextKeyboard() { select(nextProfile) }
    private func select(_ next: KeyboardProfile) {
        finishActiveComposition()
        defaults.set(next.id.uuidString, forKey: Self.activeKey)
        profile = next
        engine = Self.engine(for: next)
        chinese.completionsEnabled = next.language == .chinese && next.suggestionsEnabled
        invalidateSuggestions()
        recentCommit = nil; adaptiveTail = nil
    }
    func label(for key: ASCIIKey) -> String? {
        if key.keyCode == 56 { return nextProfile.language == .english ? "ABC" : nextProfile.language == .chinese ? "中" : "VIỆT" }
        if keyboardLanguage == .chinese { return chinese.keyLabel(key.label) }
        if ascii { return key.label }
        if input == .grid4x8 {
            guard let index = GridKey.index(keyCode: key.keyCode) else { return nil }
            if index == 31 && !pending && recentCommit == nil { return nil }
            return engine.action(at: index)
        }
        guard let choice = ASCIIPlusMapping.bindings(for: phase, inventory: engine.inventory, keymap: engine.keymap)[key.keyCode] else { return nil }
        if phase == .tone { return VietnameseTone(rawValue: choice)?.label }
        return engine.componentLabel(choice)
    }
    func accessibilityLabel(for key: ASCIIKey) -> String {
        if key.keyCode == 56 { return AppCopy.text("nextKeyboard") }
        if keyboardLanguage == .chinese { return key.label + ": " + (chinese.keyLabel(key.label) ?? AppCopy.text("unavailable")) }
        let action = input == .grid4x8 ? (label(for: key) ?? AppCopy.text("unavailable")) : (ASCIIPlusMapping.actions(for: engine, keymap: engine.keymap)[key.keyCode] ?? AppCopy.text("unavailable"))
        return ascii ? key.label : "\(key.label): \(action == "Clear" ? AppCopy.text("clear") : action)"
    }
    func press(_ key: ASCIIKey, letterCase: MobileLetterCase = .lowercase) {
        edit {
            if key.keyCode == 56 {
                selectNextKeyboard()
                return
            }
            if keyboardLanguage == .chinese {
                if !chinese.isPending { begin() }
                apply(chinese.append(key.label.lowercased()))
            } else if engine.ascii {
                insertLiteral(letterCase.apply(key.label))
            } else if input == .grid4x8, let index = GridKey.index(keyCode: key.keyCode) {
                guard label(for: key) != nil else { return }
                if !engine.isPending { begin() }
                if index != 31 && engine.phase != .tone { componentCases.append(letterCase) }
                apply(engine.press(index))
            } else if let choice = ASCIIPlusMapping.bindings(for: engine.phase, inventory: engine.inventory, keymap: engine.keymap)[key.keyCode] {
                if !engine.isPending { begin() }
                if engine.phase != .tone { componentCases.append(letterCase) }
                apply(engine.selectComponent(choice))
            } else if key.label == ";" {
                // Match the Mac's contextual punctuation behavior.
                finishActiveComposition()
                insertLiteral(";")
            }
        }
    }
    func backspace() {
        edit {
            if keyboardLanguage == .chinese, chinese.isPending { apply(chinese.backspace()); return }
            if engine.isPending {
                if !componentCases.isEmpty { componentCases.removeLast() }
                apply(engine.backspace())
            }
            else { document.deleteBackward(); expected = Position(document) }
        }
    }
    func space() {
        edit {
            if keyboardLanguage == .chinese {
                if chinese.isPending { apply(chinese.choose()) }
                else { insertLiteral(" ") }
                return
            }
            let hasPreview = !engine.preview.isEmpty
            apply(engine.finishPartial(suffix: " "))
            if !hasPreview { insertLiteral(" ") }
            // A typed space is the writer's own: only a completed block's automatic space adapts.
            adaptiveTail = nil
        }
    }
    func selectSuggestion(at index: Int) {
        edit {
            if keyboardLanguage == .chinese { apply(chinese.choose(index + 1)); return }
            let values = suggestions
            guard values.indices.contains(index) else { return }
            acceptSuggestion(values[index])
        }
    }
    func endCursorMovement() { movingCursor = false; scheduleSuggestions(); onChange?() }
    func beginCursorMovement() {
        movingCursor = true
        invalidateSuggestions()
        edit {
            finishActiveComposition()
            recentCommit = nil; adaptiveTail = nil
        }
    }
    func moveCursor(by offset: Int) {
        guard offset != 0 else { return }
        edit {
            finishActiveComposition()
            recentCommit = nil; adaptiveTail = nil
            document.moveCursor(by: offset)
            expected = Position(document)
        }
    }
    func literal(_ text: String) {
        guard CompositionText.isSafe(text) else { return }
        edit {
            finishActiveComposition()
            // Adaptive punctuation: "mệt quá " + "!" → "mệt quá! ", only over verified text of our own.
            if let tail = adaptiveTail, let rewrite = AdaptivePunctuation.rewrite(tail: tail, typing: text),
               document.beforeInput?.hasSuffix(tail) == true, (document.selectedText ?? "").isEmpty {
                for _ in tail { document.deleteBackward() }
                insertLiteral(rewrite)
                adaptiveTail = rewrite
                return
            }
            insertLiteral(text)
        }
    }
    /// What the letter layer's comma or period key types for the active keyboard (，。 for Chinese).
    func letterMark(_ text: String) -> String { LetterLayerPunctuation.mark(text, language: keyboardLanguage) }
    func newline() {
        edit { finishActiveComposition(); insertLiteral("\n") }
    }
    func finish() { edit { finishActiveComposition() } }
    func cancel() { edit { apply(engine.cancel()); apply(chinese.cancel()); invalidateSuggestions() } }
    func documentDidChange() {
        guard !editing else { return }
        reconcile()
        reloadSettings()
        scheduleSuggestions()
        onChange?()
    }
    private func finishActiveComposition() {
        if keyboardLanguage == .chinese { apply(chinese.choose(literal: chinese.selected == nil)) }
        else { apply(engine.finishPartial()) }
    }
    private func invalidateSuggestions() {
        predictionRequest?.cancel(); chineseRequest?.cancel()
        predictionKey = nil; chinesePredictionKey = nil; cachedSuggestions = []; englishPrefix = ""
    }
    private func scheduleSuggestions() {
        guard !movingCursor else { return }
        if keyboardLanguage == .chinese {
            guard chinese.completionsEnabled, chinese.isPending else { chineseRequest?.cancel(); chinesePredictionKey = nil; return }
            let code = chinese.code
            guard chinesePredictionKey != code else { return }
            chineseRequest?.cancel(); chinesePredictionKey = code
            let dictionary = chinese.dictionary
            chineseRequest = CompletionScheduler.submit({ dictionary.candidates(for: code, completing: true) }, receive: whenAlive { (self: MobileInputSession, values: [ShuangpinCandidate]) in
                guard self.chinesePredictionKey == code, self.keyboardLanguage == .chinese else { return }
                self.chinese.applyCompletions(values, for: code)
                self.onChange?()
            })
            return
        }
        guard profile.suggestionsEnabled else { invalidateSuggestions(); return }
        let context = String((document.beforeInput ?? "").suffix(256))
        let prefix = engine.preview
        let language = keyboardLanguage
        let key = "\(language):\(context):\(prefix)"
        guard key != predictionKey else { return }
        predictionRequest?.cancel(); predictionKey = key
        if language != .english {
            // The Vietnamese model is a small in-memory table: rank it now, so suggestions
            // never blink empty between keys or wait for idle time.
            cachedSuggestions = VietnamesePredictionEngine.suggestions(context: context, prefix: prefix, limit: 16).map({ $0.suffix })
            return
        }
        // Until the word list answers, the last suggestions that still fit the longer word stay up.
        let word = EnglishCompletion.prefix(of: context)
        if word.count > englishPrefix.count, !englishPrefix.isEmpty, word.hasPrefix(englishPrefix) {
            let typed = String(word.dropFirst(englishPrefix.count))
            cachedSuggestions = cachedSuggestions.filter({ $0.count > typed.count && $0.hasPrefix(typed) }).map({ String($0.dropFirst(typed.count)) })
        } else {
            cachedSuggestions = []
        }
        englishPrefix = word
        let complete = englishWords
        predictionRequest = submitCompletion({
            EnglishCompletion.suffixes(context: context, complete: complete)
        }, whenAlive { (self: MobileInputSession, values: [String]) in
            guard self.predictionKey == key else { return }
            self.cachedSuggestions = values
            self.onChange?()
        })
    }
    /// Late completion results reach only a live session. Embedded Swift (the web
    /// demo) has no weak references; its page keeps one session for its whole life.
    private func whenAlive<Value>(_ body: @escaping (MobileInputSession, Value) -> Void) -> (Value) -> Void {
        #if hasFeature(Embedded)
        return { value in body(self, value) }
        #else
        return { [weak self] value in if let self = self { body(self, value) } }
        #endif
    }
    func moveCursorVertically(by lines: Int) {
        guard lines != 0 else { return }
        edit {
            finishActiveComposition()
            recentCommit = nil; adaptiveTail = nil
            document.moveCursorVertically(by: lines)
            expected = Position(document)
        }
    }

    private func edit(_ body: () -> Void) {
        guard !editing else { return }
        reconcile()
        reloadSettings()
        editing = true
        body()
        editing = false
        reloadSettings()
        scheduleSuggestions()
        onChange?()
    }
    private func reconcile() {
        let current = Position(document)
        guard let expected = expected else { self.expected = current; return }
        if current == expected { return }
        // Accept an as-yet unacknowledged marked caret, without replacing our
        // predicted new position with the host's old snapshot.
        if marked, current == origin { return }
        // A cursor/selection/document change ends the local flow. Never delete or
        // reinsert an old preview at a new caret or in a different text field.
        if marked && current.identifier == expected.identifier {
            editing = true
            document.unmarkText()
            editing = false
        }
        _ = engine.cancel()
        _ = chinese.cancel()
        invalidateSuggestions()
        componentCases.removeAll(); compositionParts.removeAll()
        recentCommit = nil; adaptiveTail = nil
        marked = false
        originalSelection = ""
        origin = nil
        self.expected = Position(document)
    }
    private func begin() {
        componentCases.removeAll(); compositionParts.removeAll()
        origin = Position(document)
        originalSelection = document.selectedText ?? ""
    }
    private func insertLiteral(_ text: String) {
        recentCommit = nil; adaptiveTail = nil
        let start = Position(document)
        document.insertText(text)
        expected = start.inserting(text)
    }
    private func acceptSuggestion(_ suffix: String) {
        finishActiveComposition()
        insertLiteral(suffix + " ")
        if adaptive { adaptiveTail = suffix + " " }
    }
    /// Vietnamese blocks and completions arm adaptive punctuation when this keyboard enables it.
    private var adaptive: Bool { keyboardLanguage == .vietnamese && !engine.ascii && profile.adaptivePunctuation }
    private func apply(_ effect: EngineEffect) {
        switch effect {
        case .marked(let text):
            guard !text.isEmpty || marked else { return }
            compositionParts = engine.components.enumerated().map { index, choice in
                if index == 0 { return engine.inventory.initials[choice] }
                if index == 1 { return engine.inventory.vowelAtoms[choice].label }
                return engine.inventory.finals[choice]
            }
            let visible = text.isEmpty ? originalSelection : keyboardLanguage == .chinese ? text : cased(compositionParts)
            document.setMarkedText(visible)
            marked = true
            expected = origin?.inserting(visible)
        case .commit(let rawText):
            if keyboardLanguage == .vietnamese, let basis = engine.lastCommittedBasis {
                if engine.outputType == .quocNgu { compositionParts = StandardVietnamese.parts(basis) }
                else {
                    let rendered = basis.sieuviet()
                    compositionParts = [basis.initial,
                        String(rendered.dropFirst(basis.initial.count).dropLast(basis.final.count)), basis.final]
                }
            }
            let text = keyboardLanguage == .chinese ? rawText : cased(compositionParts) + String(rawText.dropFirst(compositionParts.joined().count))
            if marked {
                document.setMarkedText(text)
                document.unmarkText()
                expected = origin?.inserting(text)
            } else { insertLiteral(text) }
            resetMark()
            recentCommit = text
            adaptiveTail = adaptive ? text : nil
        case .cancel:
            if marked {
                document.setMarkedText(originalSelection)
                document.unmarkText()
                expected = origin?.inserting(originalSelection)
            }
            resetMark()
        case .none: break
        case .deleteCycle:
            guard let text = recentCommit, document.beforeInput?.hasSuffix(text) == true,
                  (document.selectedText ?? "").isEmpty else { recentCommit = nil; adaptiveTail = nil; return }
            for _ in text { document.deleteBackward() }
            recentCommit = nil; adaptiveTail = nil
            expected = Position(document)
        }
    }
    private func cased(_ parts: [String]) -> String {
        parts.enumerated().map { index, text in
            index < componentCases.count ? componentCases[index].apply(text) : text
        }.joined().precomposedStringWithCanonicalMapping
    }
    private func resetMark() {
        componentCases.removeAll(); compositionParts.removeAll()
        marked = false
        origin = nil
        originalSelection = ""
    }
}
