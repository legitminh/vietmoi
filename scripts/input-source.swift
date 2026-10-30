import Foundation
import Carbon

let action = CommandLine.arguments.dropFirst().first ?? "list"
let identifier = action == "select-us" || action == "prepare-update" ? "com.apple.keylayout.US" : "com.minh.inputmethod.VietMoi"
var currentID: String?
if let current = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
   let value = TISGetInputSourceProperty(current, kTISPropertyInputSourceID) {
    currentID = Unmanaged<CFString>.fromOpaque(value).takeUnretainedValue() as String
    print("Current input source: \(currentID!)")
}
if action == "prepare-update" && currentID != "com.minh.inputmethod.VietMoi" { exit(0) }
if action == "register" {
    guard CommandLine.arguments.count > 2 else { exit(2) }
    let url = URL(fileURLWithPath: CommandLine.arguments[2]) as CFURL
    let status = TISRegisterInputSource(url)
    print("TISRegisterInputSource: \(status)")
    guard status == noErr else { exit(1) }
}
let filter = [kTISPropertyInputSourceID as String: identifier] as CFDictionary
guard let result = TISCreateInputSourceList(filter, true) else {
    fputs("Cannot contact the macOS input-source service from this process. Run outside a restricted sandbox.\n", stderr)
    exit(1)
}
let sources = result.takeRetainedValue() as! [TISInputSource]
for source in sources {
    let name: String = TISGetInputSourceProperty(source, kTISPropertyLocalizedName).map {
        Unmanaged<CFString>.fromOpaque($0).takeUnretainedValue() as String
    } ?? identifier
    print("Found input source: \(name)")
    if action == "enable" || action == "select" || action == "select-us" || action == "prepare-update" {
        let enabled = TISEnableInputSource(source)
        print("TISEnableInputSource: \(enabled)")
        if action == "select" || action == "select-us" || action == "prepare-update" {
            print("TISSelectInputSource: \(TISSelectInputSource(source))")
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.25))
        }
    }
}
if sources.isEmpty { print("Not visible in the TIS list yet. Log out and back in if Settings does not list it.") }
