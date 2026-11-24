import UIKit

// The app's practice editor and the system keyboard use this same touch surface.
final class KeyboardSurfaceView: UIInputView {
    let session: MobileInputSession
    let globe = KeyboardKeyButton(type: .custom)
    private var currentRows: [[UInt16]] = []
    private var keys: [(ASCIIKey, KeyboardKeyButton)] = []
    private var keyButtonsByCode: [UInt16: KeyboardKeyButton] = [:]
    private var lastPreferredHeight: CGFloat = 0
    private var symbols: [(String, KeyboardKeyButton)] = []
    private let numbers = KeyboardKeyButton(type: .custom)
    private let moreSymbols = KeyboardKeyButton(type: .custom)
    private let space = KeyboardKeyButton(type: .custom)
    private let comma = KeyboardKeyButton(type: .custom)
    private let period = KeyboardKeyButton(type: .custom)
    private let backspace = KeyboardKeyButton(type: .custom)
    private let enter = KeyboardKeyButton(type: .custom)
    private let candidateBar = UIView()
    private let candidateDivider = UIView()
    private var candidateButtons: [KeyboardKeyButton] = []
    private var shift = MobileShiftState()
    private var symbolState = MobileSymbolState()
    private var showingSymbols: Bool { symbolState.page != .letters }
    private var uppercase: Bool { shift.uppercase }
    private var symbolValues: [String] {
        let rows = TouchKeyboardSymbols.pages[symbolState.page == .symbols ? 1 : 0]
        return rows.flatMap { $0.map(String.init) }
    }
    private var typingButtons = Set<KeyboardKeyButton>()
    private var trackedTouches: [UITouch: KeyboardKeyButton] = [:]
    private let keyPopup = KeyPressPopup()
    private var repeatTimer: Timer?
    private var spaceCursorX: CGFloat?
    private var spaceCursorY: CGFloat?
    private var spaceCursorRemainder: CGFloat = 0
    private var spaceCursorVerticalRemainder: CGFloat = 0
    var showGlobe = false { didSet { if oldValue != showGlobe { setNeedsLayout() } } }
    var preferredHeight: CGFloat {
        let rows = showingSymbols ? 3 : session.rows.count
        return CGFloat(rows + 1) * (bounds.width > 600 ? 42 : 48) + (session.suggestionsEnabled ? 38 : 0)
    }

    init(session: MobileInputSession) {
        self.session = session
        let initialHeight = CGFloat(session.rows.count + 1) * 48 + (session.suggestionsEnabled ? 38 : 0)
        super.init(frame: CGRect(x: 0, y: 0, width: 390, height: initialHeight), inputViewStyle: .keyboard)
        accessibilityIdentifier = "keyboard.surface"
        autoresizingMask = [.flexibleWidth]
        allowsSelfSizing = true
        isMultipleTouchEnabled = true
        clipsToBounds = false
        keyPopup.isHidden = true
        addSubview(keyPopup)
        // Keep the same paper surface as the desktop guide and Android IME.
        backgroundColor = AppTheme.background
        candidateBar.backgroundColor = AppTheme.surface
        candidateBar.clipsToBounds = true
        candidateBar.accessibilityIdentifier = "suggestion.bar"
        candidateDivider.backgroundColor = AppTheme.border
        candidateBar.addSubview(candidateDivider)
        addSubview(candidateBar)
        for index in 0..<16 {
            let button = makeButton(identifier: "suggestion.\(index)")
            candidateBar.addSubview(button)
            button.titleLabel?.font = AppTheme.font(15, weight: .medium)
            button.addAction(UIAction { [weak self] _ in self?.session.selectSuggestion(at: index) }, for: .touchUpInside)
            candidateButtons.append(button)
        }
        for (index, text) in symbolValues.enumerated() {
            let button = makeButton(identifier: "symbol.\(index)")
            addTypingAction(button) { [weak self] _ in
                guard let self = self else { return }
                self.session.literal(self.symbolValues[index])
            }
            symbols.append((text, button))
        }
        configurePanel(numbers, page: .numbers, title: "123", id: "keyboard.numbers")
        configurePanel(moreSymbols, page: .symbols, title: "#+=", id: "keyboard.moreSymbols")
        configureTyping(space, title: "", id: "keyboard.space") { [weak self] _ in self?.session.space() }
        let cursorGesture = UILongPressGestureRecognizer(target: self, action: #selector(trackSpaceCursor(_:)))
        cursorGesture.minimumPressDuration = 0.35
        cursorGesture.allowableMovement = 18
        cursorGesture.cancelsTouchesInView = true
        space.addGestureRecognizer(cursorGesture)
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
        updatePreferredHeight()
        let width = bounds.width
        let margin: CGFloat = 5
        let columns = showingSymbols ? 10 : (session.rows.map(\.count).max() ?? 10)
        let unit = (width - 2 * margin) / CGFloat(columns)
        let compact = width > 600
        let rowCount = showingSymbols ? 3 : session.rows.count
        let suggestionHeight: CGFloat = session.suggestionsEnabled ? 38 : 0
        // The host can retain the old input-view height during a settings change
        // or rotation. Keep the suggestion strip separate even in that interval.
        let rowHeight = min(compact ? 42 : 48,
                            max(0, bounds.height - suggestionHeight) / CGFloat(rowCount + 1))
        // Anchor to the bottom even when a host gives the input view extra height.
        // Leave only the same 3-point gutter used between rows.
        let header = max(suggestionHeight + 3, bounds.height - CGFloat(rowCount + 1) * rowHeight + 3)
        let candidates = session.suggestions
        candidateBar.isHidden = !session.suggestionsEnabled || candidates.isEmpty
        candidateBar.frame = CGRect(x: 0, y: max(0, header - 38), width: width, height: 38)
        candidateDivider.frame = CGRect(x: 0, y: candidateBar.bounds.height - 1, width: width, height: 1)
        var candidateX = margin
        for (index, button) in candidateButtons.enumerated() {
            guard session.suggestionsEnabled, candidates.indices.contains(index) else { button.isHidden = true; continue }
            let text = candidates[index]
            let desired = min(width * 0.55, max(52, (text as NSString).size(withAttributes: [.font: AppTheme.font(15, weight: .medium)]).width + 26))
            guard candidateX + desired <= width - margin else { button.isHidden = true; continue }
            button.isHidden = false
            button.frame = CGRect(x: candidateX, y: 3, width: desired, height: 32)
            candidateX += desired + 5
        }
        for (rowIndex, row) in session.rows.enumerated() {
            for (column, key) in row.enumerated() {
                keyButtonsByCode[key.keyCode]?.frame = CGRect(
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
        let footerHeight = rowHeight
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
        let candidates = session.suggestions
        for (index, button) in candidateButtons.enumerated() {
            let title = candidates.indices.contains(index) ? candidates[index] : ""
            button.setTitle(title, for: .normal)
            button.accessibilityLabel = title
        }
        let rows = session.rows
        let rowIDs = rows.map { $0.map(\.keyCode) }
        if currentRows != rowIDs {
            clearTouches()
            for entry in keys { typingButtons.remove(entry.1); entry.1.removeFromSuperview() }
            keys.removeAll()
            keyButtonsByCode.removeAll()
            currentRows = rowIDs
            for row in rows {
                for key in row {
                    let button = makeButton(identifier: "key.\(key.label)")
                    if key.keyCode == 56 { configureShift(button) }
                    else {
                        addTypingAction(button) { [weak self] letterCase in self?.session.press(key, letterCase: letterCase) }
                    }
                    keys.append((key, button))
                    keyButtonsByCode[key.keyCode] = button
                }
            }
        }
        for (key, button) in keys {
            let action = session.label(for: key)
            button.isHidden = showingSymbols
            button.isEnabled = action != nil
            let title = key.keyCode != 56 && action != "Clear" ? action.map { shift.letterCase.apply($0) } : action
            let visibleTitle = key.keyCode == 56 ? nil : (title == "Clear" ? AppCopy.text("clear") : title ?? "")
            if button.title(for: .normal) != visibleTitle { button.setTitle(visibleTitle, for: .normal) }
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
        // A second finger can complete a round while another is still held.
        // Re-target that held touch against the newly enabled keys as well.
        for (touch, previous) in trackedTouches {
            if let target = nearestButton(to: touch.location(in: self), typingOnly: true), target !== previous {
                previous.isHighlighted = false
                target.isHighlighted = true
                trackedTouches[touch] = target
            }
        }
        if let held = trackedTouches.values.first { showPopup(for: held) }
        setNeedsLayout()
        updatePreferredHeight()
    }
    private func updatePreferredHeight() {
        if lastPreferredHeight != preferredHeight {
            lastPreferredHeight = preferredHeight
            // Practice input views are sized from their frame by UIKit; the
            // system extension instead supplies its own height constraint.
            if translatesAutoresizingMaskIntoConstraints { frame.size.height = preferredHeight }
            invalidateIntrinsicContentSize()
        }
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
    @objc private func trackSpaceCursor(_ gesture: UILongPressGestureRecognizer) {
        let point = gesture.location(in: self)
        let x = point.x
        switch gesture.state {
        case .began:
            shift.keyBegan(); symbolState.typed()
            session.beginCursorMovement()
            spaceCursorX = x
            spaceCursorY = point.y
            spaceCursorRemainder = 0
            spaceCursorVerticalRemainder = 0
            space.isSelected = true
        case .changed:
            guard let previous = spaceCursorX, let previousY = spaceCursorY else { return }
            spaceCursorRemainder += x - previous
            spaceCursorVerticalRemainder += point.y - previousY
            spaceCursorX = x
            spaceCursorY = point.y
            let stepWidth = max(10, min(16, space.bounds.height * 0.28))
            let steps = Int(spaceCursorRemainder / stepWidth)
            if steps != 0 {
                spaceCursorRemainder -= CGFloat(steps) * stepWidth
                session.moveCursor(by: steps)
            }
            // The spacebar sits near the bottom edge, so downward travel has
            // less room than upward travel. A short step works in both directions.
            let lineHeight = spaceCursorVerticalRemainder > 0
                ? max(14, min(20, space.bounds.height * 0.4))
                : max(24, space.bounds.height * 0.65)
            let lines = Int(spaceCursorVerticalRemainder / lineHeight)
            if lines != 0 {
                spaceCursorVerticalRemainder -= CGFloat(lines) * lineHeight
                session.moveCursorVertically(by: lines)
            }
        case .ended, .cancelled, .failed:
            spaceCursorX = nil
            spaceCursorY = nil
            spaceCursorRemainder = 0
            spaceCursorVerticalRemainder = 0
            space.isSelected = false
            session.endCursorMovement()
        default: break
        }
    }
    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil {
            clearTouches()
            stopDeleting(); shift.cancelHold(); symbolState.cancelHold()
            spaceCursorX = nil; spaceCursorY = nil; spaceCursorRemainder = 0; spaceCursorVerticalRemainder = 0; space.isSelected = false
            render()
        }
    }
    private func activeButtons(typingOnly: Bool = false) -> [KeyboardKeyButton] {
        let all = keys.map { $0.1 } + symbols.map { $0.1 } + [numbers, moreSymbols, space, comma, period, backspace, enter, globe] + candidateButtons
        return all.filter { button in
            !button.isHidden && !button.superview!.isHidden && button.isEnabled && button.alpha > 0 &&
            (!typingOnly || typingButtons.contains(button))
        }
    }
    private func nearestButton(to point: CGPoint, typingOnly: Bool = false) -> KeyboardKeyButton? {
        let buttons = activeButtons(typingOnly: typingOnly)
        let frames = buttons.map { $0.convert($0.bounds, to: self) }
        return KeyboardHitTesting.nearest(to: point, frames: frames).map { buttons[$0] }
    }
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard bounds.contains(point), isUserInteractionEnabled, !isHidden else { return nil }
        guard let button = nearestButton(to: point) else { return self }
        // A single touch owner allows the finger to cross visual key borders.
        // Utility keys keep native tracking, long press, and repeat behavior.
        return typingButtons.contains(button) && button !== space ? self : button
    }
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            guard let button = nearestButton(to: touch.location(in: self), typingOnly: true) else { continue }
            trackedTouches[touch] = button
            button.isHighlighted = true
            button.sendActions(for: .touchDown)
            showPopup(for: button)
        }
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            guard let previous = trackedTouches[touch],
                  let button = nearestButton(to: touch.location(in: self), typingOnly: true) else { continue }
            if previous !== button {
                previous.isHighlighted = false
                trackedTouches[touch] = button
                button.isHighlighted = true
            }
            showPopup(for: button)
        }
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            guard let button = trackedTouches.removeValue(forKey: touch) else { continue }
            button.isHighlighted = false
            let target = nearestButton(to: touch.location(in: self), typingOnly: true) ?? button
            target.sendActions(for: .touchUpInside)
        }
        if let remaining = trackedTouches.values.first { showPopup(for: remaining) }
        else { keyPopup.isHidden = true }
    }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            trackedTouches.removeValue(forKey: touch)?.isHighlighted = false
        }
        keyPopup.isHidden = true
    }
    private func clearTouches() {
        trackedTouches.values.forEach { $0.isHighlighted = false }
        trackedTouches.removeAll()
        keyPopup.isHidden = true
    }
    private func showPopup(for button: KeyboardKeyButton) {
        guard let title = button.title(for: .normal), !title.isEmpty, button !== space else { keyPopup.isHidden = true; return }
        let frame = button.convert(button.bounds, to: self)
        let width = max(64, min(110, frame.width + 24))
        keyPopup.text = title
        keyPopup.frame = CGRect(x: max(1, min(bounds.width - width - 1, frame.midX - width / 2)),
                                y: frame.minY - 58, width: width, height: 62)
        keyPopup.isHidden = false
        bringSubviewToFront(keyPopup)
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
        typingButtons.insert(button)
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
        button.acceptsPoint = { [weak self, weak button] point in
            guard let self = self, let button = button else { return false }
            return self.nearestButton(to: button.convert(point, to: self)) === button
        }
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
    var acceptsPoint: ((CGPoint) -> Bool)?
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        acceptsPoint?(point) ?? super.point(inside: point, with: event)
    }
    var keyPosition = "" { didSet { if oldValue != keyPosition { updateAppearance() } } }
    var isUtility = false { didSet { if oldValue != isUtility { updateAppearance() } } }
    override var isHighlighted: Bool { didSet { if oldValue != isHighlighted { updateAppearance() } } }
    override var isEnabled: Bool { didSet { if oldValue != isEnabled { updateAppearance() } } }
    override var isSelected: Bool { didSet { if oldValue != isSelected { updateAppearance() } } }

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


private final class KeyPressPopup: UIView {
    private let label = UILabel()
    var text = "" { didSet { label.text = text; label.font = AppTheme.font(text.count > 2 ? 24 : 32) } }
    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        accessibilityElementsHidden = true
        backgroundColor = .clear
        label.textAlignment = .center
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.5
        label.textColor = AppTheme.ink
        addSubview(label)
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.18
        layer.shadowRadius = 3
        layer.shadowOffset = CGSize(width: 0, height: 2)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func layoutSubviews() {
        super.layoutSubviews()
        label.frame = CGRect(x: 3, y: 2, width: bounds.width - 6, height: 44)
    }
    override func draw(_ rect: CGRect) {
        let body = UIBezierPath(roundedRect: CGRect(x: 0.5, y: 0.5, width: bounds.width - 1, height: 49), cornerRadius: 9)
        body.move(to: CGPoint(x: bounds.midX - 15, y: 49))
        body.addLine(to: CGPoint(x: bounds.midX - 8, y: 61))
        body.addLine(to: CGPoint(x: bounds.midX + 8, y: 61))
        body.addLine(to: CGPoint(x: bounds.midX + 15, y: 49))
        body.close()
        AppTheme.surface.setFill(); body.fill()
        AppTheme.border.setStroke(); body.lineWidth = 1; body.stroke()
    }
}
