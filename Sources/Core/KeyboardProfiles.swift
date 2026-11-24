import Foundation

final class KeyboardProfiles {
    static let shared = KeyboardProfiles()
    static let didChange = Notification.Name("viet.keyboardProfilesChanged")
    private struct State: Codable {
        var profiles: [KeyboardProfile]
        var activeID: UUID
    }
    private let listKey = "keyboardProfiles.languages.v1"
    private let defaults: UserDefaults
    private let storageKey = "keyboardProfiles.v1"
    private var state: State
    var profiles: [KeyboardProfile] { state.profiles }
    var active: KeyboardProfile { state.profiles.first { $0.id == state.activeID } ?? state.profiles[0] }
    var hasOpenedSetup: Bool {
        get { defaults.bool(forKey: "hasOpenedSetup") }
        set { defaults.set(newValue, forKey: "hasOpenedSetup") }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: storageKey),
           let saved = try? JSONDecoder().decode(State.self, from: data), !saved.profiles.isEmpty {
            state = saved
            if !saved.profiles.contains(where: { $0.id == saved.activeID }) { state.activeID = saved.profiles[0].id }
            // Before keyboards had languages, a Shift tap toggled literal ASCII. Keep
            // that reachable once by listing an English keyboard after the old ones.
            if !defaults.bool(forKey: listKey) && !state.profiles.contains(where: { $0.language == .english }) {
                state.profiles.append(.makeEnglish())
            }
        } else {
            let profiles = KeyboardProfile.makeDefaultList()
            state = State(profiles: profiles, activeID: profiles[0].id)
        }
        defaults.set(true, forKey: listKey)
    }
    /// A left Shift tap moves to the next keyboard, wrapping to the first.
    func selectNext() {
        guard let index = state.profiles.firstIndex(where: { $0.id == state.activeID }) else { return }
        select(state.profiles[(index + 1) % state.profiles.count].id)
    }
    func setLanguage(_ language: KeyboardLanguage, for id: UUID) {
        guard let index = state.profiles.firstIndex(where: { $0.id == id }) else { return }
        state.profiles[index].language = language
        state.profiles[index].normalize()
        save()
    }
    /// The keyboard list in the shared settings UI's schema; the host adds its own preferences.
    func sharedState() -> [String: Any] {
        let profiles = (try? JSONSerialization.jsonObject(with: JSONEncoder().encode(state.profiles))) as? [[String: Any]] ?? []
        return ["profiles": profiles.map { $0.filter { $0.key != "asciiPlusKeymap" } }, "activeID": state.activeID.uuidString]
    }
    /// Apply a list written by the shared settings UI. Custom keymaps stay with their keyboards.
    func applySharedState(_ value: [String: Any]) {
        // Fields the shared UI does not edit (custom keymaps, Apple-only options) stay with their keyboards.
        if let list = value["profiles"] as? [[String: Any]] {
            let merged: [[String: Any]] = list.map { incoming in
                guard let id = incoming["id"] as? String, let existing = state.profiles.first(where: { $0.id.uuidString == id }),
                      let data = try? JSONEncoder().encode(existing),
                      var fields = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return incoming }
                fields.merge(incoming) { _, new in new }
                return fields
            }
            if let data = try? JSONSerialization.data(withJSONObject: merged),
               let profiles = try? JSONDecoder().decode([KeyboardProfile].self, from: data), !profiles.isEmpty {
                state.profiles = profiles
            }
        }
        if let text = value["activeID"] as? String, let id = UUID(uuidString: text), state.profiles.contains(where: { $0.id == id }) {
            state.activeID = id
        } else if !state.profiles.contains(where: { $0.id == state.activeID }) { state.activeID = state.profiles[0].id }
        save()
    }
    @discardableResult func add() -> UUID {
        var number = 2
        while state.profiles.contains(where: { $0.name == "Keyboard \(number)" || $0.name == "Bàn phím \(number)" }) { number += 1 }
        let profile = KeyboardProfile(id: UUID(), name: AppCopy.text("keyboardNumber", ["number": String(number)]), inputType: .grid4x8, outputType: .sieuviet)
        state.profiles.append(profile)
        save()
        return profile.id
    }
    func remove(_ id: UUID) {
        guard state.profiles.count > 1 else { return }
        state.profiles.removeAll { $0.id == id }
        if state.activeID == id { state.activeID = state.profiles[0].id }
        save()
    }
    func select(_ id: UUID) {
        guard state.profiles.contains(where: { $0.id == id }) else { return }
        state.activeID = id
        save()
    }
    func update(_ id: UUID, language: KeyboardLanguage? = nil, input: InputType? = nil, output: OutputType? = nil,
                inputMode: InputMode? = nil, showVirtualKeyboard: Bool? = nil, suggestionsEnabled: Bool? = nil) {
        guard let index = state.profiles.firstIndex(where: { $0.id == id }) else { return }
        if let language = language { state.profiles[index].language = language }
        if let input = input { state.profiles[index].inputType = input; state.profiles[index].language = input.language }
        if let inputMode = inputMode { state.profiles[index].inputMode = inputMode }
        if let output = output { state.profiles[index].outputType = output }
        state.profiles[index].normalize()
        if let showVirtualKeyboard = showVirtualKeyboard { state.profiles[index].showVirtualKeyboard = showVirtualKeyboard }
        if let suggestionsEnabled = suggestionsEnabled { state.profiles[index].suggestionsEnabled = suggestionsEnabled }
        save()
    }
    func setASCIIPlusKeymap(_ keymap: ASCIIPlusKeymap?, for id: UUID) {
        guard let index = state.profiles.firstIndex(where: { $0.id == id }) else { return }
        state.profiles[index].asciiPlusKeymap = keymap
        save()
    }
    private func save() {
        if let data = try? JSONEncoder().encode(state) { defaults.set(data, forKey: storageKey) }
        NotificationCenter.default.post(name: Self.didChange, object: self)
    }
}
