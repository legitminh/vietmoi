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
    override func numberOfSections(in tableView: UITableView) -> Int { 3 }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        section == 0 ? MobileKeyboardSettings.inputTypes.count : section == 1 ? OutputType.allCases.count : 2
    }
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        AppCopy.text(["inputLabel", "outputLabel", "language"][section])
    }
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        section == 1 ? AppCopy.text("iosSettingsHelp") : section == 2 ? AppCopy.text("languageHelp") : nil
    }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        let name: String, identifier: String, selected: Bool
        if indexPath.section == 0 {
            let value = MobileKeyboardSettings.inputTypes[indexPath.row]
            name = value.rawValue; selected = settings.input == value
            identifier = "settings.input.\(value.rawValue)"
        } else if indexPath.section == 1 {
            let value = OutputType.allCases[indexPath.row]
            name = value.displayName; selected = settings.output == value
            identifier = "settings.output.\(value.rawValue)"
        } else {
            let language = indexPath.row == 0 ? "vi" : "en"
            name = AppCopy.text(indexPath.row == 0 ? "vietnamese" : "english")
            selected = settings.language == language; identifier = "settings.language.\(language)"
        }
        cell.textLabel?.text = name
        cell.textLabel?.font = AppTheme.font(16)
        cell.textLabel?.textColor = AppTheme.ink
        cell.backgroundColor = AppTheme.surface
        cell.accessibilityIdentifier = identifier
        cell.accessoryType = selected ? .checkmark : .none
        return cell
    }
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        var next = settings
        if indexPath.section == 0 { next.input = MobileKeyboardSettings.inputTypes[indexPath.row] }
        else if indexPath.section == 1 { next.output = OutputType.allCases[indexPath.row] }
        else { next.language = indexPath.row == 0 ? "vi" : "en" }
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
