package com.minh.sieuviet.android

import android.content.Context
import android.content.res.Configuration
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.graphics.drawable.StateListDrawable
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowInsets
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import org.json.JSONObject

/** A native Android surface. Every modal key/label/row comes from the Swift model. */
class KeyboardView(context: Context, private val session: () -> EditorSession?,
                   private val nextKeyboard: () -> Unit, private val picker: () -> Unit) : LinearLayout(context) {
    private val theme = AppTheme(context)
    private val ink = theme.ink
    private val rowsView = LinearLayout(context).apply { orientation = VERTICAL }
    private val footer = LinearLayout(context)
    private val modalButtons = mutableMapOf<String, Button>()
    private val handler = Handler(Looper.getMainLooper())
    private var signature = ""
    private var symbols = false
    private var symbolPage = 0
    private var uppercase = false
    private val compact get() = resources.configuration.orientation == Configuration.ORIENTATION_LANDSCAPE
    private val keyHeight get() = dp(if (compact) 42 else 48)
    private fun dp(value: Int) = (resources.displayMetrics.density * value).toInt()

    init {
        orientation = VERTICAL
        setBackgroundColor(theme.background)
        setPadding(dp(3), dp(3), dp(3), dp(4))
        isFocusable = false
        addView(rowsView); addView(footer)
        setOnApplyWindowInsetsListener { _, insets ->
            @Suppress("DEPRECATION")
            val bottom = if (android.os.Build.VERSION.SDK_INT >= 30) insets.getInsets(WindowInsets.Type.navigationBars()).bottom
                         else insets.systemWindowInsetBottom
            setPadding(dp(3), dp(3), dp(3), dp(4) + bottom)
            insets
        }
    }

    fun resetPresentation(numeric: Boolean = false) { symbols = numeric; symbolPage = 0; uppercase = false; signature = ""; render() }

    fun render() {
        val current = session() ?: return
        val state = current.state
        val ascii = state.getBoolean("ascii")
        val grid = state.getBoolean("grid") && !symbols
        val rows = state.getJSONArray("rows")
        val nextSignature = "${AppCopy.language}:$grid:$symbols:$symbolPage:$compact:" + (0 until rows.length()).joinToString("|") { row ->
            val values = rows.getJSONArray(row)
            (0 until values.length()).joinToString(",") { values.getJSONObject(it).getString("id") }
        }
        if (nextSignature != signature) {
            stopRepeating(); rowsView.removeAllViews(); footer.removeAllViews(); modalButtons.clear()
            signature = nextSignature
            if (symbols) {
                val values = state.getJSONArray("symbolPages").getJSONArray(symbolPage)
                for (rowIndex in 0 until values.length()) {
                    val row = LinearLayout(context)
                    val entries = values.getJSONArray(rowIndex)
                    for (index in 0 until entries.length()) {
                        val text = entries.getString(index)
                        row.addView(button(text, AppCopy.text("symbol", "symbol" to text)) { session()?.literal(text) }, keyParams())
                    }
                    if (rowIndex == values.length() - 1) addEditing(row)
                    rowsView.addView(row)
                }
            } else {
                for (rowIndex in 0 until rows.length()) {
                    val row = LinearLayout(context)
                    val entries = rows.getJSONArray(rowIndex)
                    for (index in 0 until entries.length()) {
                        val key = entries.getJSONObject(index)
                        val id = key.getString("id")
                        val keyButton = button("", "") {
                            val live = session() ?: return@button
                            if (live.state.getBoolean("ascii") && key.getInt("command") == NativeEngine.KEY) {
                                val text = key.getString("position")
                                live.literal(if (uppercase) text.uppercase() else text)
                            } else if (!live.command(key.getInt("command"), key.getInt("argument")) && key.getString("position") == ";") {
                                live.literal(";")
                            }
                        }
                        val resourceName = "key_" + if (id == ";") "semicolon" else id
                        keyButton.id = resources.getIdentifier(resourceName, "id", context.packageName)
                        modalButtons[id] = keyButton
                        row.addView(keyButton, keyParams())
                    }
                    if (!grid && rowIndex == rows.length() - 1) addEditing(row)
                    rowsView.addView(row)
                }
            }
            footer.addView(button(if (symbols) "ABC" else "123", AppCopy.text("numbersSymbols"), R.id.keyboard_numbers) {
                session()?.finish(); symbols = !symbols; render()
            }, keyParams())
            val globe = button("◎", AppCopy.text("nextKeyboard"), R.id.keyboard_globe) { session()?.finish(); nextKeyboard() }
            globe.setOnLongClickListener { session()?.finish(); picker(); true }
            footer.addView(globe, keyParams())
            footer.addView(button(if (symbols) "#+=" else "⇧", if (symbols) AppCopy.text("moreSymbols") else AppCopy.text("uppercaseAscii"), R.id.keyboard_caps) {
                if (symbols) { symbolPage = 1 - symbolPage; signature = "" } else uppercase = !uppercase
                render()
            }, keyParams())
            footer.addView(button(AppCopy.text("space"), AppCopy.text("space"), R.id.keyboard_space) { session()?.command(NativeEngine.SPACE) }, keyParams(if (grid) 3f else 4f))
            if (grid) addEditing(footer)
            else {
                footer.addView(button(",", AppCopy.text("comma")) { session()?.literal(",") }, keyParams())
                footer.addView(button(".", AppCopy.text("period")) { session()?.literal(".") }, keyParams())
            }
        }
        if (!symbols) {
            for (rowIndex in 0 until rows.length()) {
                val entries = rows.getJSONArray(rowIndex)
                for (index in 0 until entries.length()) {
                    val key = entries.getJSONObject(index)
                    val view = modalButtons[key.getString("id")] ?: continue
                    val title = key.getString("title")
                    view.text = if (title == "Clear") AppCopy.text("clear") else if (ascii && uppercase && key.getInt("command") == NativeEngine.KEY) title.uppercase() else title
                    view.textSize = if (title.length > 3) 12f else if (key.getString("id") == "mode") 13f else 20f
                    val color = theme.keyColor(key.getString("position"))
                    view.background = theme.keyBackground(color)
                    view.setTextColor(android.content.res.ColorStateList(arrayOf(intArrayOf(android.R.attr.state_pressed), intArrayOf()), intArrayOf(theme.background, color)))
                    view.isEnabled = key.getBoolean("enabled")
                    view.alpha = if (view.isEnabled) 1f else 0.3f
                    view.contentDescription = if (key.getString("id") == "mode") AppCopy.text(if (ascii) "switchVietnamese" else "switchAscii")
                                              else "${key.getString("position")}: ${if (view.isEnabled) title else AppCopy.text("unavailable")}"
                }
            }
        }
        findViewById<Button>(R.id.keyboard_caps)?.apply { isEnabled = ascii || symbols; alpha = if (isEnabled) 1f else 0.3f; isSelected = uppercase && !symbols }
    }

    private fun keyParams(weight: Float = 1f) = LayoutParams(0, keyHeight - dp(6), weight).apply { setMargins(dp(2), dp(3), dp(2), dp(3)) }
    private fun button(title: String, description: String, identifier: Int = View.NO_ID, action: () -> Unit): Button = Button(context).apply {
        id = identifier; text = title; contentDescription = description; isAllCaps = false
        isFocusable = false; isFocusableInTouchMode = false; stateListAnimator = null
        minWidth = 0; minimumWidth = 0; minHeight = 0; minimumHeight = 0; setPadding(0, 0, 0, 0)
        textSize = if (title.length > 3) 13f else 20f; setTextColor(ink)
        theme.text(this)
        val color = theme.keyColor(title)
        background = theme.keyBackground(color)
        setTextColor(android.content.res.ColorStateList(arrayOf(intArrayOf(android.R.attr.state_pressed), intArrayOf()), intArrayOf(theme.background, color)))
        setOnClickListener { action() }
    }

    private fun addEditing(row: LinearLayout) {
        val delete = button("⌫", AppCopy.text("backspace"), R.id.keyboard_backspace) { session()?.backspace() }
        var touching = false
        delete.setOnClickListener { if (!touching) session()?.backspace() }
        val repeat = object : Runnable { override fun run() { session()?.backspace(); handler.postDelayed(this, 90) } }
        delete.setOnTouchListener { view, event ->
            when (event.actionMasked) {
                MotionEvent.ACTION_DOWN -> { touching = true; view.isPressed = true; session()?.backspace(); handler.postDelayed(repeat, 420); true }
                MotionEvent.ACTION_UP -> { handler.removeCallbacks(repeat); view.isPressed = false; view.performClick(); touching = false; true }
                MotionEvent.ACTION_CANCEL -> { handler.removeCallbacks(repeat); view.isPressed = false; touching = false; true }
                else -> true
            }
        }
        row.addView(delete, keyParams())
        row.addView(button("↵", "Return", R.id.keyboard_return) { session()?.enter() }, keyParams())
    }
    fun stopRepeating() { handler.removeCallbacksAndMessages(null) }
    override fun onDetachedFromWindow() { stopRepeating(); super.onDetachedFromWindow() }
}
