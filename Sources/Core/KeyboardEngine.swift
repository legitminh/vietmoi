import Foundation

enum Phase: Int, CaseIterable {
    case initial, medialTone, nucleus, final
    var title: String { ["Initial", "Medial + tone", "Nucleus", "Final"][rawValue] }
}

struct GridKey {
    let label: String
    let keyCode: UInt16
    static let all: [GridKey] = zip(
        ["1","2","3","4","5","6","7","8", "q","w","e","r","t","y","u","i",
         "a","s","d","f","g","h","j","k", "⇧","z","x","c","v","b","n","m"],
        [18,19,20,21,23,22,26,28, 12,13,14,15,17,16,32,34,
         0,1,2,3,5,4,38,40, 56,6,7,8,9,11,45,46] as [UInt16]
    ).map { GridKey(label: $0.0, keyCode: $0.1) }
    static let actionSlots = Array(0..<24) + Array(25..<31)
    static func index(keyCode: UInt16) -> Int? { all.firstIndex { $0.keyCode == keyCode } }
}

enum EngineEffect: Equatable {
    case marked(String), commit(String), cancel, deleteCycle, none
}

struct KeyboardEngine {
    let outputType: OutputType
    init(outputType: OutputType = .vietmoi, ascii: Bool = false) {
        self.outputType = outputType
        self.ascii = ascii
    }
    // Keep the specification's ordering. Extra nuclei are appended so existing mappings stay stable.
    static let initials = ["b","c","ch","d","đ","g","gi","h","k","kh","l","m","n","ng","nh","p","ph","qu","r","s","t","th","tr","v","x",""]
    static let nuclei = ["a","ă","â","e","ê","i","ô","ơ","ư","ưa","ươ","ia","iê","o","u","ua","uô"]
    static let finals = ["","c","ch","i","m","n","ng","nh","o","p","t","u"]
    // Vietmoi tones are spacing suffixes; hỏi must not combine with the final letter.
    static let tones = [" ","´","`","?","~","."]
    static let toneLabels = ["—"] + Array(tones.dropFirst())
    static let toneNames = ["ngang","sắc","huyền","hỏi","ngã","nặng"]
    private(set) var components: [Int] = []
    private(set) var ascii: Bool
    var phase: Phase { Phase(rawValue: components.count)! }
    var isPending: Bool { !components.isEmpty }
    var preview: String {
        guard let first = components.first else { return "" }
        if outputType == .vietstandard, components.count == 3 {
            return standard(final: nil)
        }
        var text = Self.initials[first]
        if components.count > 1 { text += ["","u","o"][components[1] / 6] }
        if components.count > 2 { text += Self.nuclei[components[2]] }
        return text
    }
    var tonePreview: String {
        components.count > 1 ? Self.toneNames[components[1] % 6] : "Choose a tone next"
    }
    func action(at gridIndex: Int) -> String? {
        if gridIndex == 24 { return ascii ? "Viet mode" : "ASCII" }
        if ascii { return GridKey.all[gridIndex].label }
        if gridIndex == 31 { return "Clear" }
        guard let slot = GridKey.actionSlots.firstIndex(of: gridIndex) else { return nil }
        switch phase {
        case .initial: return slot < Self.initials.count ? display(Self.initials[slot]) : nil
        case .medialTone:
            // Three physical rows, one medial per row; six tones occupy the first six columns.
            let row = gridIndex / 8, col = gridIndex % 8
            guard row < 3, col < 6 else { return nil }
            return "\(["∅","u","o"][row]) · \(Self.toneLabels[col])"
        case .nucleus: return slot < Self.nuclei.count ? Self.nuclei[slot] : nil
        case .final: return slot < Self.finals.count ? display(Self.finals[slot]) : nil
        }
    }
    private func display(_ value: String) -> String { value.isEmpty ? "∅" : value }
    private func standard(final: String?) -> String {
        StandardVietnamese.render(initial: Self.initials[components[0]],
                                  medial: ["", "u", "o"][components[1] / 6],
                                  nucleus: Self.nuclei[components[2]],
                                  final: final, tone: components[1] % 6)
    }
    mutating func press(_ gridIndex: Int) -> EngineEffect {
        guard GridKey.all.indices.contains(gridIndex) else { return .none }
        if gridIndex == 24 {
            let pending = isPending
            components.removeAll()
            ascii.toggle()
            return pending ? .cancel : .none
        }
        guard !ascii else { return .none }
        if gridIndex == 31 {
            return clearCycle()
        }
        guard action(at: gridIndex) != nil,
              let slot = GridKey.actionSlots.firstIndex(of: gridIndex) else { return .none }
        return selectComponent(phase == .medialTone ? (gridIndex / 8) * 6 + gridIndex % 8 : slot)
    }
    func componentLabel(_ index: Int) -> String? {
        guard index >= 0 else { return nil }
        switch phase {
        case .initial: return index < Self.initials.count ? display(Self.initials[index]) : nil
        case .medialTone:
            guard index < 18 else { return nil }
            return "\(["∅","u","o"][index / 6])·\(Self.toneLabels[index % 6])"
        case .nucleus: return index < Self.nuclei.count ? Self.nuclei[index] : nil
        case .final: return index < Self.finals.count ? display(Self.finals[index]) : nil
        }
    }
    mutating func selectComponent(_ index: Int) -> EngineEffect {
        guard !ascii, componentLabel(index) != nil else { return .none }
        if phase == .final {
            let text = outputType == .vietstandard
                ? standard(final: Self.finals[index]) + " "
                : preview + Self.finals[index] + Self.tones[components[1] % 6]
            components.removeAll()
            return .commit(text)
        }
        components.append(index)
        return .marked(preview)
    }
    mutating func clearCycle() -> EngineEffect {
        if isPending { components.removeAll(); return .cancel }
        return .deleteCycle
    }
    mutating func backspace() -> EngineEffect {
        guard isPending else { return .none }
        components.removeLast()
        return isPending ? .marked(preview) : .cancel
    }
    mutating func cancel() -> EngineEffect {
        guard isPending else { return .none }
        components.removeAll()
        return .cancel
    }
}

struct CommittedCycle {
    let text: String
    let range: NSRange
    func canDelete(selection: NSRange, actualText: String?) -> Bool {
        selection.length == 0 && selection.location != NSNotFound &&
        selection.location == NSMaxRange(range) && actualText == text
    }
}
