import Foundation

let suiteName = "com.minh.viet.tests.\(UUID().uuidString)"
let defaults = UserDefaults(suiteName: suiteName)!
defer { defaults.removePersistentDomain(forName: suiteName) }
var checks = 0
func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    checks += 1
    if !condition() { fatalError(message) }
}
let store = KeyboardProfiles(defaults: defaults)
let original = store.active
check(store.profiles.count == 2 && original.name == "Default keyboard", "First launch must create the default keyboard")
check(store.profiles[1].language == .english && store.profiles[1].inputType == .qwerty && store.profiles[1].outputType == .literal,
      "First launch lists an English keyboard after the default, reached by a Shift tap")
store.selectNext()
check(store.active.language == .english, "A Shift tap moves to the next keyboard")
store.selectNext()
check(store.active.id == original.id, "Shift cycling wraps to the first keyboard")
store.remove(store.profiles[1].id)
check(original.inputType == .grid4x8 && original.outputType == .sieuviet, "Default configuration must preserve current typing")
check(original.showVirtualKeyboard, "Existing and new keyboards show the guide by default")
let second = store.add()
store.update(second, input: .asciiPlus, output: .quocNgu, showVirtualKeyboard: false)
store.select(second)
store.hasOpenedSetup = true
let restored = KeyboardProfiles(defaults: defaults)
check(restored.profiles.count == 2 && restored.active.id == second, "Profiles and selected keyboard must survive store recreation")
check(restored.active.inputType == .asciiPlus && restored.active.outputType == .quocNgu, "Both dropdowns must persist independently")
restored.update(second, input: .telex, output: .literal)
check(restored.active.inputType == .asciiPlus && restored.active.outputType == .sieuviet, "Vietnamese keyboards only allow their own inputs and outputs")
restored.setLanguage(.english, for: second)
check(restored.active.inputType == .qwerty && restored.active.outputType == .literal, "Changing language picks that language's defaults")
restored.setLanguage(.vietnamese, for: second)
restored.update(second, output: .quocNgu, showVirtualKeyboard: false)
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
check(KeyboardProfiles(defaults: defaults).profiles.count == 2, "Unreadable preferences must recover to a usable default")
let legacy: [String: Any] = [
    "profiles": [["id": original.id.uuidString, "name": "Existing keyboard", "inputType": "ascii+", "outputType": "vietmoi"]],
    "activeID": original.id.uuidString
]
defaults.set(try JSONSerialization.data(withJSONObject: legacy), forKey: "keyboardProfiles.v1")
defaults.removeObject(forKey: "keyboardProfiles.languages.v1")
let migrated = KeyboardProfiles(defaults: defaults)
check(migrated.profiles.count == 2 && migrated.profiles[1].language == .english, "Old lists gain an English keyboard once, replacing the old ASCII toggle")
migrated.remove(migrated.profiles[1].id)
check(KeyboardProfiles(defaults: defaults).profiles.count == 1, "A removed English keyboard is not added back")
let shared = migrated.sharedState()
check((shared["profiles"] as? [[String: Any]])?.first?["language"] as? String == "vi" && shared["activeID"] as? String == original.id.uuidString,
      "The shared settings UI receives the keyboard list")
check(migrated.active.name == "Existing keyboard" && migrated.active.inputType == .asciiPlus && migrated.active.showVirtualKeyboard,
      "Old preferences must preserve the keyboard and default guide visibility to on")
check(migrated.active.outputType == .sieuviet, "Legacy vietmoi profiles migrate to Sieuviet")
var remap = ASCIIPlusKeymap.sieuviet
remap.initials["m"] = "b"
migrated.setASCIIPlusKeymap(remap, for: original.id)
check(KeyboardProfiles(defaults: defaults).active.asciiPlusKeymap == remap, "Per-profile atom keymaps persist")
let encoded = String(data: defaults.data(forKey: "keyboardProfiles.v1")!, encoding: .utf8)!
check(encoded.contains("sieuviet") && !encoded.contains("vietmoi"), "Saving migrates the stored output name")
migrated.setASCIIPlusKeymap(nil, for: original.id)
check(KeyboardProfiles(defaults: defaults).active.asciiPlusKeymap == nil, "Keymaps can return to defaults")
let legacyKeymap: [String: Any] = [
    "initials": ["m":"b", "d":"d", "y":"nh", "f":"ph"],
    "onglideTones": ["w":["onglide":"", "tone":0]],
    "coreVowels": ["a":"a"], "finals": ["e":"", "z":"ch", "p":"t"]
]
let legacyMapData = try JSONSerialization.data(withJSONObject: legacyKeymap)
let upgradedMap = try JSONDecoder().decode(ASCIIPlusKeymap.self, from: legacyMapData)
check(upgradedMap.initials["m"] == "b", "Legacy initial custom override survives phase migration")
check(upgradedMap.initials["d"] == "đ" && upgradedMap.initials["y"] == "d" && upgradedMap.initials["w"] == "nh", "Legacy defaults adopt the new initial map")
check(upgradedMap.initials["f"] == "f" && upgradedMap.finals["j"] == "ch" && upgradedMap.finals["p"] == "t", "Updated defaults and actual final overrides migrate independently")
check(upgradedMap.vowels.count == 24 && upgradedMap.tones == ASCIIPlusKeymap.sieuviet.tones, "Incompatible old second/third-round mappings reset to the new typed rounds")
let schema = try JSONSerialization.jsonObject(with: JSONEncoder().encode(upgradedMap)) as! [String: Any]
check(schema["version"] as? Int == 6, "Migrated keymaps serialize with the new schema version")
let previousVowels = [
    "t":"ă", "g":"a", "b":"â", "y":"iê", "h":"e", "n":"ê", "u":"ơ", "j":"o", "m":"ô", "i":"ư", "k":"u", "o":"i", "p":"ươ", "l":"uô", ";":"oo",
    "q":"wă", "a":"wa", "z":"wâ", "w":"wiê", "s":"we", "x":"wê", "e":"wơ", "d":"wo", "c":"wô", "r":"wư", "f":"wu", "v":"wi"]
let previousTypedVowels = previousVowels.mapValues { atom in
    VietnameseVowelAtom(onglide: atom.hasPrefix("w") ? "w" : "", coreVowel: atom.hasPrefix("w") ? String(atom.dropFirst()) : atom)
}
let oldVowels: [String: String] = [
    "t":"a", "g":"ă", "b":"â", "y":"e", "h":"ê", "n":"i", "u":"o", "j":"ơ", "m":"ô", "i":"u", "k":"ư", "o":"iê", "l":"ươ", "p":"uô", ",":"oo",
    "q":"wa", "a":"wă", "z":"wâ", "w":"we", "s":"wê", "x":"wi", "e":"wo", "d":"wơ", "c":"wô", "r":"wu", "f":"wư", "v":"wiê"]
var oldTypedVowels = oldVowels.mapValues { atom in
    VietnameseVowelAtom(onglide: atom.hasPrefix("w") ? "w" : "", coreVowel: atom.hasPrefix("w") ? String(atom.dropFirst()) : atom)
}
var version2 = try JSONSerialization.jsonObject(with: JSONEncoder().encode(ASCIIPlusKeymap.sieuviet)) as! [String: Any]
version2["version"] = 2
var historicalFinals = ASCIIPlusKeymap.sieuviet.finals
historicalFinals.removeValue(forKey: "o")
historicalFinals["u"] = "u"
version2["finals"] = historicalFinals
version2["vowels"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(oldTypedVowels))
let defaultsUpdated = try JSONDecoder().decode(ASCIIPlusKeymap.self, from: JSONSerialization.data(withJSONObject: version2))
check(defaultsUpdated == ASCIIPlusKeymap.sieuviet, "Version-2 defaults adopt every new vowel key position")
oldTypedVowels["g"] = VietnameseVowelAtom(onglide: "", coreVowel: "ô")
oldTypedVowels.removeValue(forKey: ",")
version2["vowels"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(oldTypedVowels))
var customizedInitials = ASCIIPlusKeymap.sieuviet.initials
customizedInitials["m"] = "b"
version2["initials"] = customizedInitials
let overridesUpdated = try JSONDecoder().decode(ASCIIPlusKeymap.self, from: JSONSerialization.data(withJSONObject: version2))
check(overridesUpdated.vowels["g"]?.coreVowel == "ô", "Actual custom vowel override survives a default-layout update")
check(overridesUpdated.vowels[","] == nil && overridesUpdated.vowels[";"] == nil && overridesUpdated.vowels["w"]?.label == "ă", "Removed custom keys stay removed while untouched defaults update")
check(overridesUpdated.initials["m"] == "b" && overridesUpdated.tones == ASCIIPlusKeymap.sieuviet.tones && overridesUpdated.finals == ASCIIPlusKeymap.sieuviet.finals, "Unchanged rounds retain their saved settings during migration")
var version3 = try JSONSerialization.jsonObject(with: JSONEncoder().encode(ASCIIPlusKeymap.sieuviet)) as! [String: Any]
version3["version"] = 3
var commaVowels = previousTypedVowels
commaVowels[","] = commaVowels.removeValue(forKey: ";")
version3["vowels"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(commaVowels))
let semicolonUpdated = try JSONDecoder().decode(ASCIIPlusKeymap.self, from: JSONSerialization.data(withJSONObject: version3))
check(semicolonUpdated == ASCIIPlusKeymap.sieuviet, "Saved comma-oo defaults migrate through semicolon to the new a position")
var version4 = try JSONSerialization.jsonObject(with: JSONEncoder().encode(ASCIIPlusKeymap.sieuviet)) as! [String: Any]
version4["version"] = 4
version4["vowels"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(previousTypedVowels))
version4["finals"] = historicalFinals
func migrateFinals(_ finals: [String: String]) throws -> ASCIIPlusKeymap {
    version4["finals"] = finals
    return try JSONDecoder().decode(ASCIIPlusKeymap.self, from: JSONSerialization.data(withJSONObject: version4))
}
let defaultFinalsUpdated = try migrateFinals(historicalFinals)
check(defaultFinalsUpdated == ASCIIPlusKeymap.sieuviet, "Version-4 default final u moves to o")
var customFinals = historicalFinals
customFinals["u"] = "n"; customFinals["b"] = "u"
let renamedCustomFinals = try migrateFinals(customFinals)
check(renamedCustomFinals.finals["u"] == "n" && renamedCustomFinals.finals["b"] == "o", "Custom positions survive the final atom rename")
customFinals = historicalFinals; customFinals["o"] = "p"
let occupiedO = try migrateFinals(customFinals)
check(occupiedO.finals["o"] == "p" && occupiedO.finals["u"] == "o", "Existing custom o binding is not overwritten")
customFinals.removeValue(forKey: "u")
let removedFinal = try migrateFinals(customFinals)
check(removedFinal.finals["u"] == nil && removedFinal.finals["o"] == "p", "Removed default stays removed")
let roundTrippedFinals = try JSONDecoder().decode(ASCIIPlusKeymap.self, from: JSONEncoder().encode(renamedCustomFinals))
check(roundTrippedFinals == renamedCustomFinals, "Version-6 custom maps round trip unchanged")
var version5 = try JSONSerialization.jsonObject(with: JSONEncoder().encode(ASCIIPlusKeymap.sieuviet)) as! [String: Any]
version5["version"] = 5
version5["vowels"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(previousTypedVowels))
let defaultV5Updated = try JSONDecoder().decode(ASCIIPlusKeymap.self, from: JSONSerialization.data(withJSONObject: version5))
check(defaultV5Updated == ASCIIPlusKeymap.sieuviet, "Version-5 defaults adopt all 24 new vowel choices")
var customV5Vowels = previousTypedVowels
customV5Vowels["g"] = VietnameseVowelAtom(onglide: "", coreVowel: "ô")
customV5Vowels.removeValue(forKey: "w")
customV5Vowels["p"] = VietnameseVowelAtom(onglide: "w", coreVowel: "a")
customV5Vowels["q"] = VietnameseVowelAtom(onglide: "w", coreVowel: "u")
version5["vowels"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(customV5Vowels))
let customV5Updated = try JSONDecoder().decode(ASCIIPlusKeymap.self, from: JSONSerialization.data(withJSONObject: version5))
check(customV5Updated.vowels["g"]?.label == "ô" && customV5Updated.vowels["w"] == nil, "Custom atoms and physical-key removals survive version 6")
check(customV5Updated.vowels["p"]?.label == "wa", "An override on a newly unused position remains available")
check(customV5Updated.vowels["m"]?.label == "wi" && customV5Updated.vowels["n"]?.label == "wê", "Untouched defaults resolve the user's m/n assignment")
check(customV5Updated.vowels["q"]?.label == "wu" && ASCIIPlusMapping.bindings(for: .onglideCoreVowel, keymap: customV5Updated)[ASCIIKeyboardLayout.keyCodesByLabel["q"]!] == nil,
      "A removed custom combination is retained as data but cannot select a different vowel")
let roundTrippedV6 = try JSONDecoder().decode(ASCIIPlusKeymap.self, from: JSONEncoder().encode(customV5Updated))
check(roundTrippedV6 == customV5Updated, "Version-6 custom bindings do not migrate twice")
let oldOutputData = Data("\"vietstandard\"".utf8)
let migratedOutput = try JSONDecoder().decode(OutputType.self, from: oldOutputData)
check(migratedOutput == .quocNgu && migratedOutput.rawValue == "quốc ngữ", "Legacy standard output migrates to the renamed mode")
let encodedOutput = try JSONEncoder().encode(migratedOutput)
let outputName = try JSONSerialization.jsonObject(with: encodedOutput, options: .fragmentsAllowed) as? String
check(outputName == "quốc ngữ", "The renamed output serializes as quốc ngữ")
print("Passed \(checks) profile persistence, migration, and deletion checks.")
