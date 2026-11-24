import AppKit

final class GuidePanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

private final class GuideBackground: NSView {
    override var isOpaque: Bool { false }
    override func draw(_ dirtyRect: NSRect) {
        AppTheme.background.setFill()
        let shape = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: AppDesign.panelRadius, yRadius: AppDesign.panelRadius)
        shape.fill()
        AppTheme.border.setStroke()
        shape.stroke()
    }
}

final class KeyboardPanel: NSObject {
    static let shared = KeyboardPanel()
    private let panel: GuidePanel
    private let asciiKeyboard = ASCIIKeyboardView(frame: NSRect(x: 16, y: 14, width: 480, height: 144))
    private var cards: [(NSView, NSTextField)] = []
    private var suggestionLabels: [NSButton] = []
    private var onChoose: ((Int) -> Void)?
    private let chineseKeyboard = ASCIIKeyboardView(frame: NSRect(x: 16, y: 14, width: 552, height: 144), physicalLabels: true)

    private override init() {
        panel = GuidePanel(contentRect: NSRect(x: 0, y: 0, width: 584, height: 288),
                           styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = .popUpMenu
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        super.init()
        let content = GuideBackground(frame: NSRect(x: 0, y: 0, width: 584, height: 288))
        content.autoresizingMask = [.width, .height]
        panel.contentView = content
        asciiKeyboard.isHidden = true
        content.addSubview(asciiKeyboard)
        chineseKeyboard.isHidden = true
        content.addSubview(chineseKeyboard)
        for index in 0..<32 {
            let row = index / 8, col = index % 8
            let card = ThemedSurface(frame: NSRect(x: 16 + col * 69, y: 183 - row * 57, width: 63, height: 51))
            card.wantsLayer = true
            card.layer?.cornerRadius = AppDesign.keyRadius
            let physical = NSTextField(labelWithString: GridKey.all[index].label)
            physical.frame = NSRect(x: 7, y: 31, width: 50, height: 14)
            physical.font = .monospacedSystemFont(ofSize: 10, weight: .medium)
            physical.textColor = AppTheme.muted
            let action = NSTextField(labelWithString: "")
            action.frame = NSRect(x: 3, y: 7, width: 57, height: 23)
            action.font = AppTheme.font(18, weight: .medium)
            action.alignment = .center
            card.addSubview(physical)
            card.addSubview(action)
            content.addSubview(card)
            cards.append((card, action))
        }
        for index in 0..<9 {
            let label = NSButton(title: "", target: self, action: #selector(chooseSuggestion(_:)))
            label.tag = index
            label.isBordered = false
            label.setButtonType(.momentaryPushIn)
            label.font = AppTheme.font(14, weight: .medium)
            label.alignment = .center
            label.wantsLayer = true
            label.layer?.cornerRadius = AppDesign.keyRadius
            label.layer?.borderWidth = AppDesign.borderWidth
            label.layer?.borderColor = AppTheme.border.cgColor
            label.isHidden = true
            content.addSubview(label)
            suggestionLabels.append(label)
        }

    }

    func show(engine: KeyboardEngine, caret: NSRect?, message: String? = nil,
              inputType: InputType = .grid4x8, asciiActions: [UInt16: String] = [:],
              showKeyboard: Bool = true, suggestions: [String] = [], onChoose: ((Int) -> Void)? = nil) {
        guard (showKeyboard || !suggestions.isEmpty), SettingsWindow.shared.window?.isVisible != true else { hide(); return }
        self.onChoose = onChoose
        chineseKeyboard.isHidden = true
        let useASCII = inputType == .asciiPlus || engine.ascii
        let baseHeight: CGFloat = showKeyboard ? (useASCII ? 168 : 250) : 0
        let suggestionHeight: CGFloat = suggestions.isEmpty ? 0 : 42
        let size = NSSize(width: useASCII ? 512 : 584, height: baseHeight + suggestionHeight)
        panel.setContentSize(size)
        asciiKeyboard.isHidden = !showKeyboard || !useASCII
        asciiKeyboard.update(actions: asciiActions, literal: engine.ascii)
        for (card, _) in cards { card.isHidden = !showKeyboard || useASCII }
        for (index, (card, label)) in cards.enumerated() {
            let action = engine.action(at: index)
            label.stringValue = action == "Clear" ? AppCopy.text("clear") : action ?? "—"
            label.isHidden = false
            if index == 24 { label.stringValue = "⇧"; label.setAccessibilityLabel(AppCopy.text("nextKeyboard")) }
            label.font = AppTheme.font(index == 24 || index == 31 || engine.phase == .tone ? 12 : 18, weight: .medium)
            let color = AppTheme.keyColor(GridKey.all[index].label)
            label.textColor = color
            (card as? ThemedSurface)?.outline = color
            card.alphaValue = action == nil ? 0.35 : 1
        }
        var x: CGFloat = 12
        for (index, label) in suggestionLabels.enumerated() {
            guard suggestions.indices.contains(index) else { label.isHidden = true; continue }
            let value = suggestions[index]
            let width = min(size.width * 0.5, max(58, (value as NSString).size(withAttributes: [.font: label.font!]).width + 34))
            guard x + width <= size.width - 12 else { label.isHidden = true; continue }
            label.isHidden = false
            label.title = "\(index + 1)  \(value)"
            label.setAccessibilityLabel(value)
            label.frame = NSRect(x: x, y: baseHeight + 5, width: width, height: 32)
            x += width + 6
        }
        position(caret: caret)
    }

    private func position(caret: NSRect?) {
        let screen = NSScreen.screens.first { screen in caret.map { screen.frame.intersects($0) } ?? false } ?? NSScreen.main
        if let screen = screen {
            let bounds = screen.visibleFrame.insetBy(dx: 12, dy: 12)
            let size = panel.frame.size
            var origin = NSPoint(x: bounds.midX - size.width / 2, y: bounds.minY + 35)
            if let caret = caret, caret.height > 0, caret.origin.x.isFinite, caret.origin.y.isFinite {
                origin.x = caret.minX
                origin.y = caret.minY - size.height - 10
                if origin.y < bounds.minY { origin.y = caret.maxY + 10 }
            }
            origin.x = max(bounds.minX, min(origin.x, bounds.maxX - size.width))
            origin.y = max(bounds.minY, min(origin.y, bounds.maxY - size.height))
            panel.setFrameOrigin(origin)
        }
        NSApp.unhideWithoutActivation()
        panel.orderFrontRegardless()
    }
    func show(chinese: ShuangpinEngine, caret: NSRect?, showKeyboard: Bool, onChoose: ((Int) -> Void)? = nil) {
        guard (showKeyboard || chinese.isPending), SettingsWindow.shared.window?.isVisible != true else { hide(); return }
        self.onChoose = onChoose
        let rows = (chinese.visibleCandidates.count + 2) / 3
        let base: CGFloat = showKeyboard ? 168 : 0
        panel.setContentSize(NSSize(width: 584, height: base + CGFloat(rows) * 36))
        asciiKeyboard.isHidden = true
        cards.forEach { $0.0.isHidden = true }
        chineseKeyboard.isHidden = !showKeyboard
        let actions = Dictionary(uniqueKeysWithValues: ASCIIKeyboardLayout.keys.compactMap { key -> (UInt16, String)? in
            chinese.keyLabel(key.label).map { (key.keyCode, $0) }
        })
        chineseKeyboard.update(actions: actions, literal: false)
        for (index, button) in suggestionLabels.enumerated() {
            guard chinese.visibleCandidates.indices.contains(index) else { button.isHidden = true; continue }
            let candidate = chinese.visibleCandidates[index]
            button.isHidden = false
            button.title = "\(index + 1)  \(candidate.text)"
            button.setAccessibilityLabel(candidate.text + ", " + candidate.pinyin + (candidate.isCompletion ? ", " + AppCopy.text("suggestions") : ""))
            let x = CGFloat(12 + (index % 3) * 188)
            let y = base + CGFloat(rows - 1 - index / 3) * 36 + 3
            button.frame = NSRect(x: x, y: y, width: 182, height: 30)
            button.layer?.borderColor = (chinese.pageStart + index == chinese.selectedIndex ? AppTheme.ink : AppTheme.border).cgColor
        }
        if !showKeyboard && chinese.visibleCandidates.isEmpty { hide(); return }
        position(caret: caret)
    }

    @objc private func chooseSuggestion(_ sender: NSButton) { onChoose?(sender.tag) }
    func hide() { panel.orderOut(nil); onChoose = nil }
}
