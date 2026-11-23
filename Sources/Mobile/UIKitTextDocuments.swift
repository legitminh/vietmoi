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
    func moveCursor(by offset: Int) { proxy.adjustTextPosition(byCharacterOffset: offset) }
}

@MainActor final class EditorTextDocument: MobileTextDocument {
    unowned let editor: UITextView
    let identifier = UUID().uuidString
    init(_ editor: UITextView) { self.editor = editor }
    var beforeInput: String? {
        guard let selection = editor.selectedTextRange,
              let start = editor.position(from: selection.start, offset: -min(512, editor.offset(from: editor.beginningOfDocument, to: selection.start))),
              let range = editor.textRange(from: start, to: selection.start) else { return nil }
        return editor.text(in: range)
    }
    var afterInput: String? {
        guard let selection = editor.selectedTextRange,
              let end = editor.position(from: selection.end, offset: min(128, editor.offset(from: selection.end, to: editor.endOfDocument))),
              let range = editor.textRange(from: selection.end, to: end) else { return nil }
        return editor.text(in: range)
    }
    var selectedText: String? { editor.selectedTextRange.flatMap { editor.text(in: $0) } }
    func setMarkedText(_ text: String) {
        editor.setMarkedText(text, selectedRange: NSRange(location: text.utf16.count, length: 0))
    }
    func unmarkText() { editor.unmarkText() }
    func insertText(_ text: String) { editor.insertText(text) }
    func deleteBackward() { editor.deleteBackward() }
    func moveCursor(by offset: Int) {
        guard offset != 0, let selection = editor.selectedTextRange else { return }
        let origin = offset < 0 ? selection.start : selection.end
        let boundary = offset < 0 ? editor.beginningOfDocument : editor.endOfDocument
        let target = editor.position(from: origin, offset: offset) ?? boundary
        editor.selectedTextRange = editor.textRange(from: target, to: target)
    }
    func moveCursorVertically(by lines: Int) {
        guard lines != 0, let selection = editor.selectedTextRange else { return }
        var target = selection.start
        for _ in 0..<abs(lines) {
            guard let next = editor.position(from: target, in: lines < 0 ? .up : .down, offset: 1) else { break }
            target = next
        }
        editor.selectedTextRange = editor.textRange(from: target, to: target)
        editor.scrollRangeToVisible(editor.selectedRange)
    }
}
