import AppKit

private final class ProfilesListView: NSView { override var isFlipped: Bool { true } }

final class ProfileCard: ThemedSurface {
    let profileID: UUID
    let language = NSPopUpButton(frame: .zero, pullsDown: false)
    let input = NSPopUpButton(frame: .zero, pullsDown: false)
    let output = NSPopUpButton(frame: .zero, pullsDown: false)
    private let visibility = NSButton(checkboxWithTitle: AppCopy.text("showKeyboard"), target: nil, action: nil)
    private let suggestions = NSButton(checkboxWithTitle: AppCopy.text("suggestions"), target: nil, action: nil)
    private let store: KeyboardProfiles
    private let profile: KeyboardProfile

    init(profile: KeyboardProfile, store: KeyboardProfiles) {
        self.profileID = profile.id
        self.profile = profile
        self.store = store
        super.init(frame: NSRect(x: 0, y: 0, width: 620, height: 192), radius: AppDesign.panelRadius)
        outline = store.active.id == profile.id ? AppTheme.ink : AppTheme.border
        let name = NSTextField(labelWithString: profile.displayName)
        name.font = AppTheme.font(15, weight: .semibold)
        name.frame = NSRect(x: 18, y: 153, width: 350, height: 22)
        addSubview(name)
        let use = NSButton(title: AppCopy.text(store.active.id == profile.id ? "selected" : "select"), target: self, action: #selector(selectProfile))
        use.bezelStyle = .rounded
        use.isEnabled = store.active.id != profile.id
        use.frame = NSRect(x: 426, y: 149, width: 110, height: 30)
        use.setAccessibilityLabel(AppCopy.text("selectProfile", ["name": profile.displayName]))
        addSubview(use)
        let remove = NSButton(image: NSImage(systemSymbolName: "minus.circle", accessibilityDescription: AppCopy.text("removeKeyboard"))!, target: self, action: #selector(removeProfile))
        remove.isBordered = false
        remove.frame = NSRect(x: 564, y: 151, width: 30, height: 28)
        remove.isEnabled = store.profiles.count > 1
        remove.setAccessibilityLabel(AppCopy.text("removeProfile", ["name": profile.displayName]))
        addSubview(remove)
        for (key, x) in [("keyboardLanguage", 18), ("inputLabel", 222), ("outputLabel", 426)] {
            let label = NSTextField(labelWithString: AppCopy.text(key))
            label.font = AppTheme.font(12, weight: .medium)
            label.textColor = AppTheme.muted
            label.frame = NSRect(x: x, y: 123, width: 180, height: 18)
            addSubview(label)
        }
        for (button, x) in [(language, 14), (input, 218), (output, 422)] {
            button.frame = NSRect(x: x, y: 84, width: 184, height: 30)
            button.target = self
            addSubview(button)
        }
        language.addItems(withTitles: KeyboardLanguage.allCases.map(\.displayName))
        language.selectItem(at: KeyboardLanguage.allCases.firstIndex(of: profile.language)!)
        language.action = #selector(changeKeyboardLanguage)
        language.setAccessibilityLabel(AppCopy.text("keyboardLanguage") + ": " + profile.displayName)
        switch profile.language {
        case .vietnamese:
            input.addItems(withTitles: InputMode.allCases.map(\.displayName))
            input.selectItem(at: InputMode.allCases.firstIndex(of: profile.inputMode)!)
        case .english: input.addItem(withTitle: "QWERTY")
        case .chinese: input.addItem(withTitle: "Microsoft Shuangpin")
        }
        input.isEnabled = profile.language == .vietnamese
        input.action = #selector(changeInput)
        input.setAccessibilityLabel(AppCopy.text("inputProfile", ["name": profile.displayName]))
        output.addItems(withTitles: profile.language.outputs.map(\.displayName))
        output.selectItem(at: profile.language.outputs.firstIndex(of: profile.outputType) ?? 0)
        output.isEnabled = profile.language.outputs.count > 1
        output.action = #selector(changeOutput)
        output.setAccessibilityLabel(AppCopy.text("outputProfile", ["name": profile.displayName]))
        visibility.frame = NSRect(x: 18, y: 22, width: 285, height: 22)
        visibility.state = profile.showVirtualKeyboard ? .on : .off
        visibility.target = self
        visibility.action = #selector(changeVisibility)
        visibility.setAccessibilityLabel(AppCopy.text("showProfile", ["name": profile.displayName]))
        visibility.toolTip = AppCopy.text("hideKeyboardHelp")
        addSubview(visibility)
        suggestions.frame = NSRect(x: 320, y: 22, width: 285, height: 22)
        suggestions.state = profile.suggestionsEnabled ? .on : .off
        suggestions.target = self
        suggestions.action = #selector(changeSuggestions)
        suggestions.setAccessibilityLabel(AppCopy.text("suggestions") + ": " + profile.displayName)
        suggestions.toolTip = AppCopy.text("suggestionsHelp." + profile.language.rawValue)
        addSubview(suggestions)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    @objc private func selectProfile() { store.select(profileID) }
    @objc private func removeProfile() { store.remove(profileID) }
    @objc private func changeKeyboardLanguage() {
        let index = language.indexOfSelectedItem
        if KeyboardLanguage.allCases.indices.contains(index) { store.update(profileID, language: KeyboardLanguage.allCases[index]) }
    }
    @objc private func changeInput() {
        let index = input.indexOfSelectedItem
        if profile.language == .vietnamese, InputMode.allCases.indices.contains(index) {
            store.update(profileID, input: .asciiPlus, inputMode: InputMode.allCases[index])
        }
    }
    @objc private func changeOutput() {
        let index = output.indexOfSelectedItem
        if profile.language.outputs.indices.contains(index) { store.update(profileID, output: profile.language.outputs[index]) }
    }
    @objc private func changeVisibility() { store.update(profileID, showVirtualKeyboard: visibility.state == .on) }
    @objc private func changeSuggestions() { store.update(profileID, suggestionsEnabled: suggestions.state == .on) }
}

final class SettingsWindow: NSWindowController, NSWindowDelegate, NSTextFieldDelegate {
    static let shared = SettingsWindow()
    private let store = KeyboardProfiles.shared
    private let list = NSStackView()
    private let scroll = NSScrollView()
    private let preferences = KeyboardPreferences.shared
    private let shiftTapField = NSTextField()
    private let shiftTapHint = NSTextField(wrappingLabelWithString: "")
    private var observer: NSObjectProtocol?
    private let language = NSPopUpButton(frame: .zero, pullsDown: false)

    private init() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 680, height: 640),
                              styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = AppDesign.name
        window.backgroundColor = AppTheme.background
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.delegate = self
        window.center()
        AppCopy.language = preferences.language
        buildContent()
        observer = NotificationCenter.default.addObserver(forName: KeyboardProfiles.didChange, object: store, queue: .main) { [weak self] _ in self?.reloadProfiles() }
    }
    private func buildContent() {
        guard let window = window else { return }
        let content = NSView(frame: NSRect(x: 0, y: 0, width: 680, height: 640))
        window.contentView = content
        let title = NSTextField(labelWithString: "★ " + AppDesign.name)
        title.font = AppTheme.font(26, weight: .semibold)
        title.frame = NSRect(x: 28, y: 581, width: 430, height: 34)
        content.addSubview(title)
        let subtitle = NSTextField(labelWithString: AppCopy.text("tagline"))
        subtitle.font = AppTheme.font(13)
        subtitle.textColor = AppTheme.muted
        subtitle.frame = NSRect(x: 28, y: 552, width: 625, height: 22)
        content.addSubview(subtitle)
        let add = NSButton(title: AppCopy.text("addKeyboard"), target: self, action: #selector(addKeyboard))
        add.image = NSImage(systemSymbolName: "plus", accessibilityDescription: nil)
        add.imagePosition = .imageLeading
        add.bezelStyle = .rounded
        add.frame = NSRect(x: 510, y: 584, width: 145, height: 30)
        content.addSubview(add)

        scroll.frame = NSRect(x: 28, y: 268, width: 624, height: 261)
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        list.orientation = .vertical
        list.alignment = .leading
        list.spacing = 12
        list.translatesAutoresizingMaskIntoConstraints = false
        let document = ProfilesListView()
        document.translatesAutoresizingMaskIntoConstraints = false
        document.addSubview(list)
        scroll.documentView = document
        NSLayoutConstraint.activate([
            document.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor),
            list.leadingAnchor.constraint(equalTo: document.leadingAnchor),
            list.trailingAnchor.constraint(equalTo: document.trailingAnchor, constant: -4),
            list.topAnchor.constraint(equalTo: document.topAnchor),
            list.bottomAnchor.constraint(equalTo: document.bottomAnchor, constant: -8)
        ])
        content.addSubview(scroll)

        let languageLabel = NSTextField(labelWithString: AppCopy.text("language"))
        languageLabel.font = AppTheme.font(13)
        languageLabel.frame = NSRect(x: 28, y: 232, width: 280, height: 20)
        content.addSubview(languageLabel)
        language.frame = NSRect(x: 320, y: 226, width: 280, height: 30)
        language.removeAllItems()
        language.addItems(withTitles: [AppCopy.text("vietnamese"), AppCopy.text("english")])
        language.selectItem(at: preferences.language == "en" ? 1 : 0)
        language.target = self; language.action = #selector(changeLanguage)
        language.setAccessibilityLabel(AppCopy.text("language"))
        content.addSubview(language)
        let note = NSTextField(wrappingLabelWithString: AppCopy.text("roundHelp"))
        note.font = AppTheme.font(12)
        note.textColor = AppTheme.muted
        note.frame = NSRect(x: 28, y: 160, width: 624, height: 48)
        content.addSubview(note)
        let shiftLabel = NSTextField(labelWithString: AppCopy.text("shiftLimit"))
        shiftLabel.font = AppTheme.font(13, weight: .medium)
        shiftLabel.frame = NSRect(x: 28, y: 121, width: 250, height: 20)
        content.addSubview(shiftLabel)
        shiftTapField.frame = NSRect(x: 280, y: 117, width: 85, height: 26)
        shiftTapField.delegate = self
        shiftTapField.target = self
        shiftTapField.action = #selector(saveShiftTap)
        shiftTapField.setAccessibilityLabel(AppCopy.text("shiftLimit"))
        content.addSubview(shiftTapField)
        let seconds = NSTextField(labelWithString: AppCopy.text("seconds"))
        seconds.frame = NSRect(x: 375, y: 121, width: 65, height: 20)
        content.addSubview(seconds)
        let reset = NSButton(title: AppCopy.text("reset"), target: self, action: #selector(resetShiftTap))
        reset.bezelStyle = .rounded
        reset.frame = NSRect(x: 466, y: 115, width: 130, height: 30)
        reset.toolTip = AppCopy.text("resetShiftHelp", ["seconds": String(KeyboardPreferences.defaultShiftTapSeconds)])
        reset.setAccessibilityLabel(AppCopy.text("resetShift"))
        content.addSubview(reset)
        shiftTapHint.font = AppTheme.font(11)
        shiftTapHint.frame = NSRect(x: 28, y: 77, width: 624, height: 32)
        content.addSubview(shiftTapHint)
        showShiftTapPreference()
        let hide = NSButton(title: AppCopy.text("hideAndType"), target: self, action: #selector(hideSetup))
        hide.bezelStyle = .rounded
        hide.keyEquivalent = "\r"
        hide.frame = NSRect(x: 478, y: 27, width: 180, height: 34)
        content.addSubview(hide)
        let hint = NSTextField(labelWithString: AppCopy.text("reopenHelp"))
        hint.font = AppTheme.font(12)
        hint.textColor = AppTheme.muted
        hint.frame = NSRect(x: 28, y: 30, width: 400, height: 38)
        hint.lineBreakMode = .byWordWrapping
        hint.maximumNumberOfLines = 2
        content.addSubview(hint)
        applyTypography(to: content)
        reloadProfiles()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func open() {
        showShiftTapPreference()
        store.hasOpenedSetup = true
        NSApp.setActivationPolicy(.regular)
        KeyboardPanel.shared.hide()
        showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
    @objc func hideSetup() {
        window?.makeFirstResponder(nil)
        window?.orderOut(nil)
        NSApp.setActivationPolicy(.accessory)
        NSApp.hide(nil)
    }
    func windowShouldClose(_ sender: NSWindow) -> Bool { hideSetup(); return false }
    private func showShiftTapPreference(error: Bool = false) {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 3
        shiftTapField.stringValue = formatter.string(from: NSNumber(value: preferences.shiftTapSeconds)) ?? "0.20"
        shiftTapHint.textColor = error ? .systemRed : AppTheme.muted
        shiftTapHint.stringValue = error
            ? AppCopy.text("shiftLimitError")
            : AppCopy.text("shiftLimitHelp")
    }
    @objc private func saveShiftTap() {
        let value = shiftTapField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: Locale.current.decimalSeparator ?? ".", with: ".")
        let accepted = Double(value).map { preferences.setShiftTapSeconds($0) } ?? false
        showShiftTapPreference(error: !accepted)
    }
    @objc private func resetShiftTap() {
        window?.makeFirstResponder(nil)
        preferences.resetShiftTapSeconds()
        showShiftTapPreference()
    }
    func controlTextDidEndEditing(_ notification: Notification) {
        if notification.object as? NSTextField === shiftTapField { saveShiftTap() }
    }
    @objc private func changeLanguage() {
        window?.makeFirstResponder(nil)
        preferences.language = language.indexOfSelectedItem == 1 ? "en" : "vi"
        AppCopy.language = preferences.language
        buildContent()
        NotificationCenter.default.post(name: AppCopy.didChange, object: nil)
    }
    @objc private func addKeyboard() {
        let id = store.add()
        if let card = list.arrangedSubviews.compactMap({ $0 as? ProfileCard }).first(where: { $0.profileID == id }) {
            card.scrollToVisible(card.bounds)
        }
    }
    private func applyTypography(to view: NSView) {
        if let control = view as? NSControl, !(control is NSTextField) { control.font = AppTheme.font(12) }
        if let label = view as? NSTextField, label.textColor == .labelColor { label.textColor = AppTheme.ink }
        for child in view.subviews { applyTypography(to: child) }
    }
    private func reloadProfiles() {
        for view in list.arrangedSubviews { list.removeArrangedSubview(view); view.removeFromSuperview() }
        for profile in store.profiles {
            let card = ProfileCard(profile: profile, store: store)
            applyTypography(to: card)
            card.translatesAutoresizingMaskIntoConstraints = false
            list.addArrangedSubview(card)
            card.heightAnchor.constraint(equalToConstant: 192).isActive = true
            card.widthAnchor.constraint(equalTo: list.widthAnchor).isActive = true
        }
        list.layoutSubtreeIfNeeded()
    }
}
