import UIKit
import WebKit

// The iOS app hosts the shared siêu việt UI, opening on the keyboard list. The
// keyboard extension reads the saved list each time it opens.
final class SharedAppViewController: UIViewController {
    private let store = MobileSettingsStore()
    private lazy var app = SharedWebApp(platform: "ios", readState: { [store] in Self.state(store.current) },
                                        writeState: { [weak self] in self?.save($0) })

    override func viewDidLoad() {
        super.viewDidLoad()
        try? store.initializeIfNeeded()
        store.load()
        view.backgroundColor = AppTheme.background
        let web = app.makeWebView(page: "keyboards")
        web.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(web)
        NSLayoutConstraint.activate([
            web.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            web.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            web.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            web.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private static func state(_ settings: MobileKeyboardSettings) -> [String: Any] {
        let profiles = (try? JSONSerialization.jsonObject(with: JSONEncoder().encode(settings.profiles))) as? [[String: Any]] ?? []
        return ["profiles": profiles, "activeID": settings.activeID.uuidString,
                "interfaceLanguage": settings.language, "shiftTapSeconds": ShiftTapDetector.defaultTapSeconds]
    }

    private func save(_ state: [String: Any]) {
        var next = store.current
        // Fields the shared UI does not edit stay with their keyboards.
        if let list = state["profiles"] as? [[String: Any]] {
            let merged: [[String: Any]] = list.map { incoming in
                guard let id = incoming["id"] as? String, let existing = next.profiles.first(where: { $0.id.uuidString == id }),
                      let data = try? JSONEncoder().encode(existing),
                      var fields = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return incoming }
                fields.merge(incoming) { _, new in new }
                return fields
            }
            if let data = try? JSONSerialization.data(withJSONObject: merged),
               let profiles = try? JSONDecoder().decode([KeyboardProfile].self, from: data), !profiles.isEmpty {
                next.profiles = profiles
            }
        }
        if let text = state["activeID"] as? String, let id = UUID(uuidString: text) { next.activeID = id }
        if let language = state["interfaceLanguage"] as? String { next.language = language }
        do { try store.save(next.supported) } catch { app.push() }
    }
}
