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
        // card-builder sub-modules (helpers first, index last)
        "card-builder-helpers",
        "card-metrics",
        "card-mood",
        "card-timer",
        "card-stop",
        "card-stats",
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
            uiView.evaluateJavaScript(buildLabelsInjectionScript())
        }
    }

    // MARK: - Script builders

    /// Serialises AppSettings.adLabels to window.__STOPSCROLL_AD_LABELS in the WebView.
    func buildLabelsInjectionScript() -> String {
        let labels = AppSettings.shared.adLabels
        let jsonData = (try? JSONSerialization.data(withJSONObject: labels)) ?? Data()
        let json = String(data: jsonData, encoding: .utf8) ?? "[]"
        return "window.__STOPSCROLL_AD_LABELS = \(json);"
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
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            if let yamlInjection = parent.buildYAMLInjectionScript() {
                webView.evaluateJavaScript(yamlInjection)
            }
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
