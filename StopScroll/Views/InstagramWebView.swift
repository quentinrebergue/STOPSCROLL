import SwiftUI
import WebKit

struct InstagramWebView: UIViewRepresentable {
    @Binding var isLoading: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        // Inject the Reels-blocking script at document end
        if let scriptURL = Bundle.main.url(forResource: "block_reels", withExtension: "js"),
           let scriptSource = try? String(contentsOf: scriptURL, encoding: .utf8) {
            let userScript = WKUserScript(
                source: scriptSource,
                injectionTime: .atDocumentEnd,
                forMainFrameOnly: true
            )
            config.userContentController.addUserScript(userScript)
        }

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black

        // Set mobile user agent so Instagram serves the mobile web UI
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"

        // Load Instagram
        if let url = URL(string: "https://www.instagram.com/") {
            webView.load(URLRequest(url: url))
        }

        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: InstagramWebView

        init(_ parent: InstagramWebView) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // Re-inject the script after each page load (SPA navigations)
            if let scriptURL = Bundle.main.url(forResource: "block_reels", withExtension: "js"),
               let scriptSource = try? String(contentsOf: scriptURL, encoding: .utf8) {
                webView.evaluateJavaScript(scriptSource)
            }

            DispatchQueue.main.async {
                self.parent.isLoading = false
            }
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            // Block only the Reels TAB (exact path /reels or /reels/).
            // Allow everything else: /reel/ID, /reels/ID, DM links, etc.
            if let path = navigationAction.request.url?.path {
                let trimmed = path.hasSuffix("/") ? String(path.dropLast()) : path
                if trimmed == "/reels" {
                    decisionHandler(.cancel)
                    return
                }
            }
            decisionHandler(.allow)
        }
    }
}
