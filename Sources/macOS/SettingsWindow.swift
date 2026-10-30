import AppKit

private final class ProfilesListView: NSView { override var isFlipped: Bool { true } }

final class ProfileCard: NSView {
    let profileID: UUID
    let input = NSPopUpButton(frame: .zero, pullsDown: false)
    let output = NSPopUpButton(frame: .zero, pullsDown: false)
    private let visibility = NSButton(checkboxWithTitle: "Show virtual keyboard", target: nil, action: nil)
    private let store: KeyboardProfiles

    init(profile: KeyboardProfile, store: KeyboardProfiles) {
        self.profileID = profile.id
        self.store = store
        super.init(frame: NSRect(x: 0, y: 0, width: 620, height: 144))
        wantsLayer = true
        layer?.cornerRadius = 12
        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        layer?.borderWidth = 1
        layer?.borderColor = (store.active.id == profile.id ? NSColor.systemTeal.withAlphaComponent(0.7) : NSColor.separatorColor).cgColor
        let name = NSTextField(labelWithString: profile.name)
        name.font = .systemFont(ofSize: 15, weight: .semibold)
        name.frame = NSRect(x: 18, y: 107, width: 290, height: 22)
        addSubview(name)

        let use = NSButton(title: store.active.id == profile.id ? "Selected" : "Select", target: self, action: #selector(selectProfile))
        use.bezelStyle = .rounded
        use.isEnabled = store.active.id != profile.id
        use.frame = NSRect(x: 426, y: 103, width: 88, height: 30)
        use.setAccessibilityLabel("Select \(profile.name)")
        addSubview(use)
        let remove = NSButton(image: NSImage(systemSymbolName: "minus.circle", accessibilityDescription: "Remove keyboard")!, target: self, action: #selector(removeProfile))
        remove.isBordered = false
        remove.frame = NSRect(x: 564, y: 105, width: 30, height: 28)
        remove.isEnabled = store.profiles.count > 1
        remove.toolTip = remove.isEnabled ? "Remove \(profile.name)" : "Keep at least one keyboard"
        remove.setAccessibilityLabel("Remove \(profile.name)")
        addSubview(remove)

        for (text, x) in [("Input type", 18), ("Output type", 320)] {
            let label = NSTextField(labelWithString: text)
            label.font = .systemFont(ofSize: 12, weight: .medium)
            label.textColor = .secondaryLabelColor
            label.frame = NSRect(x: x, y: 75, width: 270, height: 18)
            addSubview(label)
        }
        input.frame = NSRect(x: 14, y: 38, width: 286, height: 30)
        input.addItems(withTitles: InputType.allCases.map(\.rawValue))
        input.selectItem(withTitle: profile.inputType.rawValue)
        input.target = self
        input.action = #selector(changeInput)
        input.setAccessibilityLabel("Input type for \(profile.name)")
        addSubview(input)
        output.frame = NSRect(x: 316, y: 38, width: 286, height: 30)
        output.addItems(withTitles: OutputType.allCases.map(\.rawValue))
        output.selectItem(withTitle: profile.outputType.rawValue)
        output.target = self
        output.action = #selector(changeOutput)
        output.setAccessibilityLabel("Output type for \(profile.name)")
        addSubview(output)
        visibility.frame = NSRect(x: 18, y: 9, width: 270, height: 22)
        visibility.state = profile.showVirtualKeyboard ? .on : .off
        visibility.target = self
        visibility.action = #selector(changeVisibility)
        visibility.setAccessibilityLabel("Show virtual keyboard for \(profile.name)")
        visibility.toolTip = "When off, only the settings gear appears while typing."
        addSubview(visibility)
        let status = NSTextField(labelWithString: "Settings gear is always available")
        status.font = .systemFont(ofSize: 11)
        status.textColor = .tertiaryLabelColor
        status.frame = NSRect(x: 320, y: 12, width: 280, height: 16)
        addSubview(status)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    @objc private func selectProfile() { store.select(profileID) }
    @objc private func removeProfile() { store.remove(profileID) }
    @objc private func changeInput() {
        if let title = input.titleOfSelectedItem, let type = InputType(rawValue: title) { store.update(profileID, input: type) }
    }
    @objc private func changeOutput() {
        if let title = output.titleOfSelectedItem, let type = OutputType(rawValue: title) { store.update(profileID, output: type) }
    }
    @objc private func changeVisibility() {
        store.update(profileID, showVirtualKeyboard: visibility.state == .on)
    }
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

    private init() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 680, height: 640),
                              styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "viet"
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.delegate = self
        window.center()
        let content = NSView(frame: NSRect(x: 0, y: 0, width: 680, height: 640))
        window.contentView = content
        let title = NSTextField(labelWithString: "Your keyboards")
        title.font = .systemFont(ofSize: 26, weight: .semibold)
        title.frame = NSRect(x: 28, y: 581, width: 430, height: 34)
        content.addSubview(title)
        let subtitle = NSTextField(labelWithString: "Create a keyboard and choose how you type and write.")
        subtitle.font = .systemFont(ofSize: 13)
        subtitle.textColor = .secondaryLabelColor
        subtitle.frame = NSRect(x: 28, y: 552, width: 625, height: 22)
        content.addSubview(subtitle)
        let add = NSButton(title: "Add keyboard", target: self, action: #selector(addKeyboard))
        add.image = NSImage(systemSymbolName: "plus", accessibilityDescription: nil)
        add.imagePosition = .imageLeading
        add.bezelStyle = .rounded
        add.frame = NSRect(x: 510, y: 584, width: 145, height: 30)
        content.addSubview(add)

        scroll.frame = NSRect(x: 28, y: 220, width: 624, height: 309)
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

        let note = NSTextField(wrappingLabelWithString: "grid4x8 and ascii+ support vietmoi and standard Vietnamese output. Standard output adds a space after each syllable. Telex input is coming later.")
        note.font = .systemFont(ofSize: 12)
        note.textColor = .secondaryLabelColor
        note.frame = NSRect(x: 28, y: 160, width: 624, height: 48)
        content.addSubview(note)
        let shiftLabel = NSTextField(labelWithString: "Left Shift tap limit")
        shiftLabel.font = .systemFont(ofSize: 13, weight: .medium)
        shiftLabel.frame = NSRect(x: 28, y: 121, width: 180, height: 20)
        content.addSubview(shiftLabel)
        shiftTapField.frame = NSRect(x: 214, y: 117, width: 85, height: 26)
        shiftTapField.delegate = self
        shiftTapField.target = self
        shiftTapField.action = #selector(saveShiftTap)
        shiftTapField.setAccessibilityLabel("Left Shift tap limit in seconds")
        content.addSubview(shiftTapField)
        let seconds = NSTextField(labelWithString: "seconds")
        seconds.frame = NSRect(x: 307, y: 121, width: 65, height: 20)
        content.addSubview(seconds)
        let reset = NSButton(title: "Reset", target: self, action: #selector(resetShiftTap))
        reset.bezelStyle = .rounded
        reset.frame = NSRect(x: 382, y: 115, width: 78, height: 30)
        reset.toolTip = "Restore the default \(KeyboardPreferences.defaultShiftTapSeconds)-second tap limit"
        reset.setAccessibilityLabel("Reset Shift tap limit")
        content.addSubview(reset)
        shiftTapHint.font = .systemFont(ofSize: 11)
        shiftTapHint.frame = NSRect(x: 28, y: 77, width: 624, height: 32)
        content.addSubview(shiftTapHint)
        showShiftTapPreference()
        let hide = NSButton(title: "Hide & keep typing", target: self, action: #selector(hideSetup))
        hide.bezelStyle = .rounded
        hide.keyEquivalent = "\r"
        hide.frame = NSRect(x: 478, y: 27, width: 180, height: 34)
        content.addSubview(hide)
        let hint = NSTextField(labelWithString: "Reopen with ⚙ in the keyboard popup.")
        hint.font = .systemFont(ofSize: 12)
        hint.textColor = .secondaryLabelColor
        hint.frame = NSRect(x: 28, y: 34, width: 440, height: 20)
        content.addSubview(hint)
        observer = NotificationCenter.default.addObserver(forName: KeyboardProfiles.didChange, object: store, queue: .main) { [weak self] _ in
            self?.reloadProfiles()
        }
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
        shiftTapHint.textColor = error ? .systemRed : .secondaryLabelColor
        shiftTapHint.stringValue = error
            ? "Enter 0.01–5 seconds. Your previous value was kept."
            : "All keyboards · Tap alone to switch modes. Hold or use with another key for normal Shift."
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
    @objc private func addKeyboard() {
        let id = store.add()
        if let card = list.arrangedSubviews.compactMap({ $0 as? ProfileCard }).first(where: { $0.profileID == id }) {
            card.scrollToVisible(card.bounds)
        }
    }
    private func reloadProfiles() {
        for view in list.arrangedSubviews { list.removeArrangedSubview(view); view.removeFromSuperview() }
        for profile in store.profiles {
            let card = ProfileCard(profile: profile, store: store)
            card.translatesAutoresizingMaskIntoConstraints = false
            list.addArrangedSubview(card)
            card.heightAnchor.constraint(equalToConstant: 144).isActive = true
            card.widthAnchor.constraint(equalTo: list.widthAnchor).isActive = true
        }
        list.layoutSubtreeIfNeeded()
    }
}
