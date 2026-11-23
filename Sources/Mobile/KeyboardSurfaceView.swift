import UIKit

// The app's practice editor and the system keyboard use this same touch surface.
final class KeyboardSurfaceView: UIInputView {
    let session: MobileInputSession
    let globe = KeyboardKeyButton(type: .custom)
    private var currentRows: [[UInt16]] = []
    private var keys: [(ASCIIKey, KeyboardKeyButton)] = []
    private var symbols: [(String, KeyboardKeyButton)] = []
    private let numbers = KeyboardKeyButton(type: .custom)
    private let moreSymbols = KeyboardKeyButton(type: .custom)
    private let space = KeyboardKeyButton(type: .custom)
    private let comma = KeyboardKeyButton(type: .custom)
    private let period = KeyboardKeyButton(type: .custom)
    private let backspace = KeyboardKeyButton(type: .custom)
    private let enter = KeyboardKeyButton(type: .custom)
    private var shift = MobileShiftState()
    private var symbolState = MobileSymbolState()
    private var showingSymbols: Bool { symbolState.page != .letters }
    private var uppercase: Bool { shift.uppercase }
    private var symbolValues: [String] {
        let rows = TouchKeyboardSymbols.pages[symbolState.page == .symbols ? 1 : 0]
        return rows.flatMap { $0.map(String.init) }
    }
    private var repeatTimer: Timer?
    var showGlobe = false { didSet { if oldValue != showGlobe { setNeedsLayout() } } }
    var preferredHeight: CGFloat {
        let rows = showingSymbols ? 3 : session.rows.count
        return CGFloat(rows + 1) * (bounds.width > 600 ? 42 : 48)
    }

    init(session: MobileInputSession) {
        self.session = session
        super.init(frame: CGRect(x: 0, y: 0, width: 390, height: CGFloat(session.rows.count + 1) * 48), inputViewStyle: .keyboard)
        accessibilityIdentifier = "keyboard.surface"
        autoresizingMask = [.flexibleWidth]
        allowsSelfSizing = true
        isMultipleTouchEnabled = true
        // Keep the same paper surface as the desktop guide and Android IME.
        backgroundColor = AppTheme.background
        for (index, text) in symbolValues.enumerated() {
            let button = makeButton(identifier: "symbol.\(index)")
            addTypingAction(button, commitOnTouchDown: true) { [weak self] _ in
                guard let self = self else { return }
                self.session.literal(self.symbolValues[index])
            }
            symbols.append((text, button))
        }
        configurePanel(numbers, page: .numbers, title: "123", id: "keyboard.numbers")
        configurePanel(moreSymbols, page: .symbols, title: "#+=", id: "keyboard.moreSymbols")
        configureTyping(space, title: "", id: "keyboard.space") { [weak self] _ in self?.session.space() }
        configureTyping(comma, title: ",", id: "keyboard.comma") { [weak self] _ in self?.session.literal(",") }
        configureTyping(period, title: ".", id: "keyboard.period") { [weak self] _ in self?.session.literal(".") }
        configureTyping(enter, title: "", id: "keyboard.return") { [weak self] _ in self?.session.newline() }
        enter.setImage(UIImage(systemName: "return"), for: .normal)
        style(backspace, id: "keyboard.backspace")
        backspace.setImage(UIImage(systemName: "delete.left"), for: .normal)
        backspace.accessibilityLabel = AppCopy.text("backspace")
        backspace.addTarget(self, action: #selector(startDeleting), for: .touchDown)
        backspace.addTarget(self, action: #selector(stopDeleting), for: [.touchUpInside, .touchUpOutside, .touchCancel, .touchDragExit])
        style(globe, id: "keyboard.globe")
        globe.setImage(UIImage(systemName: "globe"), for: .normal)
        globe.accessibilityLabel = AppCopy.text("nextKeyboard")
        globe.addAction(UIAction { [weak self] _ in self?.session.finish() }, for: .touchDown)
        session.onChange = { [weak self] in self?.render() }
        render()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override var intrinsicContentSize: CGSize { CGSize(width: UIView.noIntrinsicMetric, height: preferredHeight) }
    override func layoutSubviews() {
        super.layoutSubviews()
        let width = bounds.width
        let margin: CGFloat = 5
        let columns = showingSymbols ? 10 : (session.rows.map(\.count).max() ?? 10)
        let unit = (width - 2 * margin) / CGFloat(columns)
        let compact = width > 600
        let rowHeight: CGFloat = compact ? 42 : 48
        // Anchor to the bottom even when a host gives the input view extra height.
        // Leave only the same 3-point gutter used between rows.
        let rowCount = showingSymbols ? 3 : session.rows.count
        let header = max(3, bounds.height - CGFloat(rowCount + 1) * rowHeight + 3)
        for (rowIndex, row) in session.rows.enumerated() {
            for (column, key) in row.enumerated() {
                keys.first { $0.0.keyCode == key.keyCode }?.1.frame = CGRect(
                    x: margin + CGFloat(column) * unit + 2, y: header + CGFloat(rowIndex) * rowHeight,
                    width: unit - 4, height: rowHeight - 6)
            }
        }
        // Fill the Mac guide's two unused bottom cells with touch editing keys.
        let grid = session.input == .grid4x8 && !session.ascii && !showingSymbols
        let editY = grid ? header + CGFloat(session.rows.count) * rowHeight : header + 2 * rowHeight
        let editWidth = grid ? max(33, width / 10) : unit - 4
        backspace.frame = CGRect(x: grid ? width - 2 * editWidth - margin - 6 : margin + 8 * unit + 2,
                                 y: editY, width: editWidth, height: rowHeight - 6)
        enter.frame = CGRect(x: grid ? width - editWidth - margin - 2 : margin + 9 * unit + 2,
                             y: editY, width: editWidth, height: rowHeight - 6)
        for (index, entry) in symbols.enumerated() {
            entry.1.frame = CGRect(x: margin + CGFloat(index % 10) * unit + 2, y: header + CGFloat(index / 10) * rowHeight,
                                   width: unit - 4, height: rowHeight - 6)
        }
        let footerY = header + CGFloat(showingSymbols ? 3 : session.rows.count) * rowHeight
        let footerHeight: CGFloat = compact ? 42 : 48
        let controlWidth = max(33, unit * 1.1)
        var x: CGFloat = margin + 2
        for button in [numbers, globe, moreSymbols] {
            let visible = button !== globe || showGlobe
            button.isHidden = !visible
            if visible { button.frame = CGRect(x: x, y: footerY, width: controlWidth, height: footerHeight - 6); x += controlWidth + 4 }
        }
        period.isHidden = grid
        comma.isHidden = grid
        period.frame = CGRect(x: width - margin - controlWidth, y: footerY, width: controlWidth - 2, height: footerHeight - 6)
        comma.frame = CGRect(x: period.frame.minX - controlWidth - 4, y: footerY, width: controlWidth, height: footerHeight - 6)
        space.frame = CGRect(x: x, y: footerY, width: max(30, (grid ? backspace.frame.minX : comma.frame.minX) - x - 4), height: footerHeight - 6)
    }
    func render() {
        UIView.performWithoutAnimation { renderImmediately() }
    }
    private func renderImmediately() {
        space.setTitle(nil, for: .normal)
        space.accessibilityLabel = AppCopy.text("space")
        enter.setTitle(nil, for: .normal)
        enter.accessibilityLabel = AppCopy.text("return")
        backspace.accessibilityLabel = AppCopy.text("backspace")
        globe.accessibilityLabel = AppCopy.text("nextKeyboard")
        comma.accessibilityLabel = AppCopy.text("comma")
        period.accessibilityLabel = AppCopy.text("period")
        numbers.accessibilityLabel = AppCopy.text("numbersSymbols")
        moreSymbols.accessibilityLabel = AppCopy.text("moreSymbols")
        let rows = session.rows
        let rowIDs = rows.map { $0.map(\.keyCode) }
        if currentRows != rowIDs {
            for entry in keys { entry.1.removeFromSuperview() }
            keys.removeAll()
            currentRows = rowIDs
            for row in rows {
                for key in row {
                    let button = makeButton(identifier: "key.\(key.label)")
                    if key.keyCode == 56 { configureShift(button) }
                    else {
                        addTypingAction(button) { [weak self] letterCase in self?.session.press(key, letterCase: letterCase) }
                    }
                    keys.append((key, button))
                }
            }
        }
        for (key, button) in keys {
            let action = session.label(for: key)
            button.isHidden = showingSymbols
            button.isEnabled = action != nil
            let title = key.keyCode != 56 && action != "Clear" ? action.map { shift.letterCase.apply($0) } : action
            button.setTitle(key.keyCode == 56 ? nil : (title == "Clear" ? AppCopy.text("clear") : title ?? ""), for: .normal)
            if key.keyCode == 56 {
                button.setImage(UIImage(systemName: shift.capsLock ? "capslock.fill" : (uppercase ? "shift.fill" : "shift")), for: .normal)
                button.isSelected = uppercase
                button.accessibilityLabel = AppCopy.text("shift") + ", " + session.accessibilityLabel(for: key)
                button.accessibilityValue = AppCopy.text(shift.capsLock ? "capsLock" : (uppercase ? "uppercaseNext" : "lowercase"))
            } else {
                button.accessibilityLabel = session.accessibilityLabel(for: key)
            }
            button.isUtility = key.keyCode == 56
            button.keyPosition = key.label
            button.titleLabel?.font = AppTheme.font((title?.count ?? 0) > 3 ? 11 : 19, weight: .regular)
        }
        for (index, entry) in symbols.enumerated() {
            entry.1.isHidden = !showingSymbols
            entry.1.setTitle(symbolValues[index], for: .normal)
            entry.1.accessibilityLabel = symbolValues[index]
        }
        numbers.isSelected = symbolState.page == .numbers
        moreSymbols.isSelected = symbolState.page == .symbols
        setNeedsLayout()
        invalidateIntrinsicContentSize()
    }
    @objc private func startDeleting() {
        shift.keyBegan(); symbolState.typed()
        session.backspace()
        stopDeleting()
        repeatTimer = Timer.scheduledTimer(timeInterval: 0.42, target: self, selector: #selector(beginRepeatingDelete), userInfo: nil, repeats: false)
    }
    @objc private func beginRepeatingDelete() {
        repeatTimer = Timer.scheduledTimer(timeInterval: 0.09, target: self, selector: #selector(repeatDelete), userInfo: nil, repeats: true)
    }
    @objc private func repeatDelete() { session.backspace() }
    @objc private func stopDeleting() { repeatTimer?.invalidate(); repeatTimer = nil }
    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil {
            stopDeleting(); shift.cancelHold(); symbolState.cancelHold(); render()
        }
    }
    private func configureShift(_ button: KeyboardKeyButton) {
        button.addAction(UIAction { [weak self] _ in
            guard let self = self else { return }
            let time = ProcessInfo.processInfo.systemUptime
            self.shift.begin(at: time)
            self.render()
        }, for: .touchDown)
        button.addAction(UIAction { [weak self] _ in
            guard let self = self else { return }
            let wasLocked = self.shift.capsLock
            self.shift.end(at: ProcessInfo.processInfo.systemUptime)
            if self.shift.takeModeTap() {
                // A double tap enables Caps Lock and returns to the keyboard chosen before its first tap.
                if self.shift.capsLock && !wasLocked { self.session.selectPreviousKeyboard() }
                else { self.session.press(ASCIIKey(label: "Shift", keyCode: 56)) }
            }
            self.render()
        }, for: [.touchUpInside, .touchUpOutside])
        button.addAction(UIAction { [weak self] _ in
            self?.shift.cancelHold(); self?.render()
        }, for: .touchCancel)
    }
    private func configurePanel(_ button: KeyboardKeyButton, page: MobileSymbolState.Page, title: String, id: String) {
        style(button, id: id)
        button.setTitle(title, for: .normal)
        button.addAction(UIAction { [weak self] _ in
            guard let self = self else { return }
            self.shift.keyBegan()
            self.session.finish()
            self.symbolState.begin(page, at: ProcessInfo.processInfo.systemUptime); self.render()
        }, for: .touchDown)
        button.addAction(UIAction { [weak self] _ in
            guard let self = self else { return }
            self.symbolState.end(page, at: ProcessInfo.processInfo.systemUptime); self.render()
        }, for: [.touchUpInside, .touchUpOutside])
        button.addAction(UIAction { [weak self] _ in
            guard let self = self else { return }
            self.symbolState.end(page, at: ProcessInfo.processInfo.systemUptime, cancelled: true); self.render()
        }, for: .touchCancel)
    }
    private func configureTyping(_ button: KeyboardKeyButton, title: String, id: String, action: @escaping (MobileLetterCase) -> Void) {
        style(button, id: id); button.setTitle(title, for: .normal)
        addTypingAction(button, action: action)
    }
    private func addTypingAction(_ button: KeyboardKeyButton, commitOnTouchDown: Bool = false, action: @escaping (MobileLetterCase) -> Void) {
        if commitOnTouchDown {
            button.addAction(UIAction { [weak self] _ in
                guard let self = self else { return }
                let letterCase = self.shift.typed()
                self.symbolState.typed()
                action(letterCase); self.render()
            }, for: .touchDown)
            return
        }
        button.addAction(UIAction { [weak self] _ in
            guard let self = self else { return }
            self.shift.keyBegan()
        }, for: .touchDown)
        button.addAction(UIAction { [weak self] _ in
            guard let self = self else { return }
            let letterCase = self.shift.typed()
            self.symbolState.typed()
            action(letterCase); self.render()
        }, for: .touchUpInside)
    }
    private func makeButton(identifier: String) -> KeyboardKeyButton {
        let button = KeyboardKeyButton(type: .custom)
        style(button, id: identifier)
        button.isUtility = false
        return button
    }
    private func style(_ button: KeyboardKeyButton, id: String) {
        button.accessibilityIdentifier = id
        button.isUtility = button !== space && button !== comma && button !== period
        button.titleLabel?.font = AppTheme.font(13, weight: .regular)
        button.titleLabel?.adjustsFontSizeToFitWidth = true
        button.titleLabel?.minimumScaleFactor = 0.6
        button.isExclusiveTouch = false
        button.tintColor = AppTheme.ink
        addSubview(button)
    }
}

// Custom buttons avoid UIButton.system's title/image crossfade between rounds.
// Highlight feedback is immediate too; no animation or delayed label replacement.
final class KeyboardKeyButton: UIButton {
    var keyPosition = "" { didSet { updateAppearance() } }
    var isUtility = false { didSet { updateAppearance() } }
    override var isHighlighted: Bool { didSet { updateAppearance() } }
    override var isEnabled: Bool { didSet { updateAppearance() } }
    override var isSelected: Bool { didSet { updateAppearance() } }

    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.cornerRadius = AppDesign.keyRadius
        layer.borderWidth = AppDesign.borderWidth
        updateAppearance()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func accessibilityActivate() -> Bool {
        guard isEnabled else { return false }
        sendActions(for: .touchDown)
        sendActions(for: .touchUpInside)
        return true
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) { updateAppearance() }
    }
    private func updateAppearance() {
        UIView.performWithoutAnimation {
            let color = AppTheme.keyColor(keyPosition)
            let pressed = isHighlighted || isSelected
            backgroundColor = pressed ? color : AppTheme.surface
            layer.borderColor = color.resolvedColor(with: traitCollection).cgColor
            setTitleColor(pressed ? AppTheme.background : color, for: .normal)
            setTitleColor(AppTheme.muted, for: .disabled)
            alpha = isEnabled ? 1 : 0.35
            tintColor = pressed ? AppTheme.background : color
        }
    }
}
