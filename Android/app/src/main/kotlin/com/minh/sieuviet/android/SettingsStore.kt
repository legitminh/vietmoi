package com.minh.sieuviet.android

import android.content.Context
import android.util.AtomicFile
import org.json.JSONObject
import java.io.File

data class KeyboardSettings(val input: Int = 0, val output: Int = 0, val language: String = "vi")

/** App writes; the separate IME process reads only at editor activation. */
class SettingsStore(context: Context) {
    private val base = File(context.filesDir, "keyboard-settings-v1.json")
    private val file = AtomicFile(base)
    fun load(): KeyboardSettings = try {
        // AtomicFile.openRead can repair backups. The IME only reads the base
        // snapshot; recovery and writes belong to the containing app.
        val data = JSONObject(base.readText(Charsets.UTF_8))
        KeyboardSettings(if (data.optString("input") == "grid4x8") 1 else 0,
            if (data.optString("output") == "quốc ngữ") 1 else 0, if (data.optString("language") == "en") "en" else "vi").also { AppCopy.language = it.language }
    } catch (_: Exception) { KeyboardSettings().also { AppCopy.language = "vi" } }
    fun save(value: KeyboardSettings) {
        val data = JSONObject().put("version", 1).put("input", if (value.input == 1) "grid4x8" else "ascii+")
            .put("language", if (value.language == "en") "en" else "vi")
            .put("output", if (value.output == 1) "quốc ngữ" else "sieuviet").toString().toByteArray(Charsets.UTF_8)
        val stream = file.startWrite()
        try { stream.write(data); file.finishWrite(stream); AppCopy.language = value.language }
        catch (error: Exception) { file.failWrite(stream); throw error }
    }
}
