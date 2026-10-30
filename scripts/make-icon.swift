import AppKit
let side: CGFloat = 16
let image = NSImage(size: NSSize(width: side, height: side))
image.lockFocus()
let style = NSMutableParagraphStyle()
style.alignment = .center
("★" as NSString).draw(in: NSRect(x: 0, y: -1, width: side, height: side), withAttributes: [
    .font: NSFont.systemFont(ofSize: 13, weight: .regular),
    .foregroundColor: NSColor.black,
    .paragraphStyle: style
])
image.unlockFocus()
try image.tiffRepresentation!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
