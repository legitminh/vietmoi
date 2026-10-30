import AppKit
import InputMethodKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    var server: IMKServer?
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
        configureMenu()
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
        let menu = NSMenu(title: "viet")
        let settings = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)
        let hide = NSMenuItem(title: "Hide viet", action: #selector(SettingsWindow.hideSetup), keyEquivalent: "h")
        hide.target = SettingsWindow.shared
        menu.addItem(hide)
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit viet", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.submenu = menu
        main.addItem(item)
        NSApp.mainMenu = main
    }
}

let application = NSApplication.shared
let appDelegate = AppDelegate()
application.delegate = appDelegate
application.setActivationPolicy(.accessory)
application.run()
