import UIKit

final class KeyboardSettingsViewController: UITableViewController {
    private let store: MobileSettingsStore
    private var settings: MobileKeyboardSettings
    private let onDone: () -> Void
    init(store: MobileSettingsStore, onDone: @escaping () -> Void) {
        self.store = store; settings = store.load(); self.onDone = onDone
        super.init(style: .insetGrouped)
        title = AppCopy.text("keyboardSettings")
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppTheme.background
        tableView.tintColor = AppTheme.ink
        navigationController?.navigationBar.titleTextAttributes = [.font: AppTheme.font(17, weight: .semibold)]
        let done = UIBarButtonItem(title: AppCopy.text("done"), style: .done, target: self, action: #selector(close))
        done.accessibilityIdentifier = "settings.done"
        navigationItem.rightBarButtonItem = done
    }
    override func numberOfSections(in tableView: UITableView) -> Int { 5 }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0: return KeyboardLanguage.allCases.count
        case 1: return settings.keyboardLanguage == .vietnamese ? InputMode.allCases.count : 1
        case 2: return settings.keyboardLanguage.outputs.count
        case 3: return 2
        default: return 1
        }
    }
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        AppCopy.text(["keyboardLanguage", "inputLabel", "outputLabel", "language", "suggestions"][section])
    }
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        section == 3 ? AppCopy.text("languageHelp") : section == 4 ? AppCopy.text("suggestionsHelp." + settings.keyboardLanguage.rawValue) : nil
    }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        let name: String, identifier: String, selected: Bool
        if indexPath.section == 0 {
            let value = KeyboardLanguage.allCases[indexPath.row]
            name = value.displayName; selected = settings.keyboardLanguage == value
            identifier = "settings.keyboardLanguage.\(value.rawValue)"
        } else if indexPath.section == 1 {
            if settings.keyboardLanguage == .vietnamese {
                let value = InputMode.allCases[indexPath.row]
                name = value.displayName; selected = settings.inputMode == value
                identifier = "settings.input.\(value.rawValue)"
            } else {
                name = settings.keyboardLanguage == .english ? "QWERTY" : "Microsoft Shuangpin"
                selected = true; identifier = "settings.input.\(settings.keyboardLanguage.rawValue)"
            }
        } else if indexPath.section == 2 {
            let value = settings.keyboardLanguage.outputs[indexPath.row]
            name = value.displayName
            selected = settings.keyboardLanguage != .vietnamese || settings.output == value
            identifier = "settings.output.\(value.rawValue)"
        } else if indexPath.section == 3 {
            let language = indexPath.row == 0 ? "vi" : "en"
            name = AppCopy.text(indexPath.row == 0 ? "vietnamese" : "english")
            selected = settings.language == language; identifier = "settings.language.\(language)"
        } else {
            name = AppCopy.text("suggestions")
            selected = settings.suggestionsEnabled; identifier = "settings.suggestions"
        }
        cell.textLabel?.text = name
        cell.textLabel?.font = AppTheme.font(16)
        cell.textLabel?.textColor = AppTheme.ink
        cell.backgroundColor = AppTheme.surface
        cell.accessibilityIdentifier = identifier
        cell.accessoryType = selected ? .checkmark : .none
        cell.accessibilityValue = selected ? "1" : "0"
        return cell
    }
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        var next = settings
        if indexPath.section == 0 { next.selectLanguage(KeyboardLanguage.allCases[indexPath.row]) }
        else if indexPath.section == 1 && next.keyboardLanguage == .vietnamese { next.inputMode = InputMode.allCases[indexPath.row] }
        else if indexPath.section == 2 && next.keyboardLanguage == .vietnamese { next.output = next.keyboardLanguage.outputs[indexPath.row] }
        else if indexPath.section == 3 { next.language = indexPath.row == 0 ? "vi" : "en" }
        else if indexPath.section == 4 { next.suggestionsEnabled.toggle() }
        do {
            try store.save(next)
            settings = next
            title = AppCopy.text("keyboardSettings")
            navigationItem.rightBarButtonItem?.title = AppCopy.text("done")
            tableView.reloadData()
        } catch {
            let alert = UIAlertController(title: AppCopy.text("saveError"), message: AppCopy.text("saveErrorHelp"), preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: AppCopy.text("ok"), style: .default))
            present(alert, animated: true)
        }
    }
    @objc private func close() { dismiss(animated: true, completion: onDone) }
}
