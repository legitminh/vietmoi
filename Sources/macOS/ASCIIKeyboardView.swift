import AppKit

enum ModeSwitchArtwork {
    static let image: NSImage? = {
        guard let url = Bundle.main.url(forResource: "UnitedStatesMode", withExtension: "svg") else { return nil }
        return NSImage(contentsOf: url)
    }()
}

final class ASCIIKeyboardView: NSView {
    private var cards: [(ASCIIKey, NSView, NSTextField, NSImageView?)] = []
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        var rows = ASCIIKeyboardLayout.rows.map { row in
            row.filter { $0.label.count == 1 && ("a"..."z").contains($0.label) }
        }.filter { !$0.isEmpty }
        // The mode switch belongs to the input block, immediately before z on
        // the same bottom row, rather than in a separate annotation row.
        rows[2].insert(ASCIIKey(label: "Shift", keyCode: 56), at: 0)
        let unit = frameRect.width / 10
        for (rowIndex, row) in rows.enumerated() {
            var x = (frameRect.width - CGFloat(row.count) * unit) / 2
            for key in row {
                let card = NSView(frame: NSRect(x: x + 2, y: frameRect.height - CGFloat(rowIndex + 1) * 48,
                                               width: unit - 4, height: 43))
                card.wantsLayer = true
                card.layer?.cornerRadius = 6
                let action = NSTextField(labelWithString: "")
                action.frame = NSRect(x: 2, y: 10, width: unit - 8, height: 24)
                action.alignment = .center
                action.font = .systemFont(ofSize: 16, weight: .medium)
                card.addSubview(action)
                var artwork: NSImageView?
                if key.keyCode == 56 {
                    action.isHidden = true
                    let image = NSImageView(frame: NSRect(x: 9, y: 7, width: unit - 22, height: 29))
                    image.image = ModeSwitchArtwork.image
                    image.imageScaling = .scaleProportionallyUpOrDown
                    image.setAccessibilityLabel("Tap Left Shift for literal ASCII")
                    card.addSubview(image)
                    artwork = image
                }
                addSubview(card)
                cards.append((key, card, action, artwork))
                x += unit
            }
        }
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func update(actions: [UInt16: String], literal: Bool) {
        for (key, card, label, artwork) in cards {
            if key.keyCode == 56 {
                artwork?.isHidden = literal
                card.setAccessibilityLabel("Tap Left Shift for literal ASCII")
                card.layer?.backgroundColor = NSColor.systemTeal.withAlphaComponent(0.19).cgColor
                continue
            }
            let action = literal ? key.label : actions[key.keyCode]
            label.stringValue = action ?? ""
            label.setAccessibilityLabel("\(key.label): \(action ?? "unused")")
            label.font = .systemFont(ofSize: (action?.count ?? 0) > 3 ? 10 : 16, weight: .medium)
            label.textColor = action == nil ? .tertiaryLabelColor : .labelColor
            card.layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(action == nil ? 0.025 : 0.075).cgColor
        }
    }
}
