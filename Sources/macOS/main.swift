import AppKit
import InputMethodKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    var server: IMKServer?
    private var languageObserver: NSObjectProtocol?
    func applicationDidFinishLaunching(_ notification: Notification) {
        guard let identifier = Bundle.main.bundleIdentifier,
              let connection = Bundle.main.object(forInfoDictionaryKey: "InputMethodConnectionName") as? String,
              NSClassFromString("VietMoiInputController") != nil else {
            NSLog("VietMoi: missing bundle configuration or controller class")
            NSApp.terminate(nil)
            return
        }
        server = IMKServer(name: connection, bundleIdentifier: identifier)
        NSLog("VietMoi: input-method server ready")
        AppCopy.language = KeyboardPreferences.shared.language
        configureMenu()
        languageObserver = NotificationCenter.default.addObserver(forName: AppCopy.didChange, object: nil, queue: .main) { [weak self] _ in self?.configureMenu() }
        if !KeyboardProfiles.shared.hasOpenedSetup || NSRunningApplication.current.isActive {
            SettingsWindow.shared.open()
        }
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        SettingsWindow.shared.open()
        return true
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    @objc private func openSettings() { SettingsWindow.shared.open() }
    private func configureMenu() {
        let main = NSMenu()
        let item = NSMenuItem()
        let menu = NSMenu(title: AppDesign.name)
        let settings = NSMenuItem(title: AppCopy.text("settings") + "…", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)
        let hide = NSMenuItem(title: AppCopy.text("hideApp"), action: #selector(SettingsWindow.hideSetup), keyEquivalent: "h")
        hide.target = SettingsWindow.shared
        menu.addItem(hide)
        menu.addItem(.separator())
        menu.addItem(withTitle: AppCopy.text("quitApp"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.submenu = menu
        main.addItem(item)
        // Standard editing commands for the shared UI's text fields.
        let editItem = NSMenuItem()
        let edit = NSMenu(title: "Edit")
        edit.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        let redo = edit.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        edit.addItem(.separator())
        edit.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = edit
        main.addItem(editItem)
        NSApp.mainMenu = main
    }
}

let application = NSApplication.shared
let appDelegate = AppDelegate()
application.delegate = appDelegate
application.setActivationPolicy(.accessory)
application.run()
