import Foundation

/// Portable engine boundary. The host owns composition, focus, repeat suppression,
/// selection, and applying effects. Call each instance serially on its owner thread.
/// This is not yet the capability-aware document session described in CROSS_PLATFORM.md.
public final class SieuvietEngine {
    public enum Output: Int32 { case sieuviet = 0, quocNgu = 1 }
    public enum EffectKind: Int32 { case none = 0, marked = 1, commit = 2, cancel = 3, deleteCycle = 4 }
    public struct Effect: Equatable {
        public let kind: EffectKind
        public let text: String
    }
    public enum Command: Int32 {
        /// Argument is a USB HID usage on the Keyboard/Keypad page (0x07).
        case key = 0
        /// Argument is an inventory index in the current phase; also supports grid adapters.
        case component = 1
        case backspace = 2, cancel = 3, finish = 4, toggleASCII = 5, space = 6, clear = 7
    }
    public enum InputError: Error { case invalidArgument, unmappedKey }

    private var engine: KeyboardEngine
    private var shiftTap = ShiftTapDetector()
    private var rightShiftDown = false
    public private(set) var effect = Effect(kind: .none, text: "")
    public var phase: Int32 { Int32(engine.phase.rawValue) }
    public var ascii: Bool { engine.ascii }
    public var preview: String { engine.preview }

    public init(output: Output = .sieuviet) {
        engine = KeyboardEngine(outputType: output == .quocNgu ? .quocNgu : .sieuviet)
    }

    /// Returns a mode-toggle gesture; callers dispatch .toggleASCII through their
    /// normal document path. Modifier transitions themselves remain native events.
    public func observeHardwareKey(usage: UInt16, down: Bool, time: Double, otherModifiers: Bool) -> Bool {
        if otherModifiers { shiftTap.interrupt() }
        if usage == 0xe1 {
            if down {
                shiftTap.press(at: time, threshold: ShiftTapDetector.defaultTapSeconds,
                               isolated: !otherModifiers && !rightShiftDown)
                return false
            }
            return shiftTap.release(at: time)
        }
        if usage == 0xe5 { rightShiftDown = down; shiftTap.interrupt() }
        if down { shiftTap.keyDown(usage) } else { shiftTap.keyUp(usage) }
        return false
    }

    /// Unmapped punctuation/ASCII keys return unmappedKey without changing state.
    /// The host then handles the native boundary/passthrough. Unavailable modal
    /// letters return .none. An error leaves the previous effect unchanged.
    @discardableResult public func dispatch(_ command: Command, argument: Int32 = 0) throws -> Effect {
        guard command == .key || command == .component || argument == 0 else { throw InputError.invalidArgument }
        let result: EngineEffect
        switch command {
        case .key:
            guard let label = Self.positionLabel(argument), !engine.ascii else { throw InputError.unmappedKey }
            if let index = ASCIIPlusMapping.logicalBindings(for: engine.phase)[label] {
                result = engine.selectComponent(index)
            } else if label.count == 1 && ("a"..."z").contains(label) { result = .none }
            else { throw InputError.unmappedKey }
        case .component:
            guard argument >= 0, engine.componentLabel(Int(argument)) != nil else { throw InputError.invalidArgument }
            result = engine.selectComponent(Int(argument))
        case .backspace: result = engine.backspace()
        case .cancel: result = engine.cancel()
        case .finish: result = engine.finishPartial()
        case .toggleASCII: result = engine.toggleASCII()
        case .space:
            if engine.preview.isEmpty {
                _ = engine.cancel()
                result = .commit(" ")
            } else { result = engine.finishPartial(suffix: " ") }
        case .clear: result = engine.clearCycle()
        }
        switch result {
        case .none: effect = Effect(kind: .none, text: "")
        case .marked(let text): effect = Effect(kind: .marked, text: text)
        case .commit(let text): effect = Effect(kind: .commit, text: text)
        case .cancel: effect = Effect(kind: .cancel, text: "")
        case .deleteCycle: effect = Effect(kind: .deleteCycle, text: "")
        }
        return effect
    }

    public func label(forHIDUsage usage: Int32) -> String? {
        guard let label = Self.positionLabel(usage) else { return nil }
        if engine.ascii { return label }
        guard let index = ASCIIPlusMapping.logicalBindings(for: engine.phase)[label] else { return nil }
        return engine.componentLabel(index)
    }

    /// Desktop test/dispatch share the same routing. No host needs a grid or
    /// ASCII+ atom table. Modifiers are observed separately, never consumed here.
    public func wantsKey(usage: Int32, inputType: Int32) -> Bool {
        guard !ascii, inputType == 0 || inputType == 1, let label = Self.positionLabel(usage) else { return false }
        if inputType == 1 { return GridKey.all.contains { $0.label == label } }
        return (0x04...0x1d).contains(usage) || ASCIIPlusMapping.logicalBindings(for: engine.phase)[label] != nil
    }

    @discardableResult public func dispatchKey(usage: Int32, inputType: Int32) throws -> Effect {
        guard inputType == 0 || inputType == 1 else { throw InputError.invalidArgument }
        guard wantsKey(usage: usage, inputType: inputType) else { throw InputError.unmappedKey }
        if inputType == 0 { return try dispatch(.key, argument: usage) }
        guard let label = Self.positionLabel(usage), let index = GridKey.all.firstIndex(where: { $0.label == label }) else { throw InputError.unmappedKey }
        if index == 31 { return try dispatch(.clear) }
        guard let component = GridKey.actionSlots.firstIndex(of: index) else { throw InputError.unmappedKey }
        // An unavailable grid position is still modal, including unused tone keys.
        guard engine.componentLabel(component) != nil else { effect = Effect(kind: .none, text: ""); return effect }
        return try dispatch(.component, argument: Int32(component))
    }

    public func guideText(inputType: Int32) -> String? {
        guard let json = stateJSON(inputType: inputType), let data = json.data(using: .utf8),
              let state = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let rows = state["rows"] as? [[[String: Any]]] else { return nil }
        guard !ascii else { return "Literal ASCII · Left Shift tap: Vietnamese" }
        return rows.map { row in
            row.filter { ($0["enabled"] as? Bool) == true }.map { key in
                "\(key["position"] as? String ?? ""): \(key["title"] as? String ?? "")"
            }.joined(separator: "  ")
        }.joined(separator: "\n")
    }

    /// Native views render this model; atom labels and row geometry stay shared
    /// with the Apple keyboards. inputType: 0 ASCII+, 1 grid4x8.
    public func stateJSON(inputType: Int32) -> String? {
        guard inputType == 0 || inputType == 1 else { return nil }
        let grid = inputType == 1 && !ascii
        let bindings = ASCIIPlusMapping.logicalBindings(for: engine.phase, inventory: engine.inventory)
        let rows: [[ASCIIKey]] = grid ? stride(from: 0, to: GridKey.all.count, by: 8).map { start in
            GridKey.all[start..<start + 8].map { ASCIIKey(label: $0.label, keyCode: $0.keyCode) }
        } : ASCIIKeyboardLayout.guideRows
        let descriptors: [[[String: Any]]] = rows.map { row in
            row.map { key in
                let mode = key.keyCode == 56
                let index = GridKey.index(keyCode: key.keyCode)
                let clear = grid && index == 31
                let id = mode ? "mode" : clear ? "clear" : key.label
                let command: Command = mode ? .toggleASCII : clear ? .clear : grid ? .component : .key
                let argument = mode || clear ? 0 : grid ? GridKey.actionSlots.firstIndex(of: index ?? -1).map(Int32.init) ?? -1 : Self.positionUsage(key.label) ?? -1
                let title: String? = mode ? (ascii ? "VIỆT" : "ABC") : clear ? "Clear" : grid ? index.flatMap { engine.action(at: $0) } : ascii ? key.label : bindings[key.label].flatMap { engine.componentLabel($0) }
                return ["id": id, "position": key.label, "title": title ?? "", "enabled": title != nil,
                        "command": command.rawValue, "argument": argument]
            }
        }
        let state: [String: Any] = ["phase": phase, "ascii": ascii, "pending": engine.isPending,
                                   "preview": preview, "prompt": ascii ? "Literal ASCII" : engine.tonePreview,
                                   "grid": grid, "rows": descriptors,
                                   "symbolPages": TouchKeyboardSymbols.pages.map { $0.map { $0.map(String.init) } }]
        guard let data = try? JSONSerialization.data(withJSONObject: state, options: [.sortedKeys]) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func positionUsage(_ label: String) -> Int32? {
        if label.utf8.count == 1, let code = label.utf8.first, (97...122).contains(code) {
            return Int32(code - 97 + 4)
        }
        return label == ";" ? 0x33 : label == "," ? 0x36 : nil
    }

    private static func positionLabel(_ usage: Int32) -> String? {
        // HID Keyboard A..Z usages are contiguous; these are positions, not OS codes.
        if (0x04...0x1d).contains(usage) {
            return String(UnicodeScalar(UInt32(usage - 0x04 + 0x61))!)
        }
        if (0x1e...0x26).contains(usage) { return String(usage - 0x1e + 1) }
        if usage == 0x27 { return "0" }
        switch usage {
        case 0x33: return ";"
        case 0x36: return ","
        default: return nil
        }
    }
}
