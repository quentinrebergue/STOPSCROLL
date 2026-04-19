import Foundation
import UserNotifications
import WebKit

extension InstagramWebView.Coordinator {
    func sendNativeNavigationCommand(tab: String, onlyIfActive: Bool) {
        if onlyIfActive && !parent.isActive { return }
        if !parent.handlesInstagramNavigation { return }
        guard tab != "book", tab != "dashboard" else { return }
        let escapedTab = tab
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
        let script = "(function(){var ns=window.StopScroll;if(ns&&ns.nav&&ns.nav.nativeNavigateToTab){ns.nav.nativeNavigateToTab('\(escapedTab)');}})();"
        webView?.evaluateJavaScript(script)
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

    func handleBridgeMessage(_ body: Any) {
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

    func dispatchBridgeAction(type: String, payload: [String: Any]) -> Bool {
        if type == "reloadFeed" {
            DispatchQueue.main.async { self.webView?.reload() }
            return true
        }
        if type == "openSettings" {
            DispatchQueue.main.async { self.parent.showingSettings = true }
            return true
        }
        if type == "openDashboard" {
            DispatchQueue.main.async { self.parent.showingDashboard = true }
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
        if type == "nativeNavState" {
            let tab = (payload["tab"] as? String) ?? "home"
            let badgeCount = Self.parseXPAmount(payload["messageBadge"])
            DispatchQueue.main.async {
                guard self.parent.isActive else { return }
                self.parent.selectedNativeTab = tab
                self.parent.nativeMessageBadgeCount = max(0, badgeCount)
            }
            return true
        }
        if type == "instagramTheme" {
            let isDark: Bool
            if let dark = payload["dark"] as? Bool {
                isDark = dark
            } else if let darkInt = payload["dark"] as? Int {
                isDark = darkInt != 0
            } else if let darkString = payload["dark"] as? String {
                isDark = darkString == "1" || darkString.lowercased() == "true"
            } else {
                isDark = true
            }
            let background = (payload["background"] as? String) ?? (payload["bg"] as? String)
            DispatchQueue.main.async {
                self.parent.instagramThemeIsDark = isDark
                AppSettings.shared.updateInstagramBackgroundColor(background)
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

    func bridgeResponse(
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

        let escapedJSON = json
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
        let js = "(function(){var ns=window.StopScroll;if(ns&&ns.dom&&ns.dom._onNativeBridgeResult){ns.dom._onNativeBridgeResult(JSON.parse('\(escapedJSON)'));}})();"

        DispatchQueue.main.async {
            self.webView?.evaluateJavaScript(js)
        }
    }
}
