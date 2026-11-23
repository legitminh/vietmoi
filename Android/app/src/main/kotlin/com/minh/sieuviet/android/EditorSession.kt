package com.minh.sieuviet.android

import android.icu.text.BreakIterator
import android.view.inputmethod.EditorInfo
import android.view.inputmethod.InputConnection
import org.json.JSONObject
import kotlin.math.min

/** Android document mechanics only. Construction, key choices and guide labels are Swift. */
class EditorSession(private val connection: InputConnection, val profile: KeyboardProfile,
                    private val info: EditorInfo, ascii: Boolean = false,
                    start: Int = info.initialSelStart, end: Int = info.initialSelEnd) : AutoCloseable {
    private val engine = NativeEngine(profile.output, profile.input)
    /** A Shift tap or the mode key moves to the next keyboard; the owner replaces this session. */
    var onNextKeyboard: (() -> Unit)? = null
    val state: JSONObject get() = engine.state
    var onChange: (() -> Unit)? = null
    private var marked = false
    private var markText = ""
    private var originalSelection: String? = ""
    private var origin = min(start, end)
    private var expected = end
    var observedStart = start; private set
    var observedEnd = end; private set
    private var editing = false
    private var recentCommit: String? = null
    private var closed = false

    init { if (ascii) engine.dispatch(NativeEngine.TOGGLE) }

    fun command(command: Int, argument: Int = 0): Boolean {
        if (closed) return false
        val next = onNextKeyboard
        if (command == NativeEngine.TOGGLE && next != null) { finish(); next(); return true }
        val before = state
        if (!before.getBoolean("pending") && (command == NativeEngine.KEY || command == NativeEngine.COMPONENT)) {
            origin = min(observedStart, observedEnd)
            originalSelection = connection.getSelectedText(0)?.toString() ?: if (observedStart == observedEnd) "" else null
        }
        val effect = engine.dispatch(command, argument)
        if (effect.kind < 0) return false
        editing = true
        connection.beginBatchEdit()
        try {
            when (effect.kind) {
                NativeEngine.MARKED -> {
                    if (effect.text.isNotEmpty() || marked) {
                        val visible = effect.text.ifEmpty { originalSelection ?: "" }
                        if (connection.setComposingText(visible, 1)) {
                            marked = true; markText = visible
                            expected = if (origin >= 0) origin + visible.length else -1
                        } else abandon()
                    }
                }
                NativeEngine.COMMIT -> {
                    if (connection.commitText(effect.text, 1)) {
                        expected = if (marked || before.getBoolean("pending")) origin + effect.text.length
                                   else if (observedStart >= 0) min(observedStart, observedEnd) + effect.text.length else -1
                        recentCommit = effect.text
                    } else recentCommit = null
                    resetMark()
                }
                NativeEngine.CANCELLED -> {
                    // Restore only a composition that still ends at this caret.
                    // Unknown/truncated host context is not permission to delete.
                    if (marked && originalSelection != null && ownedMark()) {
                        connection.setComposingText(originalSelection!!, 1)
                        expected = if (origin >= 0) origin + originalSelection!!.length else -1
                    }
                    connection.finishComposingText()
                    resetMark(); recentCommit = null
                }
                NativeEngine.DELETE_CYCLE -> {
                    val text = recentCommit
                    if (text != null && connection.getSelectedText(0).isNullOrEmpty() &&
                        connection.getTextBeforeCursor(text.length, 0)?.toString() == text) {
                        connection.deleteSurroundingText(text.length, 0)
                        expected = if (expected >= text.length) expected - text.length else -1
                    }
                    recentCommit = null
                }
            }
        } finally { connection.endBatchEdit(); editing = false }
        onChange?.invoke()
        return true
    }

    fun backspace() {
        if (state.getBoolean("pending")) { command(NativeEngine.BACKSPACE); return }
        recentCommit = null
        if (!connection.getSelectedText(0).isNullOrEmpty()) connection.commitText("", 1)
        else {
            val before = connection.getTextBeforeCursor(128, 0)?.toString()
            if (!before.isNullOrEmpty()) {
                val boundaries = BreakIterator.getCharacterInstance()
                boundaries.setText(before)
                val start = boundaries.preceding(before.length).coerceAtLeast(0)
                connection.deleteSurroundingText(before.length - start, 0)
            } else connection.deleteSurroundingTextInCodePoints(1, 0)
        }
        expected = -1
        onChange?.invoke()
    }

    fun observeKey(usage: Int, down: Boolean, timestamp: Double, other: Boolean) {
        if (!closed && engine.observeKey(usage, down, timestamp, other)) command(NativeEngine.TOGGLE)
    }

    fun literal(text: String) {
        finish()
        recentCommit = null
        connection.commitText(text, 1)
        expected = -1
        onChange?.invoke()
    }

    fun finish() {
        if (closed || !state.getBoolean("pending")) return
        val before = if (marked) connection.getTextBeforeCursor(markText.length, 0)?.toString() else null
        if (marked && before != null && before != markText) {
            // A lifecycle flush can race a selection callback. Never replay an
            // old preview when live surrounding text disproves ownership.
            connection.finishComposingText(); abandon(); onChange?.invoke()
        } else command(NativeEngine.FINISH)
    }

    fun enter() {
        finish(); recentCommit = null
        val action = info.imeOptions and EditorInfo.IME_MASK_ACTION
        if (action != EditorInfo.IME_ACTION_NONE && action != EditorInfo.IME_ACTION_UNSPECIFIED &&
            info.imeOptions and EditorInfo.IME_FLAG_NO_ENTER_ACTION == 0) connection.performEditorAction(action)
        else connection.commitText("\n", 1)
    }

    fun selectionChanged(start: Int, end: Int, candidatesStart: Int, candidatesEnd: Int) {
        if (closed || editing) return
        val pending = state.getBoolean("pending")
        val acknowledged = start == end && start == expected
        val delayed = pending && start == origin && end == observedEnd
        val withinMark = pending && marked && candidatesStart == origin && candidatesEnd == origin + markText.length &&
                         start == end && start in candidatesStart..candidatesEnd
        if (!acknowledged && !delayed && !withinMark) {
            if (pending) {
                // End the old native mark without replaying it at a moved caret.
                connection.finishComposingText()
                engine.dispatch(NativeEngine.CANCEL)
                resetMark()
            }
            recentCommit = null
        }
        observedStart = start; observedEnd = end
        onChange?.invoke()
    }

    private fun ownedMark(): Boolean = connection.getSelectedText(0).isNullOrEmpty() &&
        connection.getTextBeforeCursor(markText.length, 0)?.toString() == markText
    private fun resetMark() { marked = false; markText = ""; originalSelection = "" }
    private fun abandon() { engine.dispatch(NativeEngine.CANCEL); resetMark(); recentCommit = null }
    override fun close() { if (!closed) { closed = true; onChange = null; engine.close() } }
}
