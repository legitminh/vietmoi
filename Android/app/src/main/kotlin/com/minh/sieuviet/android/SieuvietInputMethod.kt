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
    private var forcedAscii = false
    private var attribute: EditorInfo? = null
    private var settings = KeyboardSettings()
    // The IME's current list position. A Shift tap moves it without writing the
    // app's snapshot; a new selection made in the app is adopted.
    private val local by lazy { getSharedPreferences("ime-keyboard", MODE_PRIVATE) }
    private fun resolve(): KeyboardProfile {
        val appActive = settings.activeId
        if (local.getString("seen", null) != appActive) {
            local.edit().putString("seen", appActive).putString("active", appActive).apply()
            return settings.active
        }
        val id = local.getString("active", null)
        return settings.profiles.firstOrNull { it.id == id } ?: settings.active
    }
    private fun open(profile: KeyboardProfile, start: Int, end: Int) {
        val connection = currentInputConnection ?: return
        val info = attribute ?: return
        session = EditorSession(connection, profile, info, profile.literal || forcedAscii, start, end).also { current ->
            current.onChange = { surface?.render() }
            if (!forcedAscii) current.onNextKeyboard = { switchTo(settings.next(current.profile.id)) }
        }
    }
    /** Replace the session with another keyboard's, keeping the caret. */
    fun switchTo(profile: KeyboardProfile) {
        val old = session ?: return
        local.edit().putString("active", profile.id).apply()
        val start = old.observedStart; val end = old.observedEnd
        old.close(); session = null
        open(profile, start, end)
        surface?.render()
    }
    fun previousKeyboard() { session?.let { it.finish(); switchTo(settings.previous(it.profile.id)) } }
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
        this.attribute = attribute
        settings = SettingsStore(this).load()
        open(resolve(), attribute.initialSelStart, attribute.initialSelEnd)
        surface?.resetPresentation(numeric)
    }
    override fun onStartInputView(info: EditorInfo, restarting: Boolean) { super.onStartInputView(info, restarting); surface?.render() }
    override fun onFinishInputView(finishingInput: Boolean) {
        session?.finish(); surface?.stopRepeating(); super.onFinishInputView(finishingInput)
    }
    override fun onFinishInput() {
        session?.finish(); session?.close(); session = null
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
