// All Apple icon sizes use the same star geometry as Android.
import AppKit
import Foundation

let root = URL(fileURLWithPath: CommandLine.arguments[1])
let build = root.appendingPathComponent("build")
let brand = try JSONSerialization.jsonObject(with: Data(contentsOf: root.appendingPathComponent("Design/brand.json"))) as! [String: Any]
let points = brand["star"] as! [[Double]]
let iconset = build.appendingPathComponent("AppIcon.iconset")
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
func draw(_ side: Int, menu: Bool = false) -> NSBitmapImageRep {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: side, pixelsHigh: side, bitsPerSample: 8,
                                  samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                                  bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    if !menu { NSColor.white.setFill(); NSRect(x: 0, y: 0, width: side, height: side).fill() }
    (menu ? NSColor.black : NSColor(srgbRed: 0.2, green: 0.2, blue: 0.2, alpha: 1)).setFill()
    let path = NSBezierPath()
    for (index, point) in points.enumerated() {
        // The menu template uses more of its 16-point canvas for legibility.
        let x = menu ? (point[0] - 0.5) * 1.4 + 0.5 : point[0]
        let y = menu ? (point[1] - 0.5) * 1.4 + 0.5 : point[1]
        let position = NSPoint(x: x * Double(side), y: (1 - y) * Double(side))
        if index == 0 { path.move(to: position) } else { path.line(to: position) }
    }
    path.close(); path.fill()
    NSGraphicsContext.restoreGraphicsState()
    return bitmap
}
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = "icon_\(size)x\(size)\(scale == 2 ? "@2x" : "").png"
        try draw(size * scale).representation(using: .png, properties: [:])!.write(to: iconset.appendingPathComponent(name))
    }
}
let menu = NSImage(size: NSSize(width: 16, height: 16))
for scale in [1, 2] {
    let bitmap = draw(16 * scale, menu: true)
    bitmap.size = menu.size
    menu.addRepresentation(bitmap)
}
try menu.tiffRepresentation!.write(to: build.appendingPathComponent("MenuIcon.tiff"))
if FileManager.default.fileExists(atPath: root.appendingPathComponent("iOS").path) {
    try draw(1024).representation(using: .png, properties: [:])!.write(to: root.appendingPathComponent("iOS/Assets.xcassets/AppIcon.appiconset/AppIcon.png"))
}
print("Generated star icons for macOS and iOS")
