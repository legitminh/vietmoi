import Foundation

enum Phase: Int, CaseIterable {
    case initial, onglideCoreVowel, final, tone
    var title: String { ["Initial", "Onglide + core vowel", "Final", "Tone"][rawValue] }
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
    let inventory: VietnamesePhoneticInventory
    init(outputType: OutputType = .sieuviet, ascii: Bool = false,
         inventory: VietnamesePhoneticInventory = .sieuviet) {
        self.outputType = outputType
        self.ascii = ascii
        self.inventory = inventory
    }
    static let initials = VietnamesePhoneticInventory.sieuviet.initials
    static let coreVowels = VietnamesePhoneticInventory.sieuviet.coreVowels
    static let finals = VietnamesePhoneticInventory.sieuviet.finals
    private(set) var components: [Int] = []
    private(set) var ascii: Bool
    // Retain the completed basis in memory. Never log users' typing to disk.
    private(set) var lastCommittedBasis: VietnamesePhoneticBasis?
    var phase: Phase { Phase(rawValue: components.count)! }
    var isPending: Bool { !components.isEmpty }
    // While phase == .tone, ngang is a neutral preview, not a chosen tone.
    var phoneticBasis: VietnamesePhoneticBasis? {
        guard components.count >= 2 else { return nil }
        return basis()
    }
    private func basis(tone: VietnameseTone = .ngang) -> VietnamesePhoneticBasis {
        let vowel = inventory.vowelAtoms[components[1]]
        return VietnamesePhoneticBasis(initial: inventory.initials[components[0]],
                                       onglide: vowel.onglide, coreVowel: vowel.coreVowel,
                                       tone: tone,
                                       final: components.count > 2 ? inventory.finals[components[2]] : "")
    }
    var preview: String {
        guard let first = components.first else { return "" }
        if let basis = phoneticBasis {
            return basis.sieuviet(inventory: inventory)
        }
        return inventory.initials[first]
    }
    var tonePreview: String {
        switch phase {
        case .initial: return "Choose an initial"
        case .onglideCoreVowel: return "Choose onglide + core vowel"
        case .tone: return "Choose a tone next"
        case .final: return "Choose a final"
        }
    }
    func action(at gridIndex: Int) -> String? {
        guard GridKey.all.indices.contains(gridIndex) else { return nil }
        if gridIndex == 24 { return ascii ? "Viet mode" : "ASCII" }
        if ascii { return GridKey.all[gridIndex].label }
        if gridIndex == 31 { return "Clear" }
        return GridKey.actionSlots.firstIndex(of: gridIndex).flatMap { componentLabel($0) }
    }
    private func display(_ value: String) -> String { value.isEmpty ? "∅" : value }
    mutating func press(_ gridIndex: Int) -> EngineEffect {
        guard GridKey.all.indices.contains(gridIndex) else { return .none }
        if gridIndex == 24 {
            return toggleASCII()
        }
        guard !ascii else { return .none }
        if gridIndex == 31 { return clearCycle() }
        let slots = GridKey.actionSlots
        guard let index = slots.firstIndex(of: gridIndex) else { return .none }
        return selectComponent(index)
    }
    mutating func toggleASCII() -> EngineEffect {
        let effect = finishPartial()
        ascii.toggle()
        return effect
    }
    func componentLabel(_ index: Int) -> String? {
        guard index >= 0 else { return nil }
        switch phase {
        case .initial: return index < inventory.initials.count ? display(inventory.initials[index]) : nil
        case .onglideCoreVowel: return index < inventory.vowelAtoms.count ? inventory.vowelAtoms[index].label : nil
        case .tone: return VietnameseTone(rawValue: index)?.name
        case .final: return index < inventory.finals.count ? display(inventory.finals[index]) : nil
        }
    }
    mutating func selectComponent(_ index: Int) -> EngineEffect {
        guard !ascii, componentLabel(index) != nil else { return .none }
        if phase == .tone {
            let completed = basis(tone: VietnameseTone(rawValue: index)!)
            let text = (outputType == .quocNgu ? completed.standard() : completed.sieuviet(inventory: inventory)) + " "
            components.removeAll()
            guard CompositionText.isSafe(text) else { return .cancel }
            lastCommittedBasis = completed
            return .commit(text)
        }
        components.append(index)
        guard CompositionText.isSafe(preview) else { components.removeAll(); return .cancel }
        return .marked(preview)
    }
    // End the modal flow without inventing a missing vowel/final/tone. Partial
    // text is a literal abbreviation, so it has no completed phonetic basis.
    mutating func finishPartial(suffix: String = "") -> EngineEffect {
        guard isPending else { return .none }
        let text = preview
        components.removeAll()
        lastCommittedBasis = nil
        guard !text.isEmpty else { return .cancel }
        let committed = (text + suffix).precomposedStringWithCanonicalMapping
        return CompositionText.isSafe(committed) ? .commit(committed) : .cancel
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
    var basis: VietnamesePhoneticBasis? = nil
    func canDelete(selection: NSRange, actualText: String?) -> Bool {
        selection.length == 0 && selection.location != NSNotFound &&
        selection.location == NSMaxRange(range) && actualText == text
    }
}
