import AppKit
import Carbon
import Darwin

func inputSource(id: String) -> TISInputSource? {
    let filter = [kTISPropertyInputSourceID as String: id] as CFDictionary
    return (TISCreateInputSourceList(filter, true)?.takeRetainedValue() as? [TISInputSource])?.first
}

func pump(_ app: NSApplication, seconds: TimeInterval) {
    let end = Date(timeIntervalSinceNow: seconds)
    while Date() < end {
        if let event = app.nextEvent(matching: .any, until: Date(timeIntervalSinceNow: 0.01),
                                     inMode: .default, dequeue: true) {
            app.sendEvent(event)
        }
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.005))
    }
}

func sendKey(_ app: NSApplication, type: NSEvent.EventType, code: UInt16,
             characters: String = "", flags: NSEvent.ModifierFlags = []) {
    guard let event = NSEvent.keyEvent(with: type, location: .zero, modifierFlags: flags,
                                      timestamp: ProcessInfo.processInfo.systemUptime,
                                      windowNumber: 0, context: nil, characters: characters,
                                      charactersIgnoringModifiers: characters,
                                      isARepeat: false, keyCode: code) else {
        fatalError("Cannot create keyboard event")
    }
    app.sendEvent(event)
}

let previous = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue()
guard let viet = inputSource(id: "com.minh.inputmethod.VietMoi") else {
    fatalError("Installed VietMoi input source is unavailable")
}
guard TISEnableInputSource(viet) == noErr, TISSelectInputSource(viet) == noErr else {
    fatalError("Cannot select installed VietMoi")
}
defer {
    if let previous = previous { _ = TISSelectInputSource(previous) }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let window = NSWindow(contentRect: NSRect(x: 200, y: 200, width: 520, height: 120),
                      styleMask: [.titled], backing: .buffered, defer: false)
window.title = "VietMoi live integration test"
let textView = NSTextView(frame: NSRect(x: 12, y: 12, width: 496, height: 80))
textView.isRichText = false
textView.font = .systemFont(ofSize: 18)
window.contentView = textView
window.makeKeyAndOrderFront(nil)
window.makeFirstResponder(textView)
app.activate(ignoringOtherApps: true)
textView.inputContext?.selectedKeyboardInputSource = "com.minh.inputmethod.VietMoi"
textView.inputContext?.activate()
pump(app, seconds: 0.8)
print("LIVE_INPUT_SOURCE=\(textView.inputContext?.selectedKeyboardInputSource ?? "nil")")

textView.string = "abc nmq   "
textView.setSelectedRange(NSRange(location: textView.string.utf16.count, length: 0))
pump(app, seconds: 0.2)
print("LIVE_READY")
fflush(stdout)
let deadline = Date(timeIntervalSinceNow: 12)
while Date() < deadline && textView.string == "abc nmq   " { pump(app, seconds: 0.05) }

let result = textView.string
print("LIVE_RESULT=\(result.debugDescription)")
window.orderOut(nil)
guard result == "abc" else { exit(1) }
print("LIVE_SHIFT_DELETE_PASS")
