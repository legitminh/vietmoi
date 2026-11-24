package com.minh.sieuviet.android

import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import java.text.Normalizer

@RunWith(AndroidJUnit4::class)
class NativeEngineTests {
    private fun usage(key: Char) = if (key == ';') 0x33 else key.code - 'a'.code + 4
    @Test fun reviewedWordsAndGuideUseTheActualSwiftLibrary() {
        for ((keys, outputs) in listOf("msed" to listOf("má ", "má "), "rwos" to listOf("răo ", "rau "),
                                      "frej" to listOf("fở ", "phở "), "xaqs" to listOf("xoong ", "xoong "),
                                      "imoj" to listOf("khwỉo ", "khuỷu "))) {
            for (output in 0..1) NativeEngine(output, 0).use { engine ->
                var effect = NativeEngine.Effect(0, "")
                for (key in keys) effect = engine.dispatch(NativeEngine.KEY, usage(key))
                assertEquals(outputs[output], effect.text)
                assertEquals(NativeEngine.COMMIT, effect.kind)
                assertEquals(NativeEngine.NONE, engine.dispatch(NativeEngine.KEY, usage('a')).kind)
                assertEquals(0, engine.state.getInt("phase"))
            }
        }
        NativeEngine(1, 0).use { engine ->
            var effect = NativeEngine.Effect(0, "")
            for (key in "frej") effect = engine.dispatch(NativeEngine.KEY, usage(key))
            assertEquals("phở ", effect.text)
            assertEquals(NativeEngine.COMMIT, effect.kind)
            assertEquals(3, engine.state.getJSONArray("rows").length())
            assertEquals(2, engine.state.getJSONArray("symbolPages").length())
        }
    }

    @Test fun quocNguInputModeSpellsWithQuocNguChoices() {
        for ((output, keys, expected) in listOf(Triple(1, "qlcd", "quốc "), Triple(0, "zses", "za "))) {
            NativeEngine(output, 0, mode = 1).use { engine ->
                var effect = NativeEngine.Effect(0, "")
                for (key in keys) effect = engine.dispatch(NativeEngine.KEY, usage(key))
                assertEquals(expected, effect.text)
                assertEquals(NativeEngine.COMMIT, effect.kind)
            }
        }
        val profile = KeyboardProfile.fromJson(KeyboardProfile("A", "Mixed", mode = 1).toJson())
        assertEquals(1, profile.mode)
        assertEquals(0, KeyboardProfile.fromJson(KeyboardProfile("B", "English", "en", mode = 1).toJson()).mode)
    }

    @Test fun adaptivePunctuationComesFromTheSharedCore() {
        assertEquals("quá! ", NativeEngine.adaptivePunctuation("quá ", "!"))
        assertEquals("quá!. ", NativeEngine.adaptivePunctuation("quá! ", "."))
        assertNull(NativeEngine.adaptivePunctuation("quá ", "a"))
        assertNull(NativeEngine.adaptivePunctuation("quá", ","))
        assertFalse(KeyboardProfile.fromJson(KeyboardProfile("A", "Off", adaptive = false).toJson()).adaptive)
        assertTrue(KeyboardProfile.fromJson(org.json.JSONObject().put("id", "B").put("name", "Old")).adaptive)
    }

    @Test fun all79200ConstructionsRunNativelyOnAndroid() {
        var count = 0
        for (output in 0..1) NativeEngine(output, 0).use { engine ->
            for (initial in 0 until 25) for (vowel in 0 until 24) for (final in 0 until 11) for (tone in 0 until 6) {
                assertEquals(NativeEngine.MARKED, engine.dispatch(NativeEngine.COMPONENT, initial).kind)
                assertEquals(NativeEngine.MARKED, engine.dispatch(NativeEngine.COMPONENT, vowel).kind)
                assertEquals(NativeEngine.MARKED, engine.dispatch(NativeEngine.COMPONENT, final).kind)
                val effect = engine.dispatch(NativeEngine.COMPONENT, tone)
                assertEquals(NativeEngine.COMMIT, effect.kind)
                assertTrue(effect.text.endsWith(" ") && !effect.text.endsWith("  "))
                assertEquals(effect.text, Normalizer.normalize(effect.text, Normalizer.Form.NFC))
                assertFalse(effect.text.any { it.isISOControl() || it.code in 0xE000..0xF8FF })
                count++
            }
        }
        assertEquals(79200, count)
    }
}
