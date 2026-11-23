import AppKit
import WebKit

// The Mac app window hosts the shared siêu việt UI, opening on the keyboard list.
// Its testing ground types through the same engine as the input method.
final class SettingsWindow: NSWindowController, NSWindowDelegate {
    static let shared = SettingsWindow()
    private let store = KeyboardProfiles.shared
    private var observer: NSObjectProtocol?
    private lazy var app = SharedWebApp(platform: "macos", readState: Self.readState, writeState: Self.writeState)

    private static func readState() -> [String: Any] {
        var state = KeyboardProfiles.shared.sharedState()
        state["interfaceLanguage"] = KeyboardPreferences.shared.language
        state["shiftTapSeconds"] = KeyboardPreferences.shared.shiftTapSeconds
        return state
    }
    private static func writeState(_ state: [String: Any]) {
        let preferences = KeyboardPreferences.shared
        if let seconds = state["shiftTapSeconds"] as? Double { preferences.setShiftTapSeconds(seconds) }
        if let language = state["interfaceLanguage"] as? String, language != preferences.language {
            preferences.language = language
            AppCopy.language = preferences.language
            NotificationCenter.default.post(name: AppCopy.didChange, object: nil)
        }
        KeyboardProfiles.shared.applySharedState(state)
    }

    private init() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 900, height: 720),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = AppDesign.name
        window.backgroundColor = AppTheme.background
        window.minSize = NSSize(width: 420, height: 480)
        window.isReleasedWhenClosed = false
        window.setFrameAutosaveName("SieuvietMainWindow")
        super.init(window: window)
        window.delegate = self
        window.center()
        AppCopy.language = KeyboardPreferences.shared.language
        window.contentView = app.makeWebView(page: "keyboards")
        observer = NotificationCenter.default.addObserver(forName: KeyboardProfiles.didChange, object: store, queue: .main) { [weak self] _ in
            self?.app.push()
        }
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func open() {
        store.hasOpenedSetup = true
        NSApp.setActivationPolicy(.regular)
        KeyboardPanel.shared.hide()
        app.push()
        showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
    @objc func hideSetup() {
        window?.makeFirstResponder(nil)
        window?.orderOut(nil)
        NSApp.setActivationPolicy(.accessory)
        NSApp.hide(nil)
    }
    func windowShouldClose(_ sender: NSWindow) -> Bool { hideSetup(); return false }
}
