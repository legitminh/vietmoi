import AppKit

final class GuidePanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

private final class GuideBackground: NSView {
    override var isOpaque: Bool { false }
    override func draw(_ dirtyRect: NSRect) {
        NSColor.windowBackgroundColor.withAlphaComponent(0.76).setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 16, yRadius: 16).fill()
    }
}

final class KeyboardPanel: NSObject {
    static let shared = KeyboardPanel()
    private let panel: GuidePanel
    private let detail = NSTextField(labelWithString: "")
    private let asciiKeyboard = ASCIIKeyboardView(frame: NSRect(x: 16, y: 14, width: 480, height: 144))
    private let settings = NSButton()
    private var cards: [(NSView, NSTextField)] = []
    private var gridModeIcon: NSImageView?

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
        detail.frame = NSRect(x: 54, y: 254, width: 514, height: 20)
        detail.font = .systemFont(ofSize: 12)
        detail.textColor = .secondaryLabelColor
        content.addSubview(detail)
        asciiKeyboard.isHidden = true
        content.addSubview(asciiKeyboard)
        for index in 0..<32 {
            let row = index / 8, col = index % 8
            let card = NSView(frame: NSRect(x: 16 + col * 69, y: 183 - row * 57, width: 63, height: 51))
            card.wantsLayer = true
            card.layer?.cornerRadius = 8
            let physical = NSTextField(labelWithString: GridKey.all[index].label)
            physical.frame = NSRect(x: 7, y: 31, width: 50, height: 14)
            physical.font = .monospacedSystemFont(ofSize: 10, weight: .medium)
            physical.textColor = .secondaryLabelColor
            let action = NSTextField(labelWithString: "")
            action.frame = NSRect(x: 3, y: 7, width: 57, height: 23)
            action.font = .systemFont(ofSize: 18, weight: .medium)
            action.alignment = .center
            card.addSubview(physical)
            card.addSubview(action)
            if index == 24 {
                physical.isHidden = true
                action.isHidden = true
                let image = NSImageView(frame: NSRect(x: 14, y: 9, width: 35, height: 33))
                image.image = ModeSwitchArtwork.image
                image.imageScaling = .scaleProportionallyUpOrDown
                image.setAccessibilityLabel("Tap Left Shift for literal ASCII")
                card.setAccessibilityLabel("Tap Left Shift for literal ASCII")
                card.addSubview(image)
                gridModeIcon = image
            }
            content.addSubview(card)
            cards.append((card, action))
        }
        settings.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: "Keyboard settings")!
        settings.target = self
        settings.action = #selector(openSettings)
        settings.frame = NSRect(x: 12, y: 248, width: 32, height: 28)
        settings.isBordered = false
        settings.toolTip = "Open viet settings"
        settings.setAccessibilityLabel("Open viet settings")
        content.addSubview(settings)
    }

    func show(engine: KeyboardEngine, caret: NSRect?, message: String? = nil,
              inputType: InputType = .grid4x8, asciiActions: [UInt16: String] = [:],
              showKeyboard: Bool = true) {
        guard SettingsWindow.shared.window?.isVisible != true else { return }
        let useASCII = inputType == .asciiPlus || engine.ascii
        let size = showKeyboard ? NSSize(width: useASCII ? 512 : 584, height: useASCII ? 200 : 288) : NSSize(width: 44, height: 44)
        panel.setContentSize(size)
        detail.isHidden = !showKeyboard
        if showKeyboard {
            detail.frame = NSRect(x: 54, y: size.height - 34, width: size.width - 66, height: 20)
        }
        settings.frame = showKeyboard
            ? NSRect(x: 12, y: size.height - 40, width: 32, height: 28)
            : NSRect(x: 6, y: 8, width: 32, height: 28)
        asciiKeyboard.isHidden = !showKeyboard || !useASCII
        asciiKeyboard.update(actions: asciiActions, literal: engine.ascii)
        for (card, _) in cards { card.isHidden = !showKeyboard || useASCII }
        detail.stringValue = message ?? "\(engine.preview.isEmpty ? "∅" : engine.preview)   ·   \(engine.tonePreview)"
        for (index, (card, label)) in cards.enumerated() {
            let action = engine.action(at: index)
            label.stringValue = action ?? "—"
            label.isHidden = index == 24
            label.font = .systemFont(ofSize: index == 24 || index == 31 || engine.phase == .medialTone ? 12 : 18, weight: .medium)
            label.textColor = action == nil ? .tertiaryLabelColor : .labelColor
            let special = index == 24 || (!engine.ascii && index == 31)
            card.layer?.backgroundColor = (special ? NSColor.systemTeal.withAlphaComponent(0.19) : NSColor.labelColor.withAlphaComponent(action == nil ? 0.025 : 0.075)).cgColor
        }
        gridModeIcon?.isHidden = engine.ascii
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
    @objc private func openSettings() { SettingsWindow.shared.open() }
}
