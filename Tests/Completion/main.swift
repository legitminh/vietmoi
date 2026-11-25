import Foundation

var checks = 0
func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    checks += 1
    if !condition() { fatalError(message) }
}
let frames = [CGRect(x: 5, y: 5, width: 30, height: 40), CGRect(x: 40, y: 5, width: 30, height: 40), CGRect(x: 5, y: 51, width: 65, height: 40)]
for x in 0...75 {
    for y in 0...96 { expect(KeyboardHitTesting.nearest(to: CGPoint(x: x, y: y), frames: frames) != nil, "Keyboard margins and visual gutters always resolve to a key") }
}
expect(KeyboardHitTesting.nearest(to: CGPoint(x: 37, y: 15), frames: frames) == 0, "A left-side gutter touch selects the nearest key")
expect(KeyboardHitTesting.nearest(to: CGPoint(x: 39, y: 15), frames: frames) == 1, "Sliding across a gutter selects the neighboring key")
expect(KeyboardHitTesting.nearest(to: .zero, frames: []) == nil, "No target when no keys exist")
expect(EnglishCompletion.suffixes(context: "say hel", complete: { _ in ["hello", "help", "hello", "other"] }) == ["lo", "p"], "English completions return distinct matching suffixes")
expect(EnglishCompletion.suffixes(context: "hello ", complete: { _ in ["hello"] }).isEmpty, "Word boundaries clear English completion")
expect(KeyboardCursorMovement.verticalOffset(before: "abc\ndef", after: "ghi\njk", lines: -1) == -4, "Up preserves column")
expect(KeyboardCursorMovement.verticalOffset(before: "abc", after: "\nxy\nz", lines: 1) == 3, "Down clamps to shorter line")
expect(KeyboardCursorMovement.verticalOffset(before: "你好\n世", after: "界\n再见", lines: -1) == -3, "Cursor offsets count Unicode characters")
var received = false
let operation = CompletionScheduler.submit({ Thread.isMainThread }, receive: { ranOnMain in
    expect(!ranOnMain && Thread.isMainThread, "Prediction runs in the background and publishes on the main queue")
    received = true
})
let deadline = Date(timeIntervalSinceNow: 3)
while !received && Date() < deadline { RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.01)) }
expect(received && operation != nil, "Background result is delivered")
var numbers = SuggestionNumberKeys()
expect(numbers.key("2", shown: { 3 }) == .pick(1), "2 picks the second shown suggestion")
expect(numbers.key("5", shown: { 3 }) == .pass, "A digit past the shown suggestions types itself")
expect(numbers.key("-", shown: { 0 }) == .pass, "Minus types itself when nothing is shown")
expect(numbers.key("-", shown: { 3 }) == .escape && numbers.escaping, "Minus escapes while suggestions show")
expect(numbers.key("2", shown: { 3 }) == .pass && !numbers.escaping, "An escaped digit types itself")
_ = numbers.key("-", shown: { 3 })
expect(numbers.key("-", shown: { 3 }) == .pass, "Minus twice types one minus")
_ = numbers.key("-", shown: { 3 })
expect(numbers.key("b", shown: { 3 }) == .minusThenPass, "Minus then a letter keeps the minus")
_ = numbers.key("-", shown: { 3 })
expect(numbers.cancel() && !numbers.cancel(), "Backspace drops a held minus once")
expect(numbers.key("0", shown: { 3 }) == .pass, "0 never picks")
print("Passed \(checks) touch coverage, English completion, number picks, cursor, and background scheduling checks.")
