import Foundation

enum InputType: String, Codable, CaseIterable { case grid4x8, asciiPlus = "ascii+", telex }
enum OutputType: String, Codable, CaseIterable { case vietstandard, vietmoi }

struct KeyboardProfile: Codable, Equatable, Identifiable {
    var id: UUID
    var name: String
    var inputType: InputType
    var outputType: OutputType
    var showVirtualKeyboard: Bool
    init(id: UUID, name: String, inputType: InputType, outputType: OutputType, showVirtualKeyboard: Bool = true) {
        self.id = id
        self.name = name
        self.inputType = inputType
        self.outputType = outputType
        self.showVirtualKeyboard = showVirtualKeyboard
    }
    private enum CodingKeys: String, CodingKey {
        case id, name, inputType, outputType, showVirtualKeyboard
    }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        name = try values.decode(String.self, forKey: .name)
        inputType = try values.decode(InputType.self, forKey: .inputType)
        outputType = try values.decode(OutputType.self, forKey: .outputType)
        showVirtualKeyboard = try values.decodeIfPresent(Bool.self, forKey: .showVirtualKeyboard) ?? true
    }
    static func makeDefault() -> KeyboardProfile {
        KeyboardProfile(id: UUID(), name: "Default keyboard", inputType: .grid4x8, outputType: .vietmoi)
    }
}

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
        while state.profiles.contains(where: { $0.name == "Keyboard \(number)" }) { number += 1 }
        let profile = KeyboardProfile(id: UUID(), name: "Keyboard \(number)", inputType: .grid4x8, outputType: .vietmoi)
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
    private func save() {
        if let data = try? JSONEncoder().encode(state) { defaults.set(data, forKey: storageKey) }
        NotificationCenter.default.post(name: Self.didChange, object: self)
    }
}
