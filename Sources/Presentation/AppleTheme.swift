// Native renderers for the shared Keyflow-inspired design values.
#if canImport(UIKit)
import UIKit

enum AppTheme {
    static func color(_ light: UInt32, _ dark: UInt32) -> UIColor {
        UIColor { traits in
            let value = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: CGFloat((value >> 16) & 255) / 255, green: CGFloat((value >> 8) & 255) / 255,
                           blue: CGFloat(value & 255) / 255, alpha: 1)
        }
    }
    static let background = color(AppDesign.lightBackground, AppDesign.darkBackground)
    static let surface = color(AppDesign.lightSurface, AppDesign.darkSurface)
    static let ink = color(AppDesign.lightInk, AppDesign.darkInk)
    static let muted = color(AppDesign.lightMuted, AppDesign.darkMuted)
    static let border = color(AppDesign.lightBorder, AppDesign.darkBorder)
    static func font(_ size: CGFloat, weight: UIFont.Weight = .regular) -> UIFont {
        .monospacedSystemFont(ofSize: size, weight: weight)
    }
    static func keyColor(_ key: String) -> UIColor {
        return ink
    }
}
#elseif canImport(AppKit)
import AppKit

enum AppTheme {
    static func color(_ light: UInt32, _ dark: UInt32) -> NSColor {
        NSColor(name: nil) { appearance in
            let value = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
            return NSColor(srgbRed: CGFloat((value >> 16) & 255) / 255, green: CGFloat((value >> 8) & 255) / 255,
                           blue: CGFloat(value & 255) / 255, alpha: 1)
        }
    }
    static let background = color(AppDesign.lightBackground, AppDesign.darkBackground)
    static let surface = color(AppDesign.lightSurface, AppDesign.darkSurface)
    static let ink = color(AppDesign.lightInk, AppDesign.darkInk)
    static let muted = color(AppDesign.lightMuted, AppDesign.darkMuted)
    static let border = color(AppDesign.lightBorder, AppDesign.darkBorder)
    static func font(_ size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
        .monospacedSystemFont(ofSize: size, weight: weight)
    }
    static func keyColor(_ key: String) -> NSColor {
        return ink
    }
}

// Layer colors resolve again when the system appearance changes.
class ThemedSurface: NSView {
    var outline = AppTheme.border { didSet { refresh() } }
    var fill = AppTheme.surface { didSet { refresh() } }
    init(frame: NSRect, radius: Double = AppDesign.keyRadius) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.cornerRadius = radius
        layer?.borderWidth = AppDesign.borderWidth
        refresh()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func viewDidChangeEffectiveAppearance() { super.viewDidChangeEffectiveAppearance(); refresh() }
    private func refresh() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            layer?.backgroundColor = fill.cgColor
            layer?.borderColor = outline.cgColor
        }
    }
}
#endif
