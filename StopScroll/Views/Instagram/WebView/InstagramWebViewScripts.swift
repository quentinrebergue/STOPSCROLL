import SwiftUI
import WebKit

extension InstagramWebView {

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
        let username = (UserDefaults.standard.string(forKey: "ss_instagram_username") ?? "")
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
        return "window.__STOPSCROLL_AD_LABELS = \(json); window.__STOPSCROLL_FREQUENCY = \(freq); window.__STOPSCROLL_ARTICLE_SOURCES = \(srcJson); window.__STOPSCROLL_DEV_MODE = \(devMode); window.__STOPSCROLL_INSTAGRAM_USERNAME = '\(username)';"
    }

    func buildYAMLInjectionScript() -> String? {
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

    /// Loads scripts for the requested profile.
    static func loadScripts(profile: ScriptProfile) -> [String] {
        let names: [String]
        switch profile {
        case .full:
            names = fullModuleScripts
        case .navigationLite:
            names = navigationLiteScripts
        case .reelBlocker:
            names = reelBlockerScripts
        case .none:
            names = noScripts
        }

        var scripts: [String] = []
        for name in names {
            if let url = Bundle.main.url(forResource: name, withExtension: "js"),
               let src = try? String(contentsOf: url, encoding: .utf8) {
                scripts.append(src)
            }
        }
        if profile == .full {
            // Full bootstrap entry point – must come last.
            if let url = Bundle.main.url(forResource: "block_reels", withExtension: "js"),
               let src = try? String(contentsOf: url, encoding: .utf8) {
                scripts.append(src)
            }
        } else if profile == .navigationLite {
            scripts.append(navigationSyncBootstrapScript())
        }
        // .none profile: no bootstrap needed
        return scripts
    }

    private static func navigationSyncBootstrapScript() -> String {
        """
        (function(){
            if (window.__STOPSCROLL_NAV_LITE_RUNNING) return;
            window.__STOPSCROLL_NAV_LITE_RUNNING = true;
            var tick = function(){
                var ns = window.StopScroll;
                if (ns && ns.nav && ns.nav.syncNativeNavState) {
                    ns.nav.syncNativeNavState();
                }
                if (ns && ns.dom && ns.dom.detectTheme) {
                    ns.dom.detectTheme();
                }
            };
            tick();
            window.addEventListener('popstate', tick);
            document.addEventListener('visibilitychange', function(){ if (!document.hidden) tick(); });
            window.__STOPSCROLL_NAV_LITE_TIMER = setInterval(tick, 1200);
        })();
        """
    }


}
