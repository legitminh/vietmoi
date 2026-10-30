import Foundation

let suiteName = "com.minh.viet.tests.\(UUID().uuidString)"
let defaults = UserDefaults(suiteName: suiteName)!
defer { defaults.removePersistentDomain(forName: suiteName) }
func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() { fatalError(message) }
}
let store = KeyboardProfiles(defaults: defaults)
let original = store.active
check(store.profiles.count == 1 && original.name == "Default keyboard", "First launch must create the default keyboard")
check(original.inputType == .grid4x8 && original.outputType == .vietmoi, "Default configuration must preserve current typing")
check(original.showVirtualKeyboard, "Existing and new keyboards show the guide by default")
let second = store.add()
store.update(second, input: .telex, output: .vietstandard, showVirtualKeyboard: false)
store.select(second)
store.hasOpenedSetup = true
let restored = KeyboardProfiles(defaults: defaults)
check(restored.profiles.count == 2 && restored.active.id == second, "Profiles and selected keyboard must survive store recreation")
check(restored.active.inputType == .telex && restored.active.outputType == .vietstandard, "Both dropdowns must persist independently")
check(!restored.active.showVirtualKeyboard && restored.profiles[0].showVirtualKeyboard, "Guide visibility must persist separately for each profile")
check(restored.hasOpenedSetup, "First-launch setup state must persist")
restored.remove(second)
check(restored.active.id == original.id, "Removing the selected keyboard must select a remaining keyboard")
restored.remove(original.id)
check(restored.profiles.count == 1, "Cannot remove the last keyboard")
let third = restored.add()
check(third != original.id && third != second, "New profiles must have stable distinct identities")
restored.update(third, input: .asciiPlus)
check(KeyboardProfiles(defaults: defaults).profiles.last?.inputType == .asciiPlus, "ascii+ must be saved without changing its name")
defaults.set(Data("broken config".utf8), forKey: "keyboardProfiles.v1")
check(KeyboardProfiles(defaults: defaults).profiles.count == 1, "Unreadable preferences must recover to a usable default")
let legacy: [String: Any] = [
    "profiles": [["id": original.id.uuidString, "name": "Existing keyboard", "inputType": "ascii+", "outputType": "vietmoi"]],
    "activeID": original.id.uuidString
]
defaults.set(try JSONSerialization.data(withJSONObject: legacy), forKey: "keyboardProfiles.v1")
let migrated = KeyboardProfiles(defaults: defaults)
check(migrated.active.name == "Existing keyboard" && migrated.active.inputType == .asciiPlus && migrated.active.showVirtualKeyboard,
      "Old preferences must preserve the keyboard and default guide visibility to on")
print("Passed 13 profile persistence, migration, and deletion checks.")
