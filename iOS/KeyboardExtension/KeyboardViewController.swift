import UIKit

final class KeyboardViewController: UIInputViewController {
    private var document: ProxyTextDocument?
    private let settingsStore = MobileSettingsStore()
    private var surface: KeyboardSurfaceView?
    private var height: NSLayoutConstraint?
    private var reportedLanguage: String?
    override func viewDidLoad() {
        super.viewDidLoad()
        settingsStore.load()
        let document = ProxyTextDocument(self)
        self.document = document
        let session = MobileInputSession(document: document, settingsProvider: { [settingsStore] in settingsStore.current })
        let surface = KeyboardSurfaceView(session: session)
        session.onChange = { [weak self, weak surface, weak session] in
            surface?.render()
            if let session = session { self?.updatePrimaryLanguage(for: session) }
        }
        updatePrimaryLanguage(for: session)
        surface.showGlobe = needsInputModeSwitchKey
        surface.globe.addTarget(self, action: #selector(handleInputModeList(from:with:)), for: .allTouchEvents)
        surface.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(surface)
        NSLayoutConstraint.activate([
            surface.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            surface.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            surface.topAnchor.constraint(equalTo: view.topAnchor),
            surface.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        self.surface = surface
        let constraint = view.heightAnchor.constraint(equalToConstant: surface.preferredHeight)
        constraint.priority = .required
        constraint.isActive = true
        height = constraint
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        settingsStore.load()
        surface?.session.reloadSettings()
        if let session = surface?.session { updatePrimaryLanguage(for: session) }
        view.setNeedsLayout()
    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        surface?.showGlobe = needsInputModeSwitchKey
        let desired = surface?.preferredHeight ?? 192
        if height?.constant != desired { height?.constant = desired }
    }
    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        if document?.hasActiveDocument == true { surface?.session.documentDidChange() }
    }
    override func selectionDidChange(_ textInput: UITextInput?) {
        super.selectionDidChange(textInput)
        if document?.hasActiveDocument == true { surface?.session.documentDidChange() }
    }
    override func viewWillDisappear(_ animated: Bool) {
        surface?.session.finish()
        super.viewWillDisappear(animated)
    }

    // iOS owns the phone's dictation button. primaryLanguage is the supported
    // signal a third-party keyboard can update when its internal mode changes.
    private func updatePrimaryLanguage(for session: MobileInputSession) {
        let language = session.keyboardLanguage == .chinese ? "zh-Hans" : session.ascii ? "en" : "vi"
        // Setting this notifies the host, which may call textDidChange again.
        // A render or prediction update must not start that feedback loop.
        guard reportedLanguage != language else { return }
        reportedLanguage = language
        primaryLanguage = language
    }
}
