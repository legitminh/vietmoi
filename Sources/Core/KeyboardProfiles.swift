import Foundation

final class KeyboardProfiles {
    static let shared = KeyboardProfiles()
    static let didChange = Notification.Name("viet.keyboardProfilesChanged")
    private struct State: Codable {
        var profiles: [KeyboardProfile]
        var activeID: UUID
    }
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
        } else {
            let profile = KeyboardProfile.makeDefault()
            state = State(profiles: [profile], activeID: profile.id)
        }
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
    func update(_ id: UUID, input: InputType? = nil, output: OutputType? = nil, showVirtualKeyboard: Bool? = nil) {
        guard let index = state.profiles.firstIndex(where: { $0.id == id }) else { return }
        if let input = input { state.profiles[index].inputType = input }
        if let output = output { state.profiles[index].outputType = output }
        if let showVirtualKeyboard = showVirtualKeyboard { state.profiles[index].showVirtualKeyboard = showVirtualKeyboard }
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
