import SwiftUI
import WebKit
import UserNotifications

struct InstagramWebView: UIViewRepresentable {
    enum ScriptProfile {
        case full
        case navigationLite
        case reelBlocker     // Blocks reel scrolling but allows viewing shared reels
        case none            // No injection for secondary surfaces
    }

    @Binding var isLoading: Bool
    @Binding var showingReader: Bool
    @Binding var showingSettings: Bool
    @Binding var showingDashboard: Bool
    @Binding var reloadToken: Int
    /// Incremented by InstagramView when AppSettings.adLabels changes; triggers re-injection.
    @Binding var labelsToken: Int
    /// Incremented to force JS-side Instagram background re-detection.
    @Binding var themeRefreshToken: Int
    @Binding var selectedNativeTab: String
    @Binding var nativeMessageBadgeCount: Int
    @Binding var nativeNavCommandToken: Int
    var initialURLString: String = "https://www.instagram.com/"
    var isActive: Bool = true
    var tracksLoading: Bool = true
    var scriptProfile: ScriptProfile = .full
    var handlesInstagramNavigation: Bool = true
    var allowsHorizontalSurfaceSwipe: Bool = false
    var activeSectionTab: String = "home"
    var onHorizontalSurfaceDragChanged: ((CGFloat) -> Void)? = nil
    var onHorizontalSurfaceDragEnded: ((CGFloat, CGFloat) -> Void)? = nil
    var requestedURLString: String? = nil
    var requestedURLToken: Int = 0
    @Binding var instagramThemeIsDark: Bool
    var onGrantXP: (Int, String) -> Void = { _, _ in }

    /// Full runtime scripts injected in dependency order before the bootstrap.
    static let fullModuleScripts: [String] = [
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

    /// Lightweight scripts used by non-feed surfaces (messages/search/profile).
    static let navigationLiteScripts: [String] = [
        "constants",
        "dom-utils",
        "nav-management",
    ]

    /// Reel-blocking scripts for messages/search - prevent scroll to next reel but allow viewing.
    static let reelBlockerScripts: [String] = [
        "constants",
        "dom-utils",
        "scroll-lock",
        "page-manager",
    ]

    /// No scripts for secondary surfaces - prevent unnecessary injection.
    static let noScripts: [String] = []

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> WKWebView {
        LogManager.shared.log("📱 WebView mounting: profile=\(scriptProfile), initialURL=\(initialURLString)", category: "WebView", level: .info)
        
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

        // Inject scripts profile for this surface.
        for script in Self.loadScripts(profile: scriptProfile) {
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
        context.coordinator.installHorizontalPanRecognizer(on: webView)

        if let url = URL(string: initialURLString) {
            webView.load(URLRequest(url: url))
        }
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        context.coordinator.parent = self
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
        if context.coordinator.lastThemeRefreshToken != themeRefreshToken {
            context.coordinator.lastThemeRefreshToken = themeRefreshToken
            uiView.evaluateJavaScript("(function(){var ns=window.StopScroll;if(ns&&ns.dom&&ns.dom.detectTheme){ns.dom.detectTheme();}if(ns&&ns.cardBuilder&&ns.cardBuilder.refreshInjectedCardColors){ns.cardBuilder.refreshInjectedCardColors();}})();")
        }
        if context.coordinator.lastNativeNavCommandToken != nativeNavCommandToken {
            context.coordinator.lastNativeNavCommandToken = nativeNavCommandToken
            context.coordinator.sendNativeNavigationCommand(tab: selectedNativeTab, onlyIfActive: true)
        } else if !context.coordinator.didSendInitialActiveNavCommand, isActive {
            context.coordinator.didSendInitialActiveNavCommand = true
            context.coordinator.sendNativeNavigationCommand(tab: selectedNativeTab, onlyIfActive: true)
        }
        if context.coordinator.lastRequestedURLToken != requestedURLToken {
            context.coordinator.lastRequestedURLToken = requestedURLToken
            if let requestedURLString,
               let requestedURL = URL(string: requestedURLString) {
                let currentURL = uiView.url?.absoluteString ?? ""
                if currentURL != requestedURL.absoluteString {
                    LogManager.shared.log("🌍 Requested URL applied: \(requestedURLString)", category: "WebView", level: .debug)
                    uiView.load(URLRequest(url: requestedURL))
                } else {
                    // Already on the correct URL — no navigation needed, clear loading state.
                    DispatchQueue.main.async {
                        guard self.tracksLoading else { return }
                        withAnimation(.easeOut(duration: 0.3)) {
                            self.isLoading = false
                        }
                    }
                }
            }
        }
        if context.coordinator.lastIsActive != isActive {
            context.coordinator.lastIsActive = isActive
            LogManager.shared.log("👁️ Surface active state: \(isActive)", category: "WebView", level: .debug)
            context.coordinator.applyRuntimeActiveState(isActive)
        }
                if activeSectionTab == "messages" {
                        uiView.evaluateJavaScript("""
                        (function(){
                            try {
                                if (!location.pathname || location.pathname.indexOf('/direct') !== 0) return;
                                var nodes = document.querySelectorAll('header a[href="/direct/inbox/"], header a[href="/direct/inbox"]');
                                for (var i = 0; i < nodes.length; i++) {
                                    nodes[i].style.setProperty('display', 'none', 'important');
                                    nodes[i].style.setProperty('pointer-events', 'none', 'important');
                                }
                            } catch (_) {}
                        })();
                        """)
                }
    }

}
