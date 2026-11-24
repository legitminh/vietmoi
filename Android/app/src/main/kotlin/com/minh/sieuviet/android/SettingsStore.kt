package com.minh.sieuviet.android

import android.content.Context
import android.util.AtomicFile
import org.json.JSONArray
import org.json.JSONObject
import java.io.File

/** One managed keyboard: its language decides the allowed input layouts and outputs. */
data class KeyboardProfile(val id: String, val name: String, val language: String = "vi",
                           val input: Int = 0, val output: Int = 0, val showVirtualKeyboard: Boolean = true) {
    /** English keyboards type literal text through the engine's literal mode. */
    val literal: Boolean get() = language == "en"
    fun toJson(): JSONObject = JSONObject().put("id", id).put("name", name).put("language", if (literal) "en" else "vi")
        .put("inputType", if (literal) "qwerty" else if (input == 1) "grid4x8" else "ascii+")
        .put("outputType", if (literal) "literal" else if (output == 1) "quốc ngữ" else "sieuviet")
        .put("showVirtualKeyboard", showVirtualKeyboard)
    companion object {
        fun fromJson(data: JSONObject): KeyboardProfile {
            val english = data.optString("language") == "en"
            return KeyboardProfile(data.getString("id"), data.optString("name"), if (english) "en" else "vi",
                if (!english && data.optString("inputType") == "grid4x8") 1 else 0,
                if (!english && data.optString("outputType") == "quốc ngữ") 1 else 0,
                data.optBoolean("showVirtualKeyboard", true))
        }
    }
}

/** The managed keyboard list, the app's selected keyboard and the interface language. */
data class KeyboardSettings(val profiles: List<KeyboardProfile>, val activeId: String, val language: String) {
    /** A single-keyboard setup lists that keyboard and English, which the old Shift tap reached. */
    constructor(input: Int = 0, output: Int = 0, language: String = "vi") : this(listOf(
        KeyboardProfile(VIETNAMESE_ID, "Default keyboard", "vi", input, output),
        KeyboardProfile(ENGLISH_ID, "English", "en")), VIETNAMESE_ID, language)
    val active: KeyboardProfile get() = profiles.firstOrNull { it.id == activeId } ?: profiles.first()
    val input: Int get() = active.input
    val output: Int get() = active.output
    fun next(after: String): KeyboardProfile = profiles[(profiles.indexOfFirst { it.id == after } + 1).mod(profiles.size)]
    fun previous(before: String): KeyboardProfile = profiles[(profiles.indexOfFirst { it.id == before }.coerceAtLeast(0) - 1).mod(profiles.size)]
    /** The shared settings UI's schema. */
    fun toJson(): JSONObject = JSONObject().put("version", 2).put("profiles", JSONArray(profiles.map { it.toJson() }))
        .put("activeID", activeId).put("interfaceLanguage", language).put("shiftTapSeconds", 0.2)
    companion object {
        const val VIETNAMESE_ID = "5F1E7C2A-0000-4000-8000-000000000001"
        const val ENGLISH_ID = "5F1E7C2A-0000-4000-8000-000000000002"
        fun fromJson(data: JSONObject): KeyboardSettings {
            val language = AppCopy.supportedLanguage(data.optString("interfaceLanguage").ifEmpty { data.optString("language") })
            val list = data.optJSONArray("profiles")
            if (list == null || list.length() == 0) {
                return KeyboardSettings(if (data.optString("input") == "grid4x8") 1 else 0,
                    if (data.optString("output") == "quốc ngữ") 1 else 0, language)
            }
            val profiles = (0 until list.length()).map { KeyboardProfile.fromJson(list.getJSONObject(it)) }
            val active = data.optString("activeID").takeIf { id -> profiles.any { it.id == id } } ?: profiles.first().id
            return KeyboardSettings(profiles, active, language)
        }
    }
}

/** App writes; the separate IME process reads only at editor activation. */
class SettingsStore(context: Context) {
    private val base = File(context.filesDir, "keyboard-settings-v1.json")
    private val file = AtomicFile(base)
    fun load(): KeyboardSettings = try {
        // AtomicFile.openRead can repair backups. The IME only reads the base
        // snapshot; recovery and writes belong to the containing app.
        KeyboardSettings.fromJson(JSONObject(base.readText(Charsets.UTF_8))).also { AppCopy.language = it.language }
    } catch (_: Exception) { KeyboardSettings().also { AppCopy.language = "vi" } }
    fun save(value: KeyboardSettings) {
        val data = value.toJson().toString().toByteArray(Charsets.UTF_8)
        val stream = file.startWrite()
        try { stream.write(data); file.finishWrite(stream); AppCopy.language = value.language }
        catch (error: Exception) { file.failWrite(stream); throw error }
    }
}
