import SieuvietCore
import SieuvietCABI

private func value(_ handle: UnsafeMutableRawPointer?) -> SieuvietEngine? {
    handle.map { Unmanaged<SieuvietEngine>.fromOpaque($0).takeUnretainedValue() }
}

private func copy(_ text: String, to buffer: UnsafeMutablePointer<CChar>?, capacity: UInt64) -> Int64 {
    let bytes = text.utf8CString
    if let buffer = buffer, capacity >= UInt64(bytes.count) {
        bytes.withUnsafeBufferPointer { source in
            buffer.update(from: source.baseAddress!, count: source.count)
        }
    }
    return Int64(bytes.count)
}

@c @implementation public func sv_engine_abi_version() -> UInt32 { 1 }

@c @implementation public func sv_engine_create(_ output: Int32) -> UnsafeMutableRawPointer? {
    guard let output = SieuvietEngine.Output(rawValue: output) else { return nil }
    return Unmanaged.passRetained(SieuvietEngine(output: output)).toOpaque()
}

@c @implementation public func sv_engine_create_with_input(_ output: Int32, _ inputMode: Int32) -> UnsafeMutableRawPointer? {
    guard let output = SieuvietEngine.Output(rawValue: output), let input = SieuvietEngine.Input(rawValue: inputMode) else { return nil }
    return Unmanaged.passRetained(SieuvietEngine(output: output, input: input)).toOpaque()
}

@c @implementation public func sv_adaptive_punctuation(_ tail: UnsafePointer<CChar>?, _ typed: UnsafePointer<CChar>?,
                                                       _ buffer: UnsafeMutablePointer<CChar>?, _ capacity: UInt64) -> Int64 {
    guard let tail = tail, let typed = typed,
          let rewrite = SieuvietEngine.adaptivePunctuation(tail: String(cString: tail), typing: String(cString: typed)) else { return 0 }
    return copy(rewrite, to: buffer, capacity: capacity)
}

@c @implementation public func sv_engine_destroy(_ engine: UnsafeMutableRawPointer?) {
    if let engine = engine { Unmanaged<SieuvietEngine>.fromOpaque(engine).release() }
}

@c @implementation public func sv_engine_dispatch(_ engine: UnsafeMutableRawPointer?, _ command: Int32, _ argument: Int32) -> Int32 {
    guard let engine = value(engine), let command = SieuvietEngine.Command(rawValue: command) else { return -1 }
    if command != .key && command != .component && argument != 0 { return -1 }
    do { return try engine.dispatch(command, argument: argument).kind.rawValue }
    catch SieuvietEngine.InputError.unmappedKey { return -2 }
    catch { return -1 }
}

@c @implementation public func sv_engine_phase(_ engine: UnsafeMutableRawPointer?) -> Int32 {
    value(engine)?.phase ?? -1
}

@c @implementation public func sv_engine_ascii(_ engine: UnsafeMutableRawPointer?) -> Int32 {
    guard let engine = value(engine) else { return -1 }
    return engine.ascii ? 1 : 0
}

@c @implementation public func sv_engine_copy_text(_ engine: UnsafeMutableRawPointer?, _ buffer: UnsafeMutablePointer<CChar>?, _ capacity: UInt64) -> Int64 {
    guard let engine = value(engine) else { return -1 }
    return copy(engine.effect.text, to: buffer, capacity: capacity)
}

@c @implementation public func sv_engine_copy_preview(_ engine: UnsafeMutableRawPointer?, _ buffer: UnsafeMutablePointer<CChar>?, _ capacity: UInt64) -> Int64 {
    guard let engine = value(engine) else { return -1 }
    return copy(engine.preview, to: buffer, capacity: capacity)
}

@c @implementation public func sv_engine_copy_label(_ engine: UnsafeMutableRawPointer?, _ hid_usage: Int32, _ buffer: UnsafeMutablePointer<CChar>?, _ capacity: UInt64) -> Int64 {
    guard let engine = value(engine) else { return -1 }
    guard let label = engine.label(forHIDUsage: hid_usage) else { return -2 }
    return copy(label, to: buffer, capacity: capacity)
}

@c @implementation public func sv_engine_copy_state(_ engine: UnsafeMutableRawPointer?, _ input_type: Int32, _ buffer: UnsafeMutablePointer<CChar>?, _ capacity: UInt64) -> Int64 {
    guard let engine = value(engine), let state = engine.stateJSON(inputType: input_type) else { return -1 }
    return copy(state, to: buffer, capacity: capacity)
}

@c @implementation public func sv_engine_observe_key(_ engine: UnsafeMutableRawPointer?, _ usage: Int32, _ down: Int32, _ timestamp: Double, _ other_modifiers: Int32) -> Int32 {
    guard let engine = value(engine), let usage = UInt16(exactly: usage), (0...1).contains(down),
          (0...1).contains(other_modifiers), timestamp.isFinite else { return -1 }
    return engine.observeHardwareKey(usage: usage, down: down == 1, time: timestamp, otherModifiers: other_modifiers == 1) ? 1 : 0
}

@c @implementation public func sv_engine_wants_key(_ engine: UnsafeMutableRawPointer?, _ input_type: Int32, _ hid_usage: Int32) -> Int32 {
    guard let engine = value(engine), (0...1).contains(input_type), UInt16(exactly: hid_usage) != nil else { return -1 }
    return engine.wantsKey(usage: hid_usage, inputType: input_type) ? 1 : 0
}
@c @implementation public func sv_engine_dispatch_key(_ engine: UnsafeMutableRawPointer?, _ input_type: Int32, _ hid_usage: Int32) -> Int32 {
    guard let engine = value(engine) else { return -1 }
    do { return try engine.dispatchKey(usage: hid_usage, inputType: input_type).kind.rawValue }
    catch SieuvietEngine.InputError.unmappedKey { return -2 }
    catch { return -1 }
}
@c @implementation public func sv_engine_copy_guide(_ engine: UnsafeMutableRawPointer?, _ input_type: Int32, _ buffer: UnsafeMutablePointer<CChar>?, _ capacity: UInt64) -> Int64 {
    guard let engine = value(engine), let guide = engine.guideText(inputType: input_type) else { return -1 }
    return copy(guide, to: buffer, capacity: capacity)
}
