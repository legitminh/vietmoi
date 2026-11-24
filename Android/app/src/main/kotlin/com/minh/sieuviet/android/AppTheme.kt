package com.minh.sieuviet.android

import android.content.Context
import android.content.res.Configuration
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.graphics.drawable.StateListDrawable
import android.widget.TextView

/** Native rendering of Design/brand.json, shared by the activity and the IME. */
class AppTheme(private val context: Context) {
    private val dark = context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK == Configuration.UI_MODE_NIGHT_YES
    val background = Color.parseColor(if (dark) AppDesign.darkBackground else AppDesign.lightBackground)
    val surface = Color.parseColor(if (dark) AppDesign.darkSurface else AppDesign.lightSurface)
    val ink = Color.parseColor(if (dark) AppDesign.darkInk else AppDesign.lightInk)
    val muted = Color.parseColor(if (dark) AppDesign.darkMuted else AppDesign.lightMuted)
    val border = Color.parseColor(if (dark) AppDesign.darkBorder else AppDesign.lightBorder)
    private fun dp(value: Int) = (context.resources.displayMetrics.density * value).toInt()
    fun keyColor(key: String): Int {
        val hue = AppDesign.keyHues[key] ?: return ink
        val rgb = Color.HSVToColor(floatArrayOf(hue, 1f, 1f))
        val primary = if (dark) 0.8f else 0.2f
        fun channel(value: Int) = (((0.2575f + value / 255f * 0.585f) * 0.6f + primary * 0.4f) * 255).toInt()
        return Color.rgb(channel(Color.red(rgb)), channel(Color.green(rgb)), channel(Color.blue(rgb)))
    }
    fun outline(color: Int = border, fill: Int = surface, radius: Int = AppDesign.keyRadius) = GradientDrawable().apply {
        setColor(fill); cornerRadius = dp(radius).toFloat(); setStroke(maxOf(1, dp(AppDesign.borderWidth)), color)
    }
    fun keyBackground(color: Int) = StateListDrawable().apply {
        addState(intArrayOf(android.R.attr.state_pressed), outline(color, color))
        addState(intArrayOf(android.R.attr.state_selected), outline(color, color))
        addState(intArrayOf(), outline(color))
    }
    fun text(view: TextView) { view.typeface = Typeface.MONOSPACE; view.setTextColor(ink) }
}
