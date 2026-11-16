import UIKit

final class KeyboardViewController: UIInputViewController {
    private var document: ProxyTextDocument?
    private let settingsStore = MobileSettingsStore()
    private var surface: KeyboardSurfaceView?
    private var height: NSLayoutConstraint?
    override func viewDidLoad() {
        super.viewDidLoad()
        primaryLanguage = "vi"
        settingsStore.load()
        let document = ProxyTextDocument(self)
        self.document = document
        let session = MobileInputSession(document: document, settingsProvider: { [settingsStore] in settingsStore.current })
        let surface = KeyboardSurfaceView(session: session)
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
}
