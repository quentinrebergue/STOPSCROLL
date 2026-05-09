import Foundation
import UserNotifications
import WebKit

extension InstagramWebView.Coordinator {
    private static let nativeCardHistoryLimit = 5
    private static var nativeCardHistory: [String] = []
    private static let nativeCardHistoryQueue = DispatchQueue(label: "StopScroll.NativeCardDecisionHistory")

    func sendNativeNavigationCommand(tab: String, onlyIfActive: Bool) {
        if onlyIfActive && !parent.isActive { return }
        if !parent.handlesInstagramNavigation { return }
        guard tab != "book", tab != "dashboard" else { return }
        let escapedTab = tab
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
        let script = """
        (function(){
            var targetTab = '\(escapedTab)';
            var ns = window.StopScroll;
            if (ns && ns.nav && ns.nav.nativeNavigateToTab) {
                ns.nav.nativeNavigateToTab(targetTab);
                return;
            }

            function normalizePath(path) {
                if (!path) return '/';
                var p = String(path).split('?')[0].split('#')[0];
                if (p.length > 1 && p.charAt(p.length - 1) === '/') {
                    p = p.slice(0, -1);
                }
                return p || '/';
            }

            function detectCurrentTab() {
                var path = normalizePath(window.location && window.location.pathname);
                if (path === '/') return 'home';
                if (path.indexOf('/explore') === 0) return 'search';
                if (path.indexOf('/reels') === 0) return 'reels';
                if (path.indexOf('/direct') === 0) return 'messages';
                if (path.indexOf('/accounts') === 0 || path.indexOf('/settings') === 0) return 'profile';
                return 'home';
            }

            function readVerticalOffset() {
                var scrolling = document.scrollingElement || document.documentElement || document.body;
                var winOffset = typeof window.scrollY === 'number' ? window.scrollY : 0;
                var nodeOffset = scrolling && typeof scrolling.scrollTop === 'number' ? scrolling.scrollTop : 0;
                return Math.max(winOffset, nodeOffset, 0);
            }

            function scrollToTop() {
                try {
                    window.scrollTo({ top: 0, behavior: 'smooth' });
                } catch (_) {
                    try { window.scrollTo(0, 0); } catch (_) {}
                }
                var scrolling = document.scrollingElement || document.documentElement || document.body;
                if (scrolling && typeof scrolling.scrollTop === 'number') {
                    scrolling.scrollTop = 0;
                }
            }

            var current = detectCurrentTab();
            var supportsRetap = targetTab === 'home' || targetTab === 'search' || targetTab === 'reels';
            if (supportsRetap && current === targetTab) {
                if (readVerticalOffset() > 8) {
                    scrollToTop();
                } else {
                    window.location.reload();
                }
                return;
            }

            if (targetTab === 'home') {
                window.location.href = '/';
                return;
            }
            if (targetTab === 'search') {
                window.location.href = '/explore/';
                return;
            }
            if (targetTab === 'reels') {
                window.location.href = '/reels/';
                return;
            }
        })();
        """
        webView?.evaluateJavaScript(script)
    }

    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        switch message.name {
        case "openBookReader":
            handleOpenBookReaderMessage(message.body)
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

        if type == "requestCardForOpportunity" || type == "cardRequest" {
            let decisionPayload = Self.makeCardDecisionPayload(
                from: payload,
                defaultFrequency: AppSettings.shared.injectionFrequency
            )
            bridgeResponse(
                ok: true,
                requestId: requestId,
                type: type,
                responsePayload: decisionPayload
            )
            return
        }

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
        if type == "reelViewed" {
            DispatchQueue.main.async { DailyUsageTracker.shared.recordReel() }
            return true
        }
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
            let endTimestampMs = Self.parseDouble(payload["endTimestamp"])
            scheduleTimerNotification(minutes: minutes, label: label, endTimestampMs: endTimestampMs)
            return true
        }
        if type == "cancelTimer" {
            cancelNativeTimer()
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
        if type == "debugLog" {
            guard AppSettings.shared.devMode else {
                return true
            }
            let message = (payload["message"] as? String) ?? "[JS] debug log"
            let category = (payload["category"] as? String) ?? "JS"
            let levelRaw = ((payload["level"] as? String) ?? "DEBUG").uppercased()
            let level: LogLevel
            switch levelRaw {
            case "INFO": level = .info
            case "WARNING", "WARN": level = .warning
            case "ERROR": level = .error
            case "CRITICAL": level = .critical
            default: level = .debug
            }
            LogManager.shared.log(message, category: category, level: level)
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
            let invalidateOtherWebViewsLazily: Bool
            if let boolValue = payload["lazyRefresh"] as? Bool {
                invalidateOtherWebViewsLazily = boolValue
            } else if let intValue = payload["lazyRefresh"] as? Int {
                invalidateOtherWebViewsLazily = intValue != 0
            } else if let stringValue = payload["lazyRefresh"] as? String {
                invalidateOtherWebViewsLazily = stringValue == "1" || stringValue.lowercased() == "true"
            } else {
                invalidateOtherWebViewsLazily = false
            }
            DispatchQueue.main.async {
                self.parent.instagramThemeIsDark = isDark
                AppSettings.shared.updateInstagramBackgroundColor(
                    background,
                    invalidateOtherWebViewsLazily: invalidateOtherWebViewsLazily
                )
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

    func handleOpenBookReaderMessage(_ body: Any) {
        if let payload = body as? [String: Any] {
            openBookReader(with: payload)
            return
        }

        DispatchQueue.main.async {
            self.parent.selectedNativeTab = "book"
            self.parent.showingReader = true
        }
    }

    func openBookReader(with payload: [String: Any]) {
        let bookId = (payload["bookId"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let articleId = (payload["articleId"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let title = (payload["title"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let requestedPage = max(0, Self.parseXPAmount(payload["page"]))

        DispatchQueue.main.async {
            if !title.isEmpty {
                UserDefaults.standard.set(title, forKey: "savedBookTitle")
            }

            if !articleId.isEmpty {
                let openToken = UserDefaults.standard.integer(forKey: "currentArticleOpenToken")
                UserDefaults.standard.set(articleId, forKey: "currentArticleId")
                UserDefaults.standard.set(openToken + 1, forKey: "currentArticleOpenToken")
                UserDefaults.standard.set(0, forKey: "savedCardIndex")
                if !bookId.isEmpty {
                    UserDefaults.standard.set(bookId, forKey: "currentBookId")
                }
            } else if !bookId.isEmpty {
                UserDefaults.standard.set(bookId, forKey: "currentBookId")
                UserDefaults.standard.set("", forKey: "currentArticleId")
                UserDefaults.standard.set(requestedPage, forKey: "savedCardIndex")
            }

            self.parent.selectedNativeTab = "book"
            self.parent.showingReader = true
        }
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
        message: String? = nil,
        responsePayload: [String: Any]? = nil
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
        if let responsePayload { payload["payload"] = responsePayload }

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

    static func resetNativeCardDecisionHistoryForTests() {
        nativeCardHistoryQueue.sync {
            nativeCardHistory.removeAll()
        }
    }

    static func makeCardDecisionPayload(
        from payload: [String: Any],
        defaultFrequency: Int
    ) -> [String: Any] {
        let opportunityIndex = max(0, parseXPAmount(payload["opportunityIndex"]))
        let requestedFrequency = parseXPAmount(payload["frequency"])
        let frequency = requestedFrequency > 0 ? requestedFrequency : max(0, defaultFrequency)

        if frequency <= 0 {
            return skipDecision(reason: "frequency_disabled")
        }

        if opportunityIndex <= 0 || (opportunityIndex % frequency != 0) {
            return skipDecision(reason: "frequency_gate")
        }

        let availableCards = parseAvailableCards(payload["availableCards"])
        guard !availableCards.isEmpty else {
            return skipDecision(reason: "no_available_cards")
        }

        return nativeCardHistoryQueue.sync {
            let lastShown = nativeCardHistory.first

            // Hard-exclude the immediately previous type, then apply
            // decreasing weight penalties for 2nd–4th in history.
            let penalized: [(type: String, weight: Double)] = availableCards.compactMap { candidate in
                guard candidate.type != lastShown else { return nil }
                var w = candidate.weight
                if let idx = nativeCardHistory.firstIndex(of: candidate.type) {
                    if idx == 1 { w = max(w / 3.0, 0.1) }
                    else if idx == 2 { w = max(w / 2.0, 0.1) }
                    else if idx == 3 { w = max(w / 1.5, 0.1) }
                }
                return (type: candidate.type, weight: w)
            }
            let filtered = penalized.isEmpty ? availableCards : penalized

            let chosen = weightedCardPick(filtered)
            nativeCardHistory.insert(chosen.type, at: 0)
            if nativeCardHistory.count > nativeCardHistoryLimit {
                nativeCardHistory = Array(nativeCardHistory.prefix(nativeCardHistoryLimit))
            }

            let cardContent = buildCardContent(for: chosen.type)
            let cardActions = buildCardActions(for: chosen.type)

            return [
                "contractVersion": 1,
                "decision": "inject",
                "reason": "selected",
                "card": [
                    "schemaVersion": 1,
                    "renderMode": "legacy-builder-v1",
                    "type": chosen.type,
                    "content": cardContent,
                    "actions": cardActions,
                    "meta": [
                        "selectedBy": "native-policy-v1",
                        "weight": chosen.weight
                    ]
                ]
            ]
        }
    }

    private static func skipDecision(reason: String) -> [String: Any] {
        [
            "contractVersion": 1,
            "decision": "skip",
            "reason": reason
        ]
    }

    private static func parseAvailableCards(_ raw: Any?) -> [(type: String, weight: Double)] {
        guard let entries = raw as? [[String: Any]] else { return [] }
        return entries.compactMap { item in
            guard let type = item["type"] as? String,
                  !type.isEmpty else {
                return nil
            }
            let weight = max(0.0001, parseDouble(item["weight"]) ?? 1)
            return (type: type, weight: weight)
        }
    }

    private static func parseDouble(_ value: Any?) -> Double? {
        if let doubleValue = value as? Double { return doubleValue }
        if let intValue = value as? Int { return Double(intValue) }
        if let stringValue = value as? String, let doubleValue = Double(stringValue) {
            return doubleValue
        }
        return nil
    }

    private static func weightedCardPick(_ candidates: [(type: String, weight: Double)]) -> (type: String, weight: Double) {
        guard !candidates.isEmpty else { return (type: "stop", weight: 1) }
        if candidates.count == 1 { return candidates[0] }

        let totalWeight = candidates.reduce(0.0) { $0 + max(0.0001, $1.weight) }
        if totalWeight <= 0 { return candidates[0] }

        var roll = Double.random(in: 0..<totalWeight)
        for candidate in candidates {
            roll -= max(0.0001, candidate.weight)
            if roll <= 0 {
                return candidate
            }
        }
        return candidates[candidates.count - 1]
    }

    private static func buildCardContent(for cardType: String) -> [String: Any] {
        switch cardType {
        case "timer":
            return [
                "title": "Pick an end hour",
                "subtitle": "Set a stop time and get reminded natively",
                "defaultMinutes": 45,
                "cta": "Start timer"
            ]
        case "book":
            return [
                "title": "Read one useful article",
                "subtitle": "Open in BookReader and come back after",
                "articleTitle": "",
                "lang": "en",
                "cta": "Open article"
            ]
        case "mood":
            return [
                "title": "Quick mood check",
                "subtitle": "Name your current feeling",
                "prompt": "How do you feel right now?"
            ]
        case "metrics":
            return [
                "title": "Session pulse",
                "subtitle": "Pause and look at your current session",
                "cta": "Show stats"
            ]
        case "stop":
            return [
                "title": "Time to stop?",
                "subtitle": "Take a break before another post",
                "cta": "Open dashboard"
            ]
        case "stats":
            return [
                "title": "Your progress",
                "subtitle": "Review your stop-scroll streak",
                "cta": "Open dashboard"
            ]
        case "culture":
            return [
                "title": "Culture break",
                "subtitle": "Answer one question before continuing"
            ]
        default:
            return [:]
        }
    }

    private static func buildCardActions(for cardType: String) -> [String: Any] {
        switch cardType {
        case "timer":
            return [
                "primary": "setTimer",
                "supportsCustomEndHour": true
            ]
        case "book":
            return [
                "primary": "openArticle"
            ]
        case "stop", "stats", "metrics":
            return [
                "primary": "openDashboard"
            ]
        case "culture":
            return [
                "primary": "grantXP"
            ]
        default:
            return [:]
        }
    }
}
