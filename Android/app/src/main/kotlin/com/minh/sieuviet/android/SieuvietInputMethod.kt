package com.minh.sieuviet.android

import android.inputmethodservice.InputMethodService
import android.text.InputType
import android.view.KeyEvent
import android.view.View
import android.view.inputmethod.EditorInfo
import android.view.inputmethod.InputMethodManager

class SieuvietInputMethod : InputMethodService() {
    private var session: EditorSession? = null
    private var surface: KeyboardView? = null
    private var asciiMode = false
    private var forcedAscii = false
    override fun onEvaluateFullscreenMode() = false
    override fun onEvaluateInputViewShown(): Boolean { super.onEvaluateInputViewShown(); return true }

    override fun onCreateInputView(): View = KeyboardView(this, { session }, {
        switchToNextInputMethod(false)
    }, { getSystemService(InputMethodManager::class.java).showInputMethodPicker() }).also { surface = it; it.render() }

    override fun onStartInput(attribute: EditorInfo, restarting: Boolean) {
        super.onStartInput(attribute, restarting)
        session?.finish(); session?.close(); session = null
        val connection = currentInputConnection ?: return
        val variation = attribute.inputType and InputType.TYPE_MASK_VARIATION
        val numeric = attribute.inputType and InputType.TYPE_MASK_CLASS in listOf(InputType.TYPE_CLASS_NUMBER, InputType.TYPE_CLASS_PHONE)
        val password = variation in listOf(InputType.TYPE_TEXT_VARIATION_PASSWORD, InputType.TYPE_TEXT_VARIATION_WEB_PASSWORD, InputType.TYPE_TEXT_VARIATION_VISIBLE_PASSWORD)
        forcedAscii = numeric || password
        session = EditorSession(connection, SettingsStore(this).load(), attribute, asciiMode || forcedAscii).also { current ->
            current.onChange = { if (!forcedAscii) asciiMode = current.state.getBoolean("ascii"); surface?.render() }
        }
        surface?.resetPresentation(numeric)
    }
    override fun onStartInputView(info: EditorInfo, restarting: Boolean) { super.onStartInputView(info, restarting); surface?.render() }
    override fun onFinishInputView(finishingInput: Boolean) {
        session?.finish(); surface?.stopRepeating(); super.onFinishInputView(finishingInput)
    }
    override fun onFinishInput() {
        session?.finish(); session?.let { if (!forcedAscii) asciiMode = it.state.getBoolean("ascii") }; session?.close(); session = null
        super.onFinishInput()
    }
    override fun onUpdateSelection(oldSelStart: Int, oldSelEnd: Int, newSelStart: Int, newSelEnd: Int, candidatesStart: Int, candidatesEnd: Int) {
        super.onUpdateSelection(oldSelStart, oldSelEnd, newSelStart, newSelEnd, candidatesStart, candidatesEnd)
        session?.selectionChanged(newSelStart, newSelEnd, candidatesStart, candidatesEnd)
    }
    override fun onDestroy() { surface?.stopRepeating(); session?.close(); session = null; super.onDestroy() }

    override fun onKeyDown(keyCode: Int, event: KeyEvent): Boolean {
        val current = session ?: return super.onKeyDown(keyCode, event)
        val usage = HardwareKeys.usage(event)
        current.observeKey(usage ?: (0x1000 + keyCode).coerceAtMost(65535), true, event.eventTime / 1000.0,
                           event.isCtrlPressed || event.isAltPressed || event.isMetaPressed || event.isFunctionPressed)
        if (keyCode == KeyEvent.KEYCODE_SHIFT_LEFT || keyCode == KeyEvent.KEYCODE_SHIFT_RIGHT) return super.onKeyDown(keyCode, event)
        if (event.isCtrlPressed || event.isAltPressed || event.isMetaPressed) { current.finish(); return super.onKeyDown(keyCode, event) }
        if (keyCode == KeyEvent.KEYCODE_DEL) { current.backspace(); return true }
        if (keyCode == KeyEvent.KEYCODE_ESCAPE && current.state.getBoolean("pending")) { current.command(NativeEngine.CANCEL); return true }
        if (current.state.getBoolean("ascii")) return super.onKeyDown(keyCode, event)
        if (keyCode == KeyEvent.KEYCODE_SPACE) { current.command(NativeEngine.SPACE); return true }
        if (keyCode == KeyEvent.KEYCODE_ENTER) { current.enter(); return true }
        val position = HardwareKeys.position(usage)
        if (position != null && !event.isShiftPressed) {
            val rows = current.state.getJSONArray("rows")
            for (rowIndex in 0 until rows.length()) {
                val row = rows.getJSONArray(rowIndex)
                for (index in 0 until row.length()) {
                    val key = row.getJSONObject(index)
                    if (key.getString("position") == position) {
                        if (event.repeatCount > 0) return true
                        if (key.getInt("command") == NativeEngine.COMPONENT && !key.getBoolean("enabled")) return true
                        if (current.command(key.getInt("command"), key.getInt("argument"))) return true
                    }
                }
            }
        }
        current.finish()
        return super.onKeyDown(keyCode, event)
    }
    override fun onKeyUp(keyCode: Int, event: KeyEvent): Boolean {
        session?.observeKey(HardwareKeys.usage(event) ?: (0x1000 + keyCode).coerceAtMost(65535), false,
                            event.eventTime / 1000.0, event.isCtrlPressed || event.isAltPressed || event.isMetaPressed || event.isFunctionPressed)
        return super.onKeyUp(keyCode, event)
    }
}
