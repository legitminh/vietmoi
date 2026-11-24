import Foundation
import WebKit

// Every app hosts the same siêu việt UI (Resources/WebApp, built from sieuviet.site):
// the intro, the managed keyboard list and the testing ground. The page reads the
// native keyboard list at start, posts each change back, and receives updates made
// elsewhere, such as a Shift tap in the input method.
final class SharedWebApp: NSObject, WKURLSchemeHandler {
    static let scheme = "sieuviet"
    private let platform: String
    private let readState: () -> [String: Any]
    private let writeState: ([String: Any]) -> Void
    private let root: URL?
    private(set) weak var webView: WKWebView?

    init(platform: String, readState: @escaping () -> [String: Any], writeState: @escaping ([String: Any]) -> Void) {
        self.platform = platform
        self.readState = readState
        self.writeState = writeState
        root = Bundle.main.url(forResource: "WebApp", withExtension: nil)
        super.init()
    }

    /// Create the web view on `page`: "intro", "keyboards" or "try".
    func makeWebView(page: String) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.setURLSchemeHandler(self, forURLScheme: Self.scheme)
        let content = WKUserContentController()
        content.add(MessageRelay(self), name: "sieuviet")
        content.addUserScript(WKUserScript(source: "window.__SIEUVIET_NATIVE__ = " + Self.json(["platform": platform, "state": readState()]) + ";",
                                           injectionTime: .atDocumentStart, forMainFrameOnly: true))
        configuration.userContentController = content
        let view = WKWebView(frame: .zero, configuration: configuration)
        #if os(macOS)
        view.setValue(false, forKey: "drawsBackground")
        #else
        view.isOpaque = false
        view.backgroundColor = .clear
        view.scrollView.contentInsetAdjustmentBehavior = .never
        #endif
        webView = view
        view.load(URLRequest(url: URL(string: "\(Self.scheme)://app/index.html#\(page)")!))
        return view
    }

    /// Send the current native state to the page after a change made elsewhere.
    func push() {
        webView?.evaluateJavaScript("window.sieuvietReceive && window.sieuvietReceive(\(Self.json(readState())))", completionHandler: nil)
    }

    fileprivate func receive(_ body: Any) {
        guard let message = body as? [String: Any], message["type"] as? String == "state",
              let state = message["state"] as? [String: Any] else { return }
        writeState(state)
    }

    private static func json(_ value: Any) -> String {
        guard JSONSerialization.isValidJSONObject(value),
              let data = try? JSONSerialization.data(withJSONObject: value) else { return "null" }
        return String(data: data, encoding: .utf8) ?? "null"
    }

    // Serve the bundled files on sieuviet://app/ so ES modules load with real MIME types.
    func webView(_ webView: WKWebView, start task: WKURLSchemeTask) {
        guard let url = task.request.url, let root = root?.standardizedFileURL else {
            task.didFailWithError(URLError(.fileDoesNotExist)); return
        }
        let path = url.path.isEmpty || url.path == "/" ? "index.html" : String(url.path.dropFirst())
        let file = root.appendingPathComponent(path).standardizedFileURL
        guard file.path.hasPrefix(root.path + "/"), let data = try? Data(contentsOf: file) else {
            task.didFailWithError(URLError(.fileDoesNotExist)); return
        }
        let types = ["html": "text/html; charset=utf-8", "js": "text/javascript; charset=utf-8", "css": "text/css; charset=utf-8",
                     "json": "application/json", "svg": "image/svg+xml", "png": "image/png", "woff2": "font/woff2",
                     "wasm": "application/wasm", "txt": "text/plain; charset=utf-8"]
        let headers = ["Content-Type": types[file.pathExtension] ?? "application/octet-stream", "Content-Length": String(data.count)]
        guard let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: headers) else {
            task.didFailWithError(URLError(.badServerResponse)); return
        }
        task.didReceive(response)
        task.didReceive(data)
        task.didFinish()
    }
    func webView(_ webView: WKWebView, stop task: WKURLSchemeTask) {}
}

// WKUserContentController retains its handlers; relay weakly to avoid a cycle.
private final class MessageRelay: NSObject, WKScriptMessageHandler {
    weak var target: SharedWebApp?
    init(_ target: SharedWebApp) { self.target = target }
    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        target?.receive(message.body)
    }
}
