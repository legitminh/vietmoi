package com.minh.sieuviet.android

import org.json.JSONObject

/** Own one shared Swift engine, confined to the IME's main thread. */
class NativeEngine(output: Int, private val input: Int, mode: Int = 0) : AutoCloseable {
    private var handle = nativeCreate(output, mode)
    val state: JSONObject get() { check(handle != 0L); return JSONObject(nativeState(handle, input)) }
    data class Effect(val kind: Int, val text: String)
    fun dispatch(command: Int, argument: Int = 0): Effect {
        check(handle != 0L)
        val kind = nativeDispatch(handle, command, argument)
        return Effect(kind, if (kind >= 0) nativeText(handle) else "")
    }
    override fun close() { if (handle != 0L) { nativeDestroy(handle); handle = 0L } }
    fun observeKey(usage: Int, down: Boolean, timestamp: Double, other: Boolean): Boolean {
        check(handle != 0L); return nativeObserveKey(handle, usage, down, timestamp, other)
    }
    private external fun nativeCreate(output: Int, mode: Int): Long
    private external fun nativeDestroy(handle: Long)
    private external fun nativeDispatch(handle: Long, command: Int, argument: Int): Int
    private external fun nativeObserveKey(handle: Long, usage: Int, down: Boolean, timestamp: Double, other: Boolean): Boolean
    private external fun nativeText(handle: Long): String
    private external fun nativeState(handle: Long, input: Int): String
    companion object {
        init { System.loadLibrary("sieuviet_jni") }
        const val KEY = 0; const val COMPONENT = 1; const val BACKSPACE = 2; const val CANCEL = 3
        const val FINISH = 4; const val TOGGLE = 5; const val SPACE = 6; const val CLEAR = 7
        const val NONE = 0; const val MARKED = 1; const val COMMIT = 2; const val CANCELLED = 3; const val DELETE_CYCLE = 4
    }
}
