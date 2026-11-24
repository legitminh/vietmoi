package com.minh.sieuviet.android

import android.view.KeyEvent

/** Android/Linux scan-code translation only; Sieuviet bindings live in Swift. */
object HardwareKeys {
    private val letters = mapOf(16 to 'q', 17 to 'w', 18 to 'e', 19 to 'r', 20 to 't', 21 to 'y', 22 to 'u', 23 to 'i', 24 to 'o', 25 to 'p',
        30 to 'a', 31 to 's', 32 to 'd', 33 to 'f', 34 to 'g', 35 to 'h', 36 to 'j', 37 to 'k', 38 to 'l',
        44 to 'z', 45 to 'x', 46 to 'c', 47 to 'v', 48 to 'b', 49 to 'n', 50 to 'm')
    fun usage(event: KeyEvent): Int? {
        letters[event.scanCode]?.let { return it.code - 'a'.code + 4 }
        when (event.scanCode) {
            in 2..10 -> return event.scanCode - 2 + 0x1e
            11 -> return 0x27
            39 -> return 0x33
            42 -> return 0xe1
            54 -> return 0xe5
        }
        return when (event.keyCode) {
            in KeyEvent.KEYCODE_A..KeyEvent.KEYCODE_Z -> event.keyCode - KeyEvent.KEYCODE_A + 4
            in KeyEvent.KEYCODE_1..KeyEvent.KEYCODE_9 -> event.keyCode - KeyEvent.KEYCODE_1 + 0x1e
            KeyEvent.KEYCODE_SHIFT_LEFT -> 0xe1
            KeyEvent.KEYCODE_SHIFT_RIGHT -> 0xe5
            KeyEvent.KEYCODE_SEMICOLON -> 0x33
            else -> null
        }
    }
    fun position(usage: Int?): String? = when (usage) {
        in 4..29 -> ('a'.code + usage!! - 4).toChar().toString()
        in 0x1e..0x25 -> ('1'.code + usage!! - 0x1e).toChar().toString()
        0x33 -> ";"
        else -> null
    }
}
