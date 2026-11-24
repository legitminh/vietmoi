// Stand-ins for the Apple-only services the shared mobile session uses. The web
// host has no persistent defaults (the page keeps the keyboard list), no UI copy
// in Swift (the page localizes), and no threads (completion work runs when the
// page is idle, through CompletionScheduler below).

final class UserDefaults {
    static let standard = UserDefaults()
    private var values: [String: String] = [:]
    private var flags: [String: Bool] = [:]
    func string(forKey key: String) -> String? { values[key] }
    func bool(forKey key: String) -> Bool { flags[key] ?? false }
    func set(_ value: String, forKey key: String) { values[key] = value }
    func set(_ value: Bool, forKey key: String) { flags[key] = value }
    func removeAll() { values = [:]; flags = [:] }
}

class Operation {
    private(set) var isCancelled = false
    func cancel() { isCancelled = true }
}

typealias CompletionSubmit = (@escaping () -> [String], @escaping ([String]) -> Void) -> Operation?

/// Completion work never runs on the key path. The page drains this queue in idle time.
enum CompletionScheduler {
    private final class Job: Operation {
        let run: () -> Void
        init(_ run: @escaping () -> Void) { self.run = run }
    }
    private static var queue: [Job] = []
    static func submit<Value>(_ work: @escaping () -> Value, receive: @escaping (Value) -> Void) -> Operation? {
        var job: Job!
        job = Job {
            guard !job.isCancelled else { return }
            receive(work())
        }
        queue.append(job)
        return job
    }
    static var hasWork: Bool { queue.contains { !$0.isCancelled } }
    /// Runs the next live job. Returns whether any work remains.
    static func runNext() -> Bool {
        queue.removeAll { $0.isCancelled }
        guard !queue.isEmpty else { return false }
        let job = queue.removeFirst()
        job.run()
        return hasWork
    }
}

enum AppCopy {
    static func text(_ key: String, _ values: [String: String] = [:]) -> String { key }
    static func supportedLanguage(_ language: String?) -> String {
        language == "en" || language == "zh" ? language! : "vi"
    }
}

/// English completion words come from the page's lazily loaded word list.
enum MobileEnglishCompletion {
    static func words(_ prefix: String) -> [String] { EnglishWordList.shared.completions(prefix) }
}
