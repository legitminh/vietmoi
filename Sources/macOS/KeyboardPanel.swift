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

    }

    func show(engine: KeyboardEngine, caret: NSRect?, message: String? = nil,
              inputType: InputType = .grid4x8, asciiActions: [UInt16: String] = [:],
              showKeyboard: Bool = true) {
        guard showKeyboard, SettingsWindow.shared.window?.isVisible != true else { hide(); return }
        let useASCII = inputType == .asciiPlus || engine.ascii
        let size = NSSize(width: useASCII ? 512 : 584, height: useASCII ? 168 : 250)
        panel.setContentSize(size)
        asciiKeyboard.isHidden = !showKeyboard || !useASCII
        asciiKeyboard.update(actions: asciiActions, literal: engine.ascii)
        for (card, _) in cards { card.isHidden = !showKeyboard || useASCII }
        for (index, (card, label)) in cards.enumerated() {
            let action = engine.action(at: index)
            label.stringValue = action == "Clear" ? AppCopy.text("clear") : action ?? "—"
            label.isHidden = false
            if index == 24 { label.stringValue = engine.ascii ? "VIỆT" : "ABC" }
            label.font = AppTheme.font(index == 24 || index == 31 || engine.phase == .tone ? 12 : 18, weight: .medium)
            let color = AppTheme.keyColor(GridKey.all[index].label)
            label.textColor = color
            (card as? ThemedSurface)?.outline = color
            card.alphaValue = action == nil ? 0.35 : 1
        }
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
    func hide() { panel.orderOut(nil) }
}
