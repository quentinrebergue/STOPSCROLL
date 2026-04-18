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
    var onGrantXP: (Int, String) -> Void = { _, _ in }

    /// Module scripts injected in dependency order before the bootstrap.
    private static let moduleScripts: [String] = [
        "constants",
        "config",
        "dom-utils",
        "scroll-lock",
        "card-logic",
        "wikipedia",
        "guardian",
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
        let sources = Array(AppSettings.shared.articleSources)
        let srcData = (try? JSONSerialization.data(withJSONObject: sources)) ?? Data()
        let srcJson = String(data: srcData, encoding: .utf8) ?? "[]"
        let devMode = AppSettings.shared.devMode ? "true" : "false"
        return "window.__STOPSCROLL_AD_LABELS = \(json); window.__STOPSCROLL_FREQUENCY = \(freq); window.__STOPSCROLL_ARTICLE_SOURCES = \(srcJson); window.__STOPSCROLL_DEV_MODE = \(devMode);"
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

        init(_ parent: InstagramWebView) {
            self.parent = parent
            self.lastReloadToken = parent.reloadToken
            self.lastLabelsToken = parent.labelsToken
            self.lastWikipediaTitle = ""
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
            if let action = body as? String {
                let handled = dispatchBridgeAction(type: action, payload: [:])
                if !handled {
                    print("[StopScroll] Unknown bridge action: \(action)")
                }
                return
            }

            guard let dict = body as? [String: Any],
                  let type = dict["type"] as? String else {
                print("[StopScroll] Invalid bridge message payload")
                return
            }

            let requestId = dict["id"] as? String
            let payload = (dict["payload"] as? [String: Any]) ?? dict
            let handled = dispatchBridgeAction(type: type, payload: payload)

            if handled {
                bridgeResponse(ok: true, requestId: requestId, type: type)
            } else {
                bridgeResponse(
                    ok: false,
                    requestId: requestId,
                    type: type,
                    code: "unknown_action",
                    message: "Unknown bridge action \(type)"
                )
            }
        }

        private func dispatchBridgeAction(type: String, payload: [String: Any]) -> Bool {
            if type == "reloadFeed" {
                DispatchQueue.main.async { self.webView?.reload() }
                return true
            }
            if type == "openSettings" {
                DispatchQueue.main.async { self.parent.showingSettings = true }
                return true
            }
            if type == "setTimer",
               let minutes = payload["minutes"] as? Int {
                let label = payload["label"] as? String ?? "Time's up"
                scheduleTimerNotification(minutes: minutes, label: label)
                return true
            }
            if type == "cancelTimer" {
                UNUserNotificationCenter.current()
                    .removePendingNotificationRequests(withIdentifiers: ["stopscroll-timer"])
                return true
            }
            if type == "language",
               let lang = payload["value"] as? String {
                AppSettings.shared.seedLabels(forLanguage: lang)
                DispatchQueue.main.async {
                    self.webView?.evaluateJavaScript(self.parent.buildLabelsInjectionScript())
                }
                return true
            }
            if type == "openArticle",
               let title = payload["title"] as? String {
                let lang = (payload["lang"] as? String) ?? "en"
                fetchFullArticleAndOpen(title: title, lang: lang)
                return true
            }
            if type == "fetchArticle" {
                let lang = (payload["lang"] as? String) ?? "en"
                fetchWikipediaArticle(lang: lang)
                return true
            }
            if type == "fetchGuardianArticle" {
                fetchGuardianArticle()
                return true
            }
            if type == "grantXP" {
                let amount = Self.parseXPAmount(payload["amount"])
                let source = (payload["source"] as? String) ?? "action"
                DispatchQueue.main.async {
                    self.parent.onGrantXP(amount, source)
                }
                return true
            }
            if type == "openGuardianArticle",
               let urlString = payload["url"] as? String,
               let title = payload["title"] as? String {
                fetchGuardianFullArticleAndOpen(urlString: urlString, title: title)
                return true
            }
            return false
        }

        static func parseXPAmount(_ value: Any?) -> Int {
            if let intValue = value as? Int { return intValue }
            if let doubleValue = value as? Double { return Int(doubleValue.rounded()) }
            if let stringValue = value as? String, let intValue = Int(stringValue) { return intValue }
            return 10
        }

        private func bridgeResponse(
            ok: Bool,
            requestId: String?,
            type: String,
            code: String? = nil,
            message: String? = nil
        ) {
            guard let requestId, !requestId.isEmpty else { return }

            var payload: [String: Any] = [
                "ok": ok,
                "requestId": requestId,
                "type": type,
                "ts": Int(Date().timeIntervalSince1970 * 1000)
            ]
            if let code { payload["code"] = code }
            if let message { payload["message"] = message }

            guard let data = try? JSONSerialization.data(withJSONObject: payload),
                  let json = String(data: data, encoding: .utf8) else { return }

            let escaped = json
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "'", with: "\\'")
            let js = "(function(){var ns=window.StopScroll;if(ns&&ns.dom&&ns.dom._onNativeBridgeResult){ns.dom._onNativeBridgeResult(JSON.parse('\\(escaped)'));}})();"

            DispatchQueue.main.async {
                self.webView?.evaluateJavaScript(js)
            }
        }

        /// Fetch a curated Wikipedia article (featured or "on this day") and inject it into JS.
        private func fetchWikipediaArticle(lang: String) {
            let safeLang = String(lang.prefix(5).filter { $0.isLetter })

            // Use the "featured" endpoint which returns the daily featured article,
            // most-read articles, and "on this day" — all editorially curated.
            let now = Date()
            let cal = Calendar.current
            let y = cal.component(.year, from: now)
            let m = String(format: "%02d", cal.component(.month, from: now))
            let d = String(format: "%02d", cal.component(.day, from: now))
            let urlString = "https://\(safeLang).wikipedia.org/api/rest_v1/feed/featured/\(y)/\(m)/\(d)"
            guard let url = URL(string: urlString) else {
                // Fallback to random summary
                fetchRandomWikipediaArticle(lang: safeLang)
                return
            }

            URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
                guard let data = data, error == nil,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    // Fallback to random summary
                    self?.fetchRandomWikipediaArticle(lang: safeLang)
                    return
                }

                // Strategy: pick from most-read articles (more variety than the single featured article)
                var picked: [String: Any]? = nil

                // 1. Try most-read articles (top 15, pick a random one that looks interesting)
                if let mostRead = json["mostread"] as? [String: Any],
                   let articles = mostRead["articles"] as? [[String: Any]] {
                    // Filter out very short extracts and disambiguation pages
                    let good = articles.filter { art in
                        let ext = art["extract"] as? String ?? ""
                        let desc = (art["description"] as? String ?? "").lowercased()
                        return ext.count > 80
                            && !desc.contains("disambiguation")
                            && !desc.contains("wikimedia")
                            && !desc.contains("wikipedia")
                    }
                    picked = Self.pickWikipediaArticle(from: good, avoidingTitle: self?.lastWikipediaTitle)
                }

                // 2. Fallback: today's featured article
                if picked == nil, let tfa = json["tfa"] as? [String: Any] {
                    picked = Self.pickWikipediaArticle(from: [tfa], avoidingTitle: self?.lastWikipediaTitle)
                }

                // 3. Fallback: on-this-day person/event
                if picked == nil, let otd = json["onthisday"] as? [[String: Any]],
                   let first = otd.first,
                   let pages = first["pages"] as? [[String: Any]],
                   let page = pages.first {
                    picked = Self.pickWikipediaArticle(from: [page], avoidingTitle: self?.lastWikipediaTitle)
                }

                guard let article = picked else {
                    self?.fetchRandomWikipediaArticle(lang: safeLang)
                    return
                }

                if let title = article["title"] as? String {
                    self?.lastWikipediaTitle = title
                }

                self?.injectArticleToJS(article: article, lang: safeLang)
            }.resume()
        }

        /// Fallback: fetch a random Wikipedia summary (for languages without featured feed).
        private func fetchRandomWikipediaArticle(lang: String) {
            let urlString = "https://\(lang).wikipedia.org/api/rest_v1/page/random/summary"
            guard let url = URL(string: urlString) else { return }
            URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
                guard let data = data, error == nil,
                      let article = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
                self?.injectArticleToJS(article: article, lang: lang)
            }.resume()
        }

        /// Inject an article object (from any Wikipedia API) into the JS runtime.
        private func injectArticleToJS(article: [String: Any], lang: String) {
            let title = (article["title"] as? String ?? "").replacingOccurrences(of: "'", with: "\\'")
            let extract = (article["extract"] as? String ?? "").replacingOccurrences(of: "'", with: "\\'")
                .replacingOccurrences(of: "\n", with: "\\n")
            let desc = (article["description"] as? String ?? "").replacingOccurrences(of: "'", with: "\\'")
            let pageUrl: String
            if let urls = article["content_urls"] as? [String: Any],
               let mobile = urls["mobile"] as? [String: Any],
               let page = mobile["page"] as? String {
                pageUrl = page.replacingOccurrences(of: "'", with: "\\'")
            } else { pageUrl = "" }
            let thumb: String
            if let t = article["thumbnail"] as? [String: Any],
               let src = t["source"] as? String {
                thumb = src.replacingOccurrences(of: "'", with: "\\'")
            } else { thumb = "" }
            let js = """
            (function(){
                var ns = window.StopScroll;
                if (ns && ns.wikipedia && ns.wikipedia._setFromNative) {
                    ns.wikipedia._setFromNative({
                        title:'\(title)',extract:'\(extract)',description:'\(desc)',
                        pageUrl:'\(pageUrl)',thumbnail:'\(thumb)',lang:'\(lang)'
                    });
                }
            })();
            """
            DispatchQueue.main.async {
                self.webView?.evaluateJavaScript(js)
            }
        }

        // MARK: - The Guardian

        /// Fetch a random article from The Guardian API (editorially curated, top stories).
        private func fetchGuardianArticle() {
            let apiKey = "test" // The Guardian's open API key; replace with your own for production
            var components = URLComponents(string: "https://content.guardianapis.com/search")!
            components.queryItems = [
                URLQueryItem(name: "section", value: "world|science|technology|books|culture|environment"),
                URLQueryItem(name: "show-fields", value: "trailText,thumbnail"),
                URLQueryItem(name: "page-size", value: "20"),
                URLQueryItem(name: "order-by", value: "newest"),
                URLQueryItem(name: "api-key", value: apiKey)
            ]
            guard let url = components.url else {
                print("[StopScroll] Guardian: failed to build URL")
                injectGuardianError("bad_url")
                return
            }

            URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
                if let error = error {
                    print("[StopScroll] Guardian fetch error: \(error.localizedDescription)")
                    self?.injectGuardianError("network")
                    return
                }
                guard let data = data else {
                    print("[StopScroll] Guardian: no data")
                    self?.injectGuardianError("no_data")
                    return
                }
                guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let resp = json["response"] as? [String: Any],
                      let results = resp["results"] as? [[String: Any]],
                      !results.isEmpty else {
                    let preview = String(data: data.prefix(500), encoding: .utf8) ?? "<binary>"
                    print("[StopScroll] Guardian: unexpected response – \(preview)")
                    self?.injectGuardianError("parse")
                    return
                }

                // Pick a random article from the results
                let article = results[Int.random(in: 0..<results.count)]
                self?.injectGuardianArticleToJS(article: article)
            }.resume()
        }

        /// Notify JS that Guardian fetch failed so it can retry.
        private func injectGuardianError(_ reason: String) {
            let js = "(function(){var ns=window.StopScroll;if(ns&&ns.guardian&&ns.guardian._setFromNative){ns.guardian._setFromNative(null);}})();"
            DispatchQueue.main.async {
                self.webView?.evaluateJavaScript(js)
            }
        }

        /// Inject a Guardian article into the JS runtime using safe JSON serialization.
        private func injectGuardianArticleToJS(article: [String: Any]) {
            let title = article["webTitle"] as? String ?? ""
            let webUrl = article["webUrl"] as? String ?? ""
            let sectionName = article["sectionName"] as? String ?? ""
            let fields = article["fields"] as? [String: Any] ?? [:]
            let rawTrailText = fields["trailText"] as? String ?? ""
            // Strip HTML tags from trailText
            let extract = rawTrailText.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            let thumbnail = fields["thumbnail"] as? String ?? ""

            // Use JSON serialization to safely pass article data (handles all escaping)
            let articleDict: [String: String] = [
                "title": title,
                "extract": extract.isEmpty ? sectionName : extract,
                "description": sectionName,
                "webUrl": webUrl,
                "thumbnail": thumbnail
            ]
            guard let jsonData = try? JSONSerialization.data(withJSONObject: articleDict),
                  let jsonString = String(data: jsonData, encoding: .utf8) else {
                print("[StopScroll] Guardian: failed to serialize article JSON")
                injectGuardianError("json")
                return
            }

            let js = "(function(){var ns=window.StopScroll;if(ns&&ns.guardian&&ns.guardian._setFromNative){ns.guardian._setFromNative(JSON.parse('\(jsonString.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "'", with: "\\'"))'));}})();"
            DispatchQueue.main.async {
                self.webView?.evaluateJavaScript(js) { _, error in
                    if let error = error {
                        print("[StopScroll] Guardian JS injection error: \(error)")
                    }
                }
            }
        }

        /// Fetch Guardian article full text and open in reader.
        private func fetchGuardianFullArticleAndOpen(urlString: String, title: String) {
            let apiKey = "test"
            // Convert web URL to API URL
            let articlePath = urlString
                .replacingOccurrences(of: "https://www.theguardian.com/", with: "")
            let apiUrlString = "https://content.guardianapis.com/\(articlePath)?show-fields=bodyText&api-key=\(apiKey)"
            guard let url = URL(string: apiUrlString) else { return }

            URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
                guard let data = data, error == nil,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let response = json["response"] as? [String: Any],
                      let content = response["content"] as? [String: Any],
                      let fields = content["fields"] as? [String: Any],
                      let bodyText = fields["bodyText"] as? String,
                      !bodyText.isEmpty else { return }

                let chapters = [(title: title, text: bodyText)]
                DispatchQueue.main.async {
                    self?.handleOpenArticle(title: title, chapters: chapters)
                }
            }.resume()
        }

        /// Fetch the full Wikipedia article text, split into sections, then open the reader.
        private func fetchFullArticleAndOpen(title: String, lang: String) {
            guard let url = Self.makeWikipediaExtractURL(title: title, lang: lang) else { return }

            URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
                guard let data = data, error == nil,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let query = json["query"] as? [String: Any],
                      let pages = query["pages"] as? [String: Any] else { return }

                // The API returns pages keyed by page ID; grab the first (only) one
                guard let pageObj = pages.values.first as? [String: Any],
                      let fullText = pageObj["extract"] as? String,
                      !fullText.isEmpty else { return }

                // Split into sections on == Heading == patterns
                let chapters = Self.splitIntoChapters(title: title, fullText: fullText)

                DispatchQueue.main.async {
                    self?.handleOpenArticle(title: title, chapters: chapters)
                }
            }.resume()
        }

        /// Split Wikipedia plain-text extract into (title, text) chapters by section headings.
        static func splitIntoChapters(title: String, fullText: String) -> [(title: String, text: String)] {
            let lines = fullText.components(separatedBy: "\n")
            var chapters: [(title: String, text: String)] = []
            var currentTitle = title
            var currentLines: [String] = []

            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                // Detect == Section == headings (any level: ==, ===, ====)
                if trimmed.hasPrefix("==") && trimmed.hasSuffix("==") {
                    // Flush previous section
                    let text = currentLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                    if !text.isEmpty {
                        chapters.append((currentTitle, text))
                    }
                    // Extract heading text (strip = signs and whitespace)
                    currentTitle = trimmed
                        .replacingOccurrences(of: "=", with: "")
                        .trimmingCharacters(in: .whitespaces)
                    currentLines = []
                } else {
                    currentLines.append(line)
                }
            }
            // Flush last section
            let lastText = currentLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            if !lastText.isEmpty {
                chapters.append((currentTitle, lastText))
            }

            // Filter out very short "See also", "References", "External links" sections
            let skipSections: Set<String> = ["see also", "references", "external links", "further reading",
                                              "notes", "bibliography", "sources",
                                              "voir aussi", "références", "liens externes", "notes et références",
                                              "bibliographie", "annexes"]
            chapters = chapters.filter { ch in
                !skipSections.contains(ch.title.lowercased())
            }

            return chapters.isEmpty ? [(title, fullText)] : chapters
        }

        static func makeArticleOpenDefaults(previousOpenToken: Int, articleId: String, title: String) -> ArticleOpenDefaults {
            ArticleOpenDefaults(
                savedCardIndex: 0,
                savedBookTitle: title,
                currentArticleId: articleId,
                currentArticleOpenToken: previousOpenToken + 1
            )
        }

        static func makeWikipediaExtractURL(title: String, lang: String) -> URL? {
            let safeLang = String(lang.prefix(5).filter { $0.isLetter })
            var components = URLComponents()
            components.scheme = "https"
            components.host = "\(safeLang).wikipedia.org"
            components.path = "/w/api.php"
            components.queryItems = [
                URLQueryItem(name: "action", value: "query"),
                URLQueryItem(name: "prop", value: "extracts"),
                URLQueryItem(name: "titles", value: title),
                URLQueryItem(name: "explaintext", value: "1"),
                URLQueryItem(name: "format", value: "json"),
                URLQueryItem(name: "exlimit", value: "1")
            ]
            return components.url
        }

        static func pickWikipediaArticle(from articles: [[String: Any]], avoidingTitle: String?) -> [String: Any]? {
            guard !articles.isEmpty else { return nil }
            guard let avoidingTitle, !avoidingTitle.isEmpty else {
                return articles.randomElement()
            }

            let normalizedAvoiding = avoidingTitle.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let filtered = articles.filter { article in
                let title = (article["title"] as? String ?? "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .lowercased()
                return title != normalizedAvoiding
            }

            return filtered.randomElement()
        }

        /// Save a Wikipedia article into BookStorage & library, then open the reader.
        private func handleOpenArticle(title: String, chapters: [(title: String, text: String)]) {
            // ── Deduplicate: reuse existing article entry with the same title ──
            var library: [LibraryBook] = []
            if let data = UserDefaults.standard.data(forKey: "library"),
               let lib = try? JSONDecoder().decode([LibraryBook].self, from: data) {
                library = lib
            }

            let existingId = library.first(where: { $0.isArticle && $0.title == title })?.id
            let bookId = existingId ?? UUID().uuidString

            if existingId == nil {
                // New article — save chapters and add library entry
                BookStorage.save(chapters: chapters, bookId: bookId)

                let cards = BookParser.makeCards(from: chapters, mode: .flow)
                let textCards = cards.filter { if case .text = $0.type { return true }; return false }
                let totalPages = textCards.isEmpty ? 0 : textCards.last!.page

                library.append(LibraryBook(
                    id: bookId, title: title,
                    savedCardIndex: 0, totalCards: cards.count,
                    currentChapter: 1, totalPages: totalPages,
                    readingMode: ReadingMode.flow.rawValue, isArticle: true
                ))
                if let encoded = try? JSONEncoder().encode(library) {
                    UserDefaults.standard.set(encoded, forKey: "library")
                }
            }

            // Update AppStorage keys — use "currentArticleId" (separate from books)
            DispatchQueue.main.async {
                let openToken = UserDefaults.standard.integer(forKey: "currentArticleOpenToken")
                let next = Self.makeArticleOpenDefaults(previousOpenToken: openToken, articleId: bookId, title: title)

                UserDefaults.standard.set(next.savedCardIndex, forKey: "savedCardIndex")
                UserDefaults.standard.set(next.savedBookTitle, forKey: "savedBookTitle")
                UserDefaults.standard.set(next.currentArticleId, forKey: "currentArticleId")
                UserDefaults.standard.set(next.currentArticleOpenToken, forKey: "currentArticleOpenToken")

                // Present reader on next run loop so @AppStorage-backed values are visible on first open.
                DispatchQueue.main.async {
                    self.parent.showingReader = true
                }
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
