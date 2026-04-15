import SwiftUI
import WebKit
import UserNotifications

struct InstagramWebView: UIViewRepresentable {
    @Binding var isLoading: Bool
    @Binding var showingReader: Bool
    @Binding var showingSettings: Bool
    @Binding var reloadToken: Int
    /// Incremented by InstagramView when AppSettings.adLabels changes; triggers re-injection.
    @Binding var labelsToken: Int

    /// Module scripts injected in dependency order before the bootstrap.
    private static let moduleScripts: [String] = [
        "constants",
        "config",
        "dom-utils",
        "scroll-lock",
        "card-logic",
        "wikipedia",
        // card-builder sub-modules (helpers first, index last)
        "card-builder-helpers",
        "card-metrics",
        "card-mood",
        "card-timer",
        "card-stop",
        "card-stats",
        "card-book",
        "card-culture",
        "card-builder",
        // remaining modules
        "card-injection",
        "ad-detection",
        "page-manager",
        "nav-management",
        "top-menu",
        "session-stats",
        "tracking",
        "runtime-state",
        "runtime-ui",
        "runtime-scan",
    ]

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        if let yamlInjection = buildYAMLInjectionScript() {
            config.userContentController.addUserScript(WKUserScript(
                source: yamlInjection,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: true
            ))
        }

        // Inject ad labels + frequency so they're available before modules load
        config.userContentController.addUserScript(WKUserScript(
            source: buildLabelsInjectionScript(),
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        ))

        // Expose current book reading state to JS
        config.userContentController.addUserScript(WKUserScript(
            source: buildBookStateScript(),
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        ))

        // Inject all module scripts in dependency order, then the bootstrap.
        for script in Self.loadAllScripts() {
            config.userContentController.addUserScript(WKUserScript(
                source: script,
                injectionTime: .atDocumentEnd,
                forMainFrameOnly: true
            ))
        }

        // Book-reader bridge
        config.userContentController.add(
            LeakAvoider(delegate: context.coordinator), name: "openBookReader"
        )
        // General bridge: language detection, reload, future events
        config.userContentController.add(
            LeakAvoider(delegate: context.coordinator), name: "stopScrollBridge"
        )

        let webView = WKWebView(frame: .zero, configuration: config)
        context.coordinator.webView = webView
        webView.navigationDelegate = context.coordinator
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.scrollView.keyboardDismissMode = .onDrag
        webView.allowsLinkPreview = false
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"

        if let url = URL(string: "https://www.instagram.com/") {
            webView.load(URLRequest(url: url))
        }
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        if context.coordinator.lastReloadToken != reloadToken {
            context.coordinator.lastReloadToken = reloadToken
            uiView.reload()
        }
        if context.coordinator.lastLabelsToken != labelsToken {
            context.coordinator.lastLabelsToken = labelsToken
            // Re-inject globals AND reload config into the running state
            let reloadScript = buildLabelsInjectionScript() + """
            (function() {
                var ns = window.StopScroll;
                if (ns && ns.config && ns.config.loadConfig && ns._state) {
                    ns._state.config = ns.config.loadConfig();
                }
            })();
            """
            uiView.evaluateJavaScript(reloadScript)
        }
    }

    // MARK: - Script builders

    /// Serialises AppSettings.adLabels and injectionFrequency to the WebView.
    func buildLabelsInjectionScript() -> String {
        let labels = AppSettings.shared.adLabels
        let jsonData = (try? JSONSerialization.data(withJSONObject: labels)) ?? Data()
        let json = String(data: jsonData, encoding: .utf8) ?? "[]"
        let freq = AppSettings.shared.injectionFrequency
        return "window.__STOPSCROLL_AD_LABELS = \(json); window.__STOPSCROLL_FREQUENCY = \(freq);"
    }

    private func buildYAMLInjectionScript() -> String? {
        guard let configURL = Bundle.main.url(forResource: "dynamic_feed_config", withExtension: "yaml"),
              let yaml = try? String(contentsOf: configURL, encoding: .utf8) else { return nil }
        let escaped = yaml
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
            .replacingOccurrences(of: "${", with: "\\${")
        return "window.__STOPSCROLL_DYNAMIC_YAML = `\(escaped)`;"
    }

    /// Reads persisted book state from UserDefaults and exposes it to JS.
    func buildBookStateScript() -> String {
        let title = UserDefaults.standard.string(forKey: "savedBookTitle") ?? ""
        let cardIndex = UserDefaults.standard.integer(forKey: "savedCardIndex")
        let bookId = UserDefaults.standard.string(forKey: "currentBookId") ?? ""

        // Try to get totalPages from the library entry
        var totalPages = 0
        if !bookId.isEmpty,
           let data = UserDefaults.standard.data(forKey: "library"),
           let lib = try? JSONDecoder().decode([LibraryBook].self, from: data) {
            if let entry = lib.first(where: { $0.id == bookId }) {
                totalPages = entry.totalPages
            }
        }

        let escapedTitle = title
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
        return "window.__STOPSCROLL_BOOK = {title:'\(escapedTitle)',page:\(cardIndex),totalPages:\(totalPages),hasBook:\(!bookId.isEmpty)};"
    }

    /// Loads all module scripts + bootstrap in dependency order from the bundle.
    private static func loadAllScripts() -> [String] {
        var scripts: [String] = []
        for name in moduleScripts {
            if let url = Bundle.main.url(forResource: name, withExtension: "js"),
               let src = try? String(contentsOf: url, encoding: .utf8) {
                scripts.append(src)
            }
        }
        // Bootstrap entry point – must come last.
        if let url = Bundle.main.url(forResource: "block_reels", withExtension: "js"),
           let src = try? String(contentsOf: url, encoding: .utf8) {
            scripts.append(src)
        }
        return scripts
    }


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
        var parent: InstagramWebView
        weak var webView: WKWebView?
        var lastReloadToken: Int
        var lastLabelsToken: Int

        init(_ parent: InstagramWebView) {
            self.parent = parent
            self.lastReloadToken = parent.reloadToken
            self.lastLabelsToken = parent.labelsToken
        }

        func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
            switch message.name {
            case "openBookReader":
                DispatchQueue.main.async { self.parent.showingReader = true }
            case "stopScrollBridge":
                handleBridgeMessage(message.body)
            default:
                break
            }
        }

        private func handleBridgeMessage(_ body: Any) {
            if let action = body as? String, action == "reloadFeed" {
                DispatchQueue.main.async { self.webView?.reload() }
                return
            }
            if let dict = body as? [String: Any],
               let type = dict["type"] as? String {
                if type == "openSettings" {
                    DispatchQueue.main.async { self.parent.showingSettings = true }
                    return
                }
                if type == "setTimer",
                   let minutes = dict["minutes"] as? Int {
                    let label = dict["label"] as? String ?? "Time's up"
                    scheduleTimerNotification(minutes: minutes, label: label)
                    return
                }
                if type == "cancelTimer" {
                    UNUserNotificationCenter.current()
                        .removePendingNotificationRequests(withIdentifiers: ["stopscroll-timer"])
                    return
                }
                if type == "language",
                   let lang = dict["value"] as? String {
                    AppSettings.shared.seedLabels(forLanguage: lang)
                    DispatchQueue.main.async {
                        self.webView?.evaluateJavaScript(self.parent.buildLabelsInjectionScript())
                    }
                }
                if type == "openArticle",
                   let title = dict["title"] as? String,
                   let text = dict["text"] as? String,
                   !text.isEmpty {
                    handleOpenArticle(title: title, text: text)
                }
                if type == "fetchArticle" {
                    let lang = (dict["lang"] as? String) ?? "en"
                    fetchWikipediaArticle(lang: lang)
                }
            }
        }

        /// Save a Wikipedia article into BookStorage & library, then open the reader.
        private func handleOpenArticle(title: String, text: String) {

        /// Fetch a random Wikipedia article natively (bypasses CSP) and inject it into JS.
        private func fetchWikipediaArticle(lang: String) {
            let safeLang = lang.prefix(5).filter { $0.isLetter }
            let urlString = "https://\(safeLang).wikipedia.org/api/rest_v1/page/random/summary"
            guard let url = URL(string: urlString) else { return }
            URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
                guard let data = data, error == nil,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
                let title = (json["title"] as? String ?? "").replacingOccurrences(of: "'", with: "\\'")
                let extract = (json["extract"] as? String ?? "").replacingOccurrences(of: "'", with: "\\'")
                    .replacingOccurrences(of: "\n", with: "\\n")
                let desc = (json["description"] as? String ?? "").replacingOccurrences(of: "'", with: "\\'")
                let pageUrl: String
                if let urls = json["content_urls"] as? [String: Any],
                   let mobile = urls["mobile"] as? [String: Any],
                   let page = mobile["page"] as? String {
                    pageUrl = page.replacingOccurrences(of: "'", with: "\\'")
                } else { pageUrl = "" }
                let thumb: String
                if let t = json["thumbnail"] as? [String: Any],
                   let src = t["source"] as? String {
                    thumb = src.replacingOccurrences(of: "'", with: "\\'")
                } else { thumb = "" }
                let js = """
                (function(){
                    var ns = window.StopScroll;
                    if (ns && ns.wikipedia && ns.wikipedia._setFromNative) {
                        ns.wikipedia._setFromNative({
                            title:'\(title)',extract:'\(extract)',description:'\(desc)',
                            pageUrl:'\(pageUrl)',thumbnail:'\(thumb)',lang:'\(safeLang)'
                        });
                    }
                })();
                """
                DispatchQueue.main.async {
                    self?.webView?.evaluateJavaScript(js)
                }
            }.resume()
        }

            let bookId = UUID().uuidString
            let chapters: [(title: String, text: String)] = [(title, text)]
            BookStorage.save(chapters: chapters, bookId: bookId)

            // Build cards to get totalCards / totalPages
            let cards = BookParser.makeCards(from: chapters, mode: .flow)
            let textCards = cards.filter { if case .text = $0.type { return true }; return false }
            let totalPages = textCards.isEmpty ? 0 : textCards.last!.page

            // Add to library
            var library: [LibraryBook] = []
            if let data = UserDefaults.standard.data(forKey: "library"),
               let lib = try? JSONDecoder().decode([LibraryBook].self, from: data) {
                library = lib
            }
            library.append(LibraryBook(
                id: bookId, title: title,
                savedCardIndex: 0, totalCards: cards.count,
                currentChapter: 1, totalPages: totalPages,
                readingMode: ReadingMode.flow.rawValue, isArticle: true
            ))
            if let encoded = try? JSONEncoder().encode(library) {
                UserDefaults.standard.set(encoded, forKey: "library")
            }

            // Update AppStorage keys so BookReaderView picks it up
            DispatchQueue.main.async {
                UserDefaults.standard.set(bookId, forKey: "currentBookId")
                UserDefaults.standard.set(0, forKey: "savedCardIndex")
                UserDefaults.standard.set(title, forKey: "savedBookTitle")
                self.parent.showingReader = true
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            if let yamlInjection = parent.buildYAMLInjectionScript() {
                webView.evaluateJavaScript(yamlInjection)
            }
            // Refresh book reading state
            webView.evaluateJavaScript(parent.buildBookStateScript())
            // Inject user label list (UserDefaults) so JS picks up any edits.
            webView.evaluateJavaScript(parent.buildLabelsInjectionScript())
            // Re-inject all module scripts + bootstrap after each navigation.
            for script in InstagramWebView.loadAllScripts() {
                webView.evaluateJavaScript(script)
            }
            DispatchQueue.main.async {
                withAnimation(.easeOut(duration: 0.3)) {
                    self.parent.isLoading = false
                }
            }
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            // Block only the Reels TAB (exact path /reels or /reels/).
            if let path = navigationAction.request.url?.path {
                let trimmed = path.hasSuffix("/") ? String(path.dropLast()) : path
                if trimmed == "/reels" { decisionHandler(.cancel); return }
            }
            decisionHandler(.allow)
        }

        // MARK: - Timer

        private func scheduleTimerNotification(minutes: Int, label: String) {
            let center = UNUserNotificationCenter.current()
            center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
                guard granted else { return }
                let content = UNMutableNotificationContent()
                content.title = "StopScroll"
                content.body = "Timer done — \(label). Time to put the phone down."
                content.sound = .default

                let trigger = UNTimeIntervalNotificationTrigger(
                    timeInterval: max(TimeInterval(minutes * 60), 1),
                    repeats: false
                )

                // Remove any previous StopScroll timer before scheduling a new one
                center.removePendingNotificationRequests(withIdentifiers: ["stopscroll-timer"])

                let request = UNNotificationRequest(
                    identifier: "stopscroll-timer",
                    content: content,
                    trigger: trigger
                )
                center.add(request)
            }
        }
    }
}
