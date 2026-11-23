import UIKit

final class DemoViewController: UIViewController, UITextViewDelegate {
    private let settingsStore = MobileSettingsStore()
    private let editor = UITextView()
    private let source = UISegmentedControl(items: [AppCopy.text("tryApp"), AppCopy.text("systemKeyboard")])
    private var compactHeader: [UIView] = []
    private var copyButtons: [(UIButton, String)] = []
    private var session: MobileInputSession!
    private var keyboard: KeyboardSurfaceView!
    override func viewDidLoad() {
        super.viewDidLoad()
        settingsStore.load()
        view.backgroundColor = AppTheme.background
        view.tintColor = AppTheme.ink
        title = AppDesign.name
        let title = UILabel()
        title.text = "★ " + AppDesign.name
        title.font = AppTheme.font(38, weight: .semibold)
        let subtitle = UILabel()
        subtitle.text = AppCopy.text("tagline")
        subtitle.font = AppTheme.font(13)
        subtitle.textColor = AppTheme.muted
        let settings = UIButton(type: .system)
        settings.setTitle(AppCopy.text("enableKeyboard"), for: .normal)
        settings.addAction(UIAction { [weak self] _ in
            let alert = UIAlertController(title: AppCopy.text("useOtherApps"), message: AppCopy.text("iosEnableHelp"), preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: AppCopy.text("openSettings"), style: .default) { _ in
                if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
            })
            alert.addAction(UIAlertAction(title: AppCopy.text("done"), style: .cancel))
            self?.present(alert, animated: true)
        }, for: .touchUpInside)
        let clear = UIButton(type: .system)
        clear.setTitle(AppCopy.text("clear"), for: .normal)
        clear.accessibilityIdentifier = "practice.clear"
        clear.addAction(UIAction { [weak self] _ in
            guard let self = self else { return }
            self.session.cancel()
            self.editor.text = ""
            self.session.documentDidChange()
        }, for: .touchUpInside)
        let preferences = UIButton(type: .system)
        preferences.setTitle(AppCopy.text("settings"), for: .normal)
        preferences.accessibilityIdentifier = "app.settings"
        preferences.addTarget(self, action: #selector(openSettings), for: .touchUpInside)
        copyButtons = [(preferences, "settings"), (settings, "enableKeyboard"), (clear, "clear")]
        let controls = UIStackView(arrangedSubviews: [preferences, UIView(), settings, UIView(), clear])
        controls.axis = .horizontal
        controls.spacing = 10
        source.setTitleTextAttributes([.font: AppTheme.font(12)], for: .normal)
        source.selectedSegmentTintColor = AppTheme.border.withAlphaComponent(0.2)
        for button in [settings, clear, preferences] { button.titleLabel?.font = AppTheme.font(12) }
        source.setTitle(AppCopy.text("tryApp"), forSegmentAt: 0)
        source.setTitle(AppCopy.text("systemKeyboard"), forSegmentAt: 1)
        source.selectedSegmentIndex = 0
        source.accessibilityIdentifier = "practice.source"
        source.addTarget(self, action: #selector(changeSource), for: .valueChanged)
        editor.font = AppTheme.font(25)
        editor.backgroundColor = AppTheme.surface
        editor.textColor = AppTheme.ink
        editor.layer.borderWidth = AppDesign.borderWidth
        editor.layer.borderColor = AppTheme.border.resolvedColor(with: traitCollection).cgColor
        editor.layer.cornerRadius = AppDesign.panelRadius
        editor.textContainerInset = UIEdgeInsets(top: 16, left: 12, bottom: 16, right: 12)
        editor.autocorrectionType = .no
        editor.autocapitalizationType = .none
        editor.smartQuotesType = .no
        editor.smartDashesType = .no
        editor.accessibilityIdentifier = "practice.editor"
        editor.accessibilityLabel = AppCopy.text("tryTyping")
        do { try settingsStore.initializeIfNeeded() }
        catch { /* Settings UI reports a failed save; the practice editor stays usable. */ }
        session = MobileInputSession(document: EditorTextDocument(editor), settingsProvider: { [settingsStore] in settingsStore.current })
        keyboard = KeyboardSurfaceView(session: session)
        editor.inputView = keyboard
        editor.delegate = self
        let content = UIStackView(arrangedSubviews: [title, subtitle, controls, source, editor])
        compactHeader = [title, subtitle]
        content.axis = .vertical
        content.spacing = 12
        content.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(content)
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            content.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 18),
            content.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -18),
            content.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor, constant: -8),
            editor.heightAnchor.constraint(greaterThanOrEqualToConstant: 60)
        ])
        editor.setContentHuggingPriority(.defaultLow, for: .vertical)
        editor.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
    }
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        editor.layer.borderColor = AppTheme.border.resolvedColor(with: traitCollection).cgColor
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        editor.becomeFirstResponder()
    }
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        let compact = view.bounds.height < 500
        compactHeader.forEach { $0.isHidden = compact }
        source.isHidden = compact
    }
    @objc private func openSettings() {
        session.finish()
        editor.resignFirstResponder()
        let settings = KeyboardSettingsViewController(store: settingsStore) { [weak self] in
            guard let self = self else { return }
            self.settingsStore.load()
            self.applyLanguage()
            self.session.reloadSettings()
            self.keyboard.render()
            self.editor.becomeFirstResponder()
        }
        present(UINavigationController(rootViewController: settings), animated: true)
    }
    private func applyLanguage() {
        (compactHeader.last as? UILabel)?.text = AppCopy.text("tagline")
        copyButtons.forEach { $0.0.setTitle(AppCopy.text($0.1), for: .normal) }
        source.setTitle(AppCopy.text("tryApp"), forSegmentAt: 0)
        source.setTitle(AppCopy.text("systemKeyboard"), forSegmentAt: 1)
        editor.accessibilityLabel = AppCopy.text("tryTyping")
    }
    func finishComposition() { session?.finish() }
    @objc private func changeSource() {
        session.finish()
        editor.inputView = source.selectedSegmentIndex == 0 ? keyboard : nil
        editor.reloadInputViews()
        editor.becomeFirstResponder()
    }
    func textViewDidChange(_ textView: UITextView) { session.documentDidChange() }
    func textViewDidChangeSelection(_ textView: UITextView) { session.documentDidChange() }
    override func viewWillDisappear(_ animated: Bool) {
        session.finish()
        super.viewWillDisappear(animated)
    }
}
