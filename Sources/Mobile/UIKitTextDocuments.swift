import UIKit

@MainActor final class ProxyTextDocument: MobileTextDocument {
    unowned let controller: UIInputViewController
    init(_ controller: UIInputViewController) { self.controller = controller }
    private var proxy: UITextDocumentProxy { controller.textDocumentProxy }
    private var documentUUID: NSUUID? {
        guard let object = proxy as? NSObject else { return nil }
        return object.perform(NSSelectorFromString("documentIdentifier"))?.takeUnretainedValue() as? NSUUID
    }
    var hasActiveDocument: Bool { documentUUID != nil }
    var identifier: String {
        // UIKit can return nil during text-client teardown despite declaring this
        // getter nonnull. Read the public Objective-C getter before UUID bridging.
        let current = proxy as AnyObject
        if let value = documentUUID {
            return value.uuidString
        }
        return "unavailable-\(ObjectIdentifier(current))"
    }
    var beforeInput: String? { proxy.documentContextBeforeInput }
    var afterInput: String? { proxy.documentContextAfterInput }
    var selectedText: String? { proxy.selectedText }
    func setMarkedText(_ text: String) {
        proxy.setMarkedText(text, selectedRange: NSRange(location: text.utf16.count, length: 0))
    }
    func unmarkText() { proxy.unmarkText() }
    func insertText(_ text: String) { proxy.insertText(text) }
    func deleteBackward() { proxy.deleteBackward() }
}

@MainActor final class EditorTextDocument: MobileTextDocument {
    unowned let editor: UITextView
    let identifier = UUID().uuidString
    init(_ editor: UITextView) { self.editor = editor }
    var beforeInput: String? {
        guard let selection = editor.selectedTextRange,
              let range = editor.textRange(from: editor.beginningOfDocument, to: selection.start) else { return nil }
        return editor.text(in: range)
    }
    var afterInput: String? {
        guard let selection = editor.selectedTextRange,
              let range = editor.textRange(from: selection.end, to: editor.endOfDocument) else { return nil }
        return editor.text(in: range)
    }
    var selectedText: String? { editor.selectedTextRange.flatMap { editor.text(in: $0) } }
    func setMarkedText(_ text: String) {
        editor.setMarkedText(text, selectedRange: NSRange(location: text.utf16.count, length: 0))
    }
    func unmarkText() { editor.unmarkText() }
    func insertText(_ text: String) { editor.insertText(text) }
    func deleteBackward() { editor.deleteBackward() }
}
