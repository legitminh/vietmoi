import Foundation

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
    private var recentCommit: String?
    private var engine: KeyboardEngine
    private var expected: Position?
    private var origin: Position?
    private var originalSelection = ""
    private var componentCases: [MobileLetterCase] = []
    private var compositionParts: [String] = []
    private var marked = false
    private var editing = false
    var onChange: (() -> Void)?
    var output: OutputType { engine.outputType }
    var input: InputType { profile.isLiteral ? .asciiPlus : profile.inputType }
    var rows: [[ASCIIKey]] {
        guard input == .grid4x8 && !ascii else { return ASCIIKeyboardLayout.guideRows }
        return stride(from: 0, to: GridKey.all.count, by: 8).map { start in
            GridKey.all[start..<start+8].map { ASCIIKey(label: $0.keyCode == 56 ? "Shift" : $0.label, keyCode: $0.keyCode) }
        }
    }
    var ascii: Bool { engine.ascii }
    var phase: Phase { engine.phase }
    var preview: String { cased(compositionParts) }
    var pending: Bool { engine.isPending }
    var completedBasis: VietnamesePhoneticBasis? { engine.lastCommittedBasis }
    init(document: MobileTextDocument, defaults: UserDefaults = .standard,
         settingsProvider: @escaping () -> MobileKeyboardSettings = { .standard }) {
        self.document = document
        self.defaults = defaults
        self.settingsProvider = settingsProvider
        let initial = settingsProvider().supported
        settings = initial
        profile = Self.resolve(initial, defaults: defaults)
        engine = KeyboardEngine(outputType: profile.outputType, ascii: profile.isLiteral)
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
        guard !engine.isPending else { return }
        let latest = settingsProvider().supported
        guard latest != settings else { return }
        settings = latest
        useProfile(Self.resolve(latest, defaults: defaults))
    }
    private func useProfile(_ next: KeyboardProfile) {
        guard next != profile || engine.ascii != next.isLiteral || engine.outputType != next.outputType else { return }
        profile = next
        engine = KeyboardEngine(outputType: next.outputType, ascii: next.isLiteral)
        recentCommit = nil
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
        apply(engine.finishPartial())
        defaults.set(next.id.uuidString, forKey: Self.activeKey)
        profile = next
        engine = KeyboardEngine(outputType: next.outputType, ascii: next.isLiteral)
        recentCommit = nil
    }
    func label(for key: ASCIIKey) -> String? {
        if key.keyCode == 56 { return nextProfile.isLiteral ? "ABC" : "VIỆT" }
        if ascii { return key.label }
        if input == .grid4x8 {
            guard let index = GridKey.index(keyCode: key.keyCode) else { return nil }
            if index == 31 && !pending && recentCommit == nil { return nil }
            return engine.action(at: index)
        }
        guard let choice = ASCIIPlusMapping.bindings(for: phase)[key.keyCode] else { return nil }
        if phase == .tone { return VietnameseTone(rawValue: choice)?.label }
        return engine.componentLabel(choice)
    }
    func accessibilityLabel(for key: ASCIIKey) -> String {
        if key.keyCode == 56 { return AppCopy.text("nextKeyboard") }
        let action = input == .grid4x8 ? (label(for: key) ?? AppCopy.text("unavailable")) : (ASCIIPlusMapping.actions(for: engine)[key.keyCode] ?? AppCopy.text("unavailable"))
        return ascii ? key.label : "\(key.label): \(action == "Clear" ? AppCopy.text("clear") : action)"
    }
    func press(_ key: ASCIIKey, letterCase: MobileLetterCase = .lowercase) {
        edit {
            if key.keyCode == 56 {
                selectNextKeyboard()
                return
            }
            if engine.ascii {
                insertLiteral(letterCase.apply(key.label))
            } else if input == .grid4x8, let index = GridKey.index(keyCode: key.keyCode) {
                guard label(for: key) != nil else { return }
                if !engine.isPending { begin() }
                if index != 31 && engine.phase != .tone { componentCases.append(letterCase) }
                apply(engine.press(index))
            } else if let choice = ASCIIPlusMapping.bindings(for: engine.phase)[key.keyCode] {
                if !engine.isPending { begin() }
                if engine.phase != .tone { componentCases.append(letterCase) }
                apply(engine.selectComponent(choice))
            } else if key.label == ";" {
                // Match the Mac's contextual punctuation behavior.
                apply(engine.finishPartial())
                insertLiteral(";")
            }
        }
    }
    func backspace() {
        edit {
            if engine.isPending {
                if !componentCases.isEmpty { componentCases.removeLast() }
                apply(engine.backspace())
            }
            else { document.deleteBackward(); expected = Position(document) }
        }
    }
    func space() {
        edit {
            let hasPreview = !engine.preview.isEmpty
            apply(engine.finishPartial(suffix: " "))
            if !hasPreview { insertLiteral(" ") }
        }
    }
    func literal(_ text: String) {
        guard CompositionText.isSafe(text) else { return }
        edit { apply(engine.finishPartial()); insertLiteral(text) }
    }
    func newline() {
        edit { apply(engine.finishPartial()); insertLiteral("\n") }
    }
    func finish() { edit { apply(engine.finishPartial()) } }
    func cancel() { edit { apply(engine.cancel()) } }
    func documentDidChange() {
        guard !editing else { return }
        reconcile()
        reloadSettings()
        onChange?()
    }
    private func edit(_ body: () -> Void) {
        guard !editing else { return }
        reconcile()
        reloadSettings()
        editing = true
        body()
        editing = false
        reloadSettings()
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
        componentCases.removeAll(); compositionParts.removeAll()
        recentCommit = nil
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
        recentCommit = nil
        let start = Position(document)
        document.insertText(text)
        expected = start.inserting(text)
    }
    private func apply(_ effect: EngineEffect) {
        switch effect {
        case .marked(let text):
            guard !text.isEmpty || marked else { return }
            compositionParts = engine.components.enumerated().map { index, choice in
                if index == 0 { return engine.inventory.initials[choice] }
                if index == 1 { return engine.inventory.vowelAtoms[choice].label }
                return engine.inventory.finals[choice]
            }
            let visible = text.isEmpty ? originalSelection : cased(compositionParts)
            document.setMarkedText(visible)
            marked = true
            expected = origin?.inserting(visible)
        case .commit(let rawText):
            if let basis = engine.lastCommittedBasis {
                if engine.outputType == .quocNgu { compositionParts = StandardVietnamese.parts(basis) }
                else {
                    let rendered = basis.sieuviet()
                    compositionParts = [basis.initial,
                        String(rendered.dropFirst(basis.initial.count).dropLast(basis.final.count)), basis.final]
                }
            }
            let text = cased(compositionParts) + String(rawText.dropFirst(compositionParts.joined().count))
            if marked {
                document.setMarkedText(text)
                document.unmarkText()
                expected = origin?.inserting(text)
            } else { insertLiteral(text) }
            resetMark()
            recentCommit = text
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
                  (document.selectedText ?? "").isEmpty else { recentCommit = nil; return }
            for _ in text { document.deleteBackward() }
            recentCommit = nil
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
