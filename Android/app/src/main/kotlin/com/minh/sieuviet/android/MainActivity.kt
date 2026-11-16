package com.minh.sieuviet.android

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.provider.Settings
import android.text.InputType
import android.view.Gravity
import android.view.View
import android.view.WindowInsets
import android.view.inputmethod.InputMethodManager
import android.widget.*

class MainActivity : Activity() {
    private var showingSettings = false
    private lateinit var body: LinearLayout
    private lateinit var editor: EditText
    private val theme by lazy { AppTheme(this) }
    private val store by lazy { SettingsStore(this) }
    private fun dp(value: Int) = (resources.displayMetrics.density * value).toInt()
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        store.load()
        val compact = resources.configuration.orientation == android.content.res.Configuration.ORIENTATION_LANDSCAPE
        val root = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL; setPadding(dp(20), 0, dp(20), 0) }
        root.setOnApplyWindowInsetsListener { view, insets ->
            if (android.os.Build.VERSION.SDK_INT >= 30) {
                val bars = insets.getInsets(WindowInsets.Type.systemBars())
                val keyboard = insets.getInsets(WindowInsets.Type.ime()).bottom
                view.setPadding(dp(20) + bars.left, bars.top + dp(if (compact) 4 else 18), dp(20) + bars.right, maxOf(bars.bottom, keyboard))
            } else {
                // Android 10 uses the platform's adjustResize path.
                @Suppress("DEPRECATION")
                view.setPadding(dp(20) + insets.systemWindowInsetLeft, insets.systemWindowInsetTop + dp(if (compact) 4 else 18),
                                dp(20) + insets.systemWindowInsetRight, insets.systemWindowInsetBottom)
            }
            insets
        }
        root.addView(TextView(this).apply { text = "★ " + AppDesign.name; textSize = if (compact) 20f else 32f; setPadding(0, 0, 0, dp(4)) })
        if (!compact) root.addView(TextView(this).apply { text = AppCopy.text("tagline"); textSize = 15f; setPadding(0, 0, 0, dp(12)) })
        val tabs = LinearLayout(this)
        tabs.addView(Button(this).apply { id = R.id.practice_tab; text = AppCopy.text("tryKeyboard"); setOnClickListener { practice() } }, LinearLayout.LayoutParams(0, dp(48), 1f))
        tabs.addView(Button(this).apply { id = R.id.settings_tab; text = AppCopy.text("settings"); setOnClickListener { settings() } }, LinearLayout.LayoutParams(0, dp(48), 1f))
        root.addView(tabs)
        val scroll = ScrollView(this).apply { isFillViewport = true }
        body = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL; setPadding(0, dp(12), 0, dp(16)) }
        scroll.addView(body)
        root.addView(scroll, LinearLayout.LayoutParams(-1, 0, 1f))
        root.setBackgroundColor(theme.background)
        window.statusBarColor = theme.background
        window.navigationBarColor = theme.background
        restyle(root)
        setContentView(root)
        if (savedInstanceState?.getBoolean("settings") == true) settings() else practice()
        if (intent.getBooleanExtra("openKeyboard", false)) editor.postDelayed({
            editor.requestFocus()
            getSystemService(InputMethodManager::class.java).showSoftInput(editor, InputMethodManager.SHOW_IMPLICIT)
        }, 350)
    }

    override fun onSaveInstanceState(outState: Bundle) {
        outState.putBoolean("settings", showingSettings)
        super.onSaveInstanceState(outState)
    }
    private fun practice() {
        showingSettings = false
        body.removeAllViews()
        body.addView(TextView(this).apply {
            text = AppCopy.text("practiceHelp")
            textSize = 15f; setPadding(0, 0, 0, dp(14))
        })
        editor = EditText(this).apply {
            id = R.id.test_editor; hint = AppCopy.text("tryTyping")
            inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_FLAG_MULTI_LINE or InputType.TYPE_TEXT_FLAG_NO_SUGGESTIONS
            gravity = Gravity.TOP; textSize = 25f; minLines = 3; setPadding(dp(10), dp(10), dp(10), dp(10))
        }
        body.addView(editor, LinearLayout.LayoutParams(-1, dp(160)))
        body.addView(EditText(this).apply {
            id = R.id.second_editor; hint = AppCopy.text("secondField")
            inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_FLAG_NO_SUGGESTIONS
            textSize = 19f; isSingleLine = true
        }, LinearLayout.LayoutParams(-1, dp(60)))
        val setup = LinearLayout(this)
        setup.addView(Button(this).apply { text = AppCopy.text("enableKeyboard"); setOnClickListener { startActivity(Intent(Settings.ACTION_INPUT_METHOD_SETTINGS)) } }, LinearLayout.LayoutParams(0, dp(48), 1f))
        setup.addView(Button(this).apply { text = AppCopy.text("selectKeyboard"); setOnClickListener { getSystemService(InputMethodManager::class.java).showInputMethodPicker() } }, LinearLayout.LayoutParams(0, dp(48), 1f))
        body.addView(setup)
        body.addView(TextView(this).apply { text = AppCopy.text("androidEnableHelp"); textSize = 13f })
        // Starting the app does not steal focus from its setup controls.
        restyle(body)
        body.isFocusableInTouchMode = true; body.requestFocus()
    }

    private fun restyle(view: View) {
        if (view is TextView) {
            theme.text(view)
            if (view is EditText) { view.background = theme.outline(radius = AppDesign.panelRadius); view.setHintTextColor(theme.muted) }
            else if (view is Button) { view.isAllCaps = false; view.textSize = 12f; view.background = theme.keyBackground(theme.border) }
        }
        if (view is android.view.ViewGroup) for (index in 0 until view.childCount) restyle(view.getChildAt(index))
    }

    private fun settings() {
        showingSettings = true
        getSystemService(InputMethodManager::class.java).hideSoftInputFromWindow(body.windowToken, 0)
        body.removeAllViews()
        val current = store.load()
        body.addView(TextView(this).apply { text = AppCopy.text("keyboardSettings"); textSize = 24f; setPadding(0, 0, 0, dp(18)) })
        fun selector(title: String, options: Array<String>, selected: Int, identifier: Int): Spinner {
            body.addView(TextView(this).apply { text = title; textSize = 16f; setPadding(0, dp(12), 0, dp(6)) })
            return Spinner(this).apply {
                id = identifier; contentDescription = title
                adapter = object : ArrayAdapter<String>(this@MainActivity, android.R.layout.simple_spinner_dropdown_item, options) {
                    override fun getView(position: Int, convertView: View?, parent: android.view.ViewGroup): View = super.getView(position, convertView, parent).also { restyle(it) }
                    override fun getDropDownView(position: Int, convertView: View?, parent: android.view.ViewGroup): View = super.getDropDownView(position, convertView, parent).also { restyle(it); it.setBackgroundColor(theme.surface) }
                }
                setSelection(selected, false)
                body.addView(this, LinearLayout.LayoutParams(-1, dp(54)))
            }
        }
        val input = selector(AppCopy.text("inputLabel"), arrayOf("ascii+", "grid4x8"), current.input, R.id.input_selector)
        val output = selector(AppCopy.text("outputLabel"), arrayOf(AppDesign.name, "quốc ngữ"), current.output, R.id.output_selector)
        val language = selector(AppCopy.text("language"), arrayOf(AppCopy.text("vietnamese"), AppCopy.text("english")), if (current.language == "en") 1 else 0, R.id.language_selector)
        val listener = object : AdapterView.OnItemSelectedListener {
            override fun onItemSelected(parent: AdapterView<*>?, view: View?, position: Int, id: Long) {
                val next = KeyboardSettings(input.selectedItemPosition, output.selectedItemPosition, if (language.selectedItemPosition == 1) "en" else "vi")
                store.save(next)
                if (next.language != current.language) recreate()
            }
            override fun onNothingSelected(parent: AdapterView<*>?) = Unit
        }
        input.onItemSelectedListener = listener; output.onItemSelectedListener = listener; language.onItemSelectedListener = listener
        body.addView(TextView(this).apply {
            text = AppCopy.text("settingsHelp")
            textSize = 15f; setPadding(0, dp(22), 0, 0)
        })
        restyle(body)
    }
}
