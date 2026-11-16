import AppKit

final class ASCIIKeyboardView: NSView {
    private var cards: [(ASCIIKey, ThemedSurface, NSTextField)] = []
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        let rows = ASCIIKeyboardLayout.guideRows
        let unit = frameRect.width / 10
        for (rowIndex, row) in rows.enumerated() {
            // Align columns: a below q, semicolon below p, and Shift below q.
            var x: CGFloat = 0
            for key in row {
                let card = ThemedSurface(frame: NSRect(x: x + 2, y: frameRect.height - CGFloat(rowIndex + 1) * 48,
                                               width: unit - 4, height: 43))
                card.wantsLayer = true
                card.layer?.cornerRadius = AppDesign.keyRadius
                let action = NSTextField(labelWithString: "")
                action.frame = NSRect(x: 2, y: 10, width: unit - 8, height: 24)
                action.alignment = .center
                action.font = AppTheme.font(16, weight: .medium)
                card.addSubview(action)
                addSubview(card)
                cards.append((key, card, action))
                x += unit
            }
        }
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func update(actions: [UInt16: String], literal: Bool) {
        for (key, card, label) in cards {
            let action = key.keyCode == 56 ? (literal ? "VIỆT" : "ABC") : literal ? key.label : actions[key.keyCode]
            label.stringValue = action ?? ""
            label.setAccessibilityLabel("\(key.label): \(action ?? AppCopy.text("unavailable"))")
            label.font = AppTheme.font((action?.count ?? 0) > 3 ? 10 : 16, weight: .medium)
            let color = AppTheme.keyColor(key.label)
            label.textColor = action == nil ? AppTheme.muted : color
            card.outline = action == nil ? AppTheme.border.withAlphaComponent(0.35) : color
            card.alphaValue = action == nil ? 0.35 : 1
        }
    }
}
