package com.minh.sieuviet.android

import android.app.Activity
import android.content.Intent
import android.view.KeyEvent
import android.widget.EditText
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.runner.lifecycle.ActivityLifecycleMonitorRegistry
import androidx.test.runner.lifecycle.Stage
import androidx.test.uiautomator.By
import androidx.test.uiautomator.UiDevice
import androidx.test.uiautomator.UiObject2
import androidx.test.uiautomator.Until
import org.junit.*
import org.junit.Assert.*
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class KeyboardTests {
    private val instrumentation = InstrumentationRegistry.getInstrumentation()
    private val device = UiDevice.getInstance(instrumentation)
    private lateinit var activity: Activity
    private fun objectById(id: String): UiObject2 = device.wait(Until.findObject(By.res(PACKAGE, id)), 4000)
        ?: throw AssertionError("Missing $id")
    private fun tap(id: String) {
        // Focus changes replace the key views; stale nodes have not dispatched a click.
        repeat(3) {
            try { objectById(id).click(); device.waitForIdle(1000); return }
            catch (_: androidx.test.uiautomator.StaleObjectException) { device.waitForIdle(1000) }
        }
        objectById(id).click(); device.waitForIdle(1000)
    }
    private fun type(keys: String) { for (key in keys) tap("key_" + if (key == ';') "semicolon" else key) }
    private fun expectText(text: String, id: String = "test_editor") {
        var actual = ""
        val deadline = android.os.SystemClock.uptimeMillis() + 4000
        do {
            instrumentation.runOnMainSync {
                val live = ActivityLifecycleMonitorRegistry.getInstance().getActivitiesInStage(Stage.RESUMED).first()
                val identifier = live.resources.getIdentifier(id, "id", PACKAGE)
                actual = live.findViewById<EditText>(identifier).text.toString()
            }
            if (actual == text) return
            android.os.SystemClock.sleep(25)
        } while (android.os.SystemClock.uptimeMillis() < deadline)
        assertEquals("Expected $id", text, actual)
    }
    private fun launch(settings: KeyboardSettings = KeyboardSettings()) {
        SettingsStore(instrumentation.targetContext).save(settings)
        activity = instrumentation.startActivitySync(Intent(instrumentation.targetContext, MainActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK))
        device.waitForIdle()
        tap("test_editor")
        device.wait(Until.hasObject(By.res(PACKAGE, "key_mode")), 12000)
        device.waitForIdle(1000)
        objectById("key_mode")
        if (objectById("key_mode").text == "VIỆT") tap("key_mode")
    }
    @Before fun portrait() { device.setOrientationNatural() }
    @After fun restoreRotation() { device.unfreezeRotation() }

    @Test fun languageChoicePersistsAndReachesTheIme() {
        launch()
        assertEquals("dấu cách", objectById("keyboard_space").text)
        tap("settings_tab"); tap("language_selector")
        device.wait(Until.findObject(By.text("English")), 3000)!!.click()
        device.waitForIdle()
        assertEquals("en", SettingsStore(instrumentation.targetContext).load().language)
        tap("practice_tab"); tap("test_editor")
        assertEquals("space", objectById("keyboard_space").text)
        type("msed"); expectText("má ")
        tap("settings_tab"); tap("language_selector")
        device.wait(Until.findObject(By.text("Tiếng Việt")), 3000)!!.click()
        device.waitForIdle()
        tap("practice_tab"); tap("test_editor")
        assertEquals("dấu cách", objectById("keyboard_space").text)
    }

    @Test fun actualImeShowsEachRoundAndBothOutputs() {
        launch(KeyboardSettings(output = 1))
        assertNotEquals(device.executeShellCommand("pidof $PACKAGE").trim(),
                        device.executeShellCommand("pidof $PACKAGE:keyboard").trim())
        tap("key_f"); expectText("f")
        tap("key_r"); expectText("fơ")
        tap("key_e"); expectText("fơ")
        assertEquals("hỏi", objectById("key_j").text)
        tap("key_j"); expectText("phở ")
        type("rwos"); expectText("phở rau ")
        launch()
        type("frejrwos"); expectText("fở răo ")
    }

    @Test fun roundUndoPartialSpaceAndAsciiArePreserved() {
        launch()
        type("ms"); expectText("ma")
        tap("keyboard_backspace"); expectText("m")
        tap("keyboard_backspace"); expectText("")
        type("m"); tap("keyboard_space"); expectText("m ")
        type("m"); tap("key_mode"); tap("key_y"); expectText("m my")
        tap("keyboard_caps"); tap("key_a"); expectText("m myA")
        tap("key_mode")
        tap("keyboard_numbers")
        device.wait(Until.findObject(By.desc("Ký hiệu 1")), 3000)!!.click()
        expectText("m myA1")
        tap("keyboard_numbers")
        type("msed"); expectText("m myA1má ")
        tap("keyboard_return"); expectText("m myA1má \n")
    }

    @Test fun focusChangesDoNotReplayAPartialWord() {
        launch()
        type("m"); expectText("m")
        tap("second_editor")
        type("msed")
        expectText("má ", "second_editor")
        expectText("m")
        tap("test_editor"); type("xvns")
        expectText("mxin ")
        expectText("má ", "second_editor")
    }

    @Test fun settingsScreenTransfersOutputAndGridToTheSeparateImeProcess() {
        launch()
        tap("settings_tab"); tap("output_selector")
        device.wait(Until.findObject(By.text("quốc ngữ")), 3000)!!.click()
        tap("practice_tab"); tap("test_editor"); type("frej"); expectText("phở ")
        tap("settings_tab"); tap("input_selector")
        device.wait(Until.findObject(By.text("grid4x8")), 3000)!!.click()
        tap("practice_tab"); tap("test_editor")
        for (title in listOf("m", "a", "∅", "sắc")) {
            device.wait(Until.findObject(By.descEndsWith(": $title")), 3000)!!.click()
            device.waitForIdle(1000)
        }
        expectText("má ")
        assertTrue(objectById("key_clear").contentDescription.endsWith(": Xóa"))
        tap("key_clear"); expectText("")
    }

    @Test fun selectionCancelAndEmojiDeletionPreserveSurroundingText() {
        launch()
        instrumentation.runOnMainSync {
            activity.findViewById<EditText>(R.id.test_editor).apply { setText("left right"); setSelection(5, 10) }
        }
        device.waitForIdle()
        type("m"); expectText("left m")
        device.pressKeyCode(KeyEvent.KEYCODE_ESCAPE)
        expectText("left right")
        instrumentation.runOnMainSync {
            activity.findViewById<EditText>(R.id.test_editor).apply { setText("A👩🏽‍💻"); setSelection(text.length) }
        }
        device.waitForIdle()
        tap("keyboard_backspace"); expectText("A")
        type("msed"); expectText("Amá ")
    }

    @Test fun alignedGuideWorksInPortraitAndLandscape() {
        launch()
        for (landscape in listOf(false, true)) {
            if (landscape) { device.setOrientationLeft(); device.waitForIdle(); tap("test_editor") }
            assertEquals(objectById("key_q").visibleBounds.left, objectById("key_a").visibleBounds.left)
            assertEquals(objectById("key_p").visibleBounds.left, objectById("key_semicolon").visibleBounds.left)
            assertEquals(objectById("key_q").visibleBounds.left, objectById("key_mode").visibleBounds.left)
            assertTrue(objectById("keyboard_space").visibleBounds.height() > 0)
            if (landscape) {
                device.takeScreenshot(java.io.File(instrumentation.targetContext.filesDir, "rotation-before.png"))
                instrumentation.sendStatus(0, android.os.Bundle().apply { putString("stream", "Landscape ${device.displayWidth}x${device.displayHeight}, m=${objectById("key_m").visibleBounds}, q=${objectById("key_q").visibleBounds}\n") })
            }
            tap("key_m"); expectText("m")
            tap("key_s"); expectText("ma")
            tap("key_e"); expectText("ma")
            tap("key_d"); expectText("má ")
            objectById("test_editor").clear()
        }
    }

    @Test fun physicalKeysUseSharedShiftTapRules() {
        launch()
        for (key in listOf(KeyEvent.KEYCODE_M, KeyEvent.KEYCODE_S, KeyEvent.KEYCODE_E, KeyEvent.KEYCODE_D)) device.pressKeyCode(key)
        expectText("má ")
        device.pressKeyCode(KeyEvent.KEYCODE_M)
        device.pressKeyCode(KeyEvent.KEYCODE_SHIFT_LEFT)
        assertEquals("VIỆT", objectById("key_mode").text)
        device.pressKeyCode(KeyEvent.KEYCODE_Y)
        expectText("má my")
        device.pressKeyCode(KeyEvent.KEYCODE_SHIFT_LEFT)
        assertEquals("ABC", objectById("key_mode").text)
        launch(KeyboardSettings(input = 1))
        device.pressKeyCode(KeyEvent.KEYCODE_R)
        device.pressKeyCode(KeyEvent.KEYCODE_Z)
        expectText("m")
        assertEquals("a", objectById("key_3").text)
        for (key in listOf(KeyEvent.KEYCODE_3, KeyEvent.KEYCODE_1, KeyEvent.KEYCODE_2)) device.pressKeyCode(key)
        expectText("má ")
    }

    companion object {
        const val PACKAGE = "com.minh.sieuviet.android"
        private const val IME = "$PACKAGE/.SieuvietInputMethod"
        private var previousIme = ""
        private var previouslyEnabled = false
        @JvmStatic @BeforeClass fun enableTestIme() {
            val device = UiDevice.getInstance(InstrumentationRegistry.getInstrumentation())
            previousIme = device.executeShellCommand("settings get secure default_input_method").trim()
            previouslyEnabled = device.executeShellCommand("ime list -s").contains(IME)
            device.executeShellCommand("ime enable $IME")
            device.executeShellCommand("ime set $IME")
        }
        @JvmStatic @AfterClass fun restoreIme() {
            val device = UiDevice.getInstance(InstrumentationRegistry.getInstrumentation())
            if (previousIme.isNotBlank() && previousIme != "null") device.executeShellCommand("ime set $previousIme")
            if (!previouslyEnabled) device.executeShellCommand("ime disable $IME")
        }
    }
}
