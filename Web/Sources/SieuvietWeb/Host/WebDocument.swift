/// The page's textbox as a MobileTextDocument. The page sends the text around the
/// caret before each call; edits are mirrored here (so the session reads its own
/// writes, as it does from UIKit) and queued as operations the page applies, in
/// order, to its textarea through Keyflow's composition API.
@MainActor final class WebDocument: MobileTextDocument {
    enum Operation {
        case setMarked(String), unmark, insert(String), deleteBackward, moveCursor(Int)
    }
    private(set) var identifier = "web"
    private var before = "", after = "", selected = ""
    private var markedCount = 0
    private(set) var operations: [Operation] = []

    var beforeInput: String? { before }
    var afterInput: String? { after }
    var selectedText: String? { selected }

    /// A fresh snapshot of the page's textbox. A marked range always ends at the caret.
    func update(before: String, after: String, selected: String, marked: Int, identifier: String) {
        self.before = before; self.after = after; self.selected = selected
        markedCount = marked; self.identifier = identifier
    }
    func takeOperations() -> [Operation] {
        defer { operations.removeAll() }
        return operations
    }

    func setMarkedText(_ text: String) {
        if markedCount > 0 { before.removeLast(min(markedCount, before.count)) } else { selected = "" }
        before += text
        markedCount = text.count
        operations.append(.setMarked(text))
    }
    func unmarkText() {
        markedCount = 0
        operations.append(.unmark)
    }
    func insertText(_ text: String) {
        if markedCount > 0 { before.removeLast(min(markedCount, before.count)); markedCount = 0 }
        selected = ""
        before += text
        operations.append(.insert(text))
    }
    func deleteBackward() {
        markedCount = 0
        if !selected.isEmpty { selected = "" } else if !before.isEmpty { before.removeLast() }
        operations.append(.deleteBackward)
    }
    func moveCursor(by offset: Int) {
        markedCount = 0
        if !selected.isEmpty {
            if offset < 0 { after = selected + after } else { before += selected }
            selected = ""
        }
        if offset < 0 {
            let count = min(-offset, before.count)
            after = String(before.suffix(count)) + after
            before.removeLast(count)
        } else if offset > 0 {
            let count = min(offset, after.count)
            before += after.prefix(count)
            after.removeFirst(count)
        }
        operations.append(.moveCursor(offset))
    }
}
