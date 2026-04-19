import SwiftUI
import WebKit

extension InstagramWebView {
    // MARK: - Leak-safe message handler wrapper

    class LeakAvoider: NSObject, WKScriptMessageHandler {
        weak var delegate: WKScriptMessageHandler?
        init(delegate: WKScriptMessageHandler) { self.delegate = delegate; super.init() }
        func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
            delegate?.userContentController(controller, didReceive: message)
        }
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        struct ArticleOpenDefaults {
            let savedCardIndex: Int
            let savedBookTitle: String
            let currentArticleId: String
            let currentArticleOpenToken: Int
        }

        var parent: InstagramWebView
        weak var webView: WKWebView?
        var lastReloadToken: Int
        var lastLabelsToken: Int
        var lastWikipediaTitle: String
        var lastNativeNavCommandToken: Int
        var lastRequestedURLToken: Int
        var lastIsActive: Bool
        var didSendInitialActiveNavCommand: Bool

        init(_ parent: InstagramWebView) {
            self.parent = parent
            self.lastReloadToken = parent.reloadToken
            self.lastLabelsToken = parent.labelsToken
            self.lastWikipediaTitle = ""
            self.lastNativeNavCommandToken = parent.nativeNavCommandToken
            // Force the first updateUIView pass to process requestedURLString/token.
            // This is important for lazily created secondary surfaces.
            self.lastRequestedURLToken = Int.min
            self.lastIsActive = parent.isActive
            self.didSendInitialActiveNavCommand = false
        }
    }
}
