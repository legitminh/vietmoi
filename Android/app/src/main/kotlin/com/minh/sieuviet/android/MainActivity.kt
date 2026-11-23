package com.minh.sieuviet.android

import android.annotation.SuppressLint
import android.app.Activity
import android.os.Bundle
import android.view.WindowInsets
import android.webkit.JavascriptInterface
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.WebView
import android.webkit.WebViewClient
import org.json.JSONObject

/**
 * The app hosts the shared siêu việt UI (assets/WebApp, built from sieuviet.site): the intro,
 * the managed keyboard list and the testing ground. The IME reads the saved list when it opens.
 */
class MainActivity : Activity() {
    private val store by lazy { SettingsStore(this) }
    private lateinit var web: WebView

    @SuppressLint("SetJavaScriptEnabled")
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        store.load()
        val theme = AppTheme(this)
        web = WebView(this).apply {
            id = R.id.shared_app
            setBackgroundColor(theme.background)
            settings.javaScriptEnabled = true
            settings.domStorageEnabled = true
            settings.allowFileAccess = false
            settings.allowContentAccess = false
            addJavascriptInterface(Bridge(), "sieuvietAndroid")
            webViewClient = object : WebViewClient() {
                override fun shouldInterceptRequest(view: WebView, request: WebResourceRequest): WebResourceResponse? {
                    val url = request.url
                    if (url.host != HOST) return WebResourceResponse("text/plain", "utf-8", 404, "Not Found", emptyMap(), null)
                    val path = url.path?.trimStart('/')?.ifEmpty { "index.html" } ?: "index.html"
                    if (path.split('/').any { it == ".." }) return null
                    return try {
                        WebResourceResponse(mime(path), "utf-8", assets.open("WebApp/$path"))
                    } catch (_: Exception) { WebResourceResponse("text/plain", "utf-8", 404, "Not Found", emptyMap(), null) }
                }
                override fun shouldOverrideUrlLoading(view: WebView, request: WebResourceRequest) = request.url.host != HOST
            }
        }
        web.setOnApplyWindowInsetsListener { view, insets ->
            if (android.os.Build.VERSION.SDK_INT >= 30) {
                val bars = insets.getInsets(WindowInsets.Type.systemBars())
                view.setPadding(bars.left, bars.top, bars.right, bars.bottom)
            }
            insets
        }
        window.statusBarColor = theme.background
        window.navigationBarColor = theme.background
        setContentView(web)
        val page = if (intent.getBooleanExtra("openKeyboard", false)) "try" else "keyboards"
        if (savedInstanceState != null) web.restoreState(savedInstanceState) else web.loadUrl("https://$HOST/index.html#$page")
    }

    override fun onSaveInstanceState(outState: Bundle) { web.saveState(outState); super.onSaveInstanceState(outState) }

    private fun mime(path: String) = when (path.substringAfterLast('.')) {
        "html" -> "text/html"; "js" -> "text/javascript"; "css" -> "text/css"; "json" -> "application/json"
        "svg" -> "image/svg+xml"; "png" -> "image/png"; "woff2" -> "font/woff2"; else -> "application/octet-stream"
    }

    private inner class Bridge {
        @JavascriptInterface fun platform() = "android"
        @JavascriptInterface fun getState(): String = store.load().toJson().toString()
        @JavascriptInterface fun postMessage(json: String) {
            val message = try { JSONObject(json) } catch (_: Exception) { return }
            if (message.optString("type") != "state") return
            val state = message.optJSONObject("state") ?: return
            try { store.save(KeyboardSettings.fromJson(state)) } catch (_: Exception) { }
        }
    }

    companion object { const val HOST = "app.sieuviet.local" }
}
