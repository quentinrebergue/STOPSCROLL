import SwiftUI
import WebKit
import UserNotifications

struct InstagramWebView: UIViewRepresentable {
    enum ScriptProfile {
        case full
        case navigationLite
        case searchLite      // Lightweight search-surface scripts that avoid accidental reel lock-in
        case reelsLite       // Hides the native Reels header so the surface is full-screen
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
    var bottomOverlayInset: CGFloat = 0
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

    /// Lightweight search-surface scripts: keep page-management and scroll controls without feed injection.
    static let searchLiteScripts: [String] = [
        "constants",
        "dom-utils",
        "scroll-lock",
        "page-manager",
    ]

    /// Card-builder modules only — no feed scanning, no ad detection, no tracking.
    /// Used by the Reels surface to render the same card types as the main feed.
    static let reelsLiteScripts: [String] = [
        "constants",
        "config",
        "dom-utils",
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
    ]

    /// No scripts for secondary surfaces - prevent unnecessary injection.
    static let noScripts: [String] = []

    private var needsFeedGlobals: Bool {
        scriptProfile == .full || scriptProfile == .reelsLite
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> WKWebView {
        LogManager.shared.log("📱 WebView mounting: profile=\(scriptProfile), initialURL=\(initialURLString)", category: "WebView", level: .info)
        
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        if needsFeedGlobals {
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

            // Expose native-owned timer state to JS.
            config.userContentController.addUserScript(WKUserScript(
                source: buildTimerStateScript(),
                injectionTime: .atDocumentStart,
                forMainFrameOnly: true
            ))
        }

        config.userContentController.addUserScript(WKUserScript(
            source: Self.surfaceLifecycleBridgeScript(),
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

        // Book-reader bridge is only needed on the feed profile (book card action).
        if needsFeedGlobals {
            config.userContentController.add(
                LeakAvoider(delegate: context.coordinator), name: "openBookReader"
            )
        }
        // General bridge: language detection, reload, future events
        config.userContentController.add(
            LeakAvoider(delegate: context.coordinator), name: "stopScrollBridge"
        )

        let webView = WKWebView(frame: .zero, configuration: config)
        context.coordinator.webView = webView
        webView.navigationDelegate = context.coordinator

        // Avoid UIKit input assistant bar layout conflicts (width==0 wrappers)
        // when focusing editable fields inside Instagram's chat composer.
        webView.inputAssistantItem.leadingBarButtonGroups = []
        webView.inputAssistantItem.trailingBarButtonGroups = []

        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.scrollView.contentInset.bottom = bottomOverlayInset
        webView.scrollView.verticalScrollIndicatorInsets.bottom = bottomOverlayInset
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
        context.coordinator.applyRuntimeGovernorIfNeeded()
        if context.coordinator.lastReloadToken != reloadToken {
            context.coordinator.lastReloadToken = reloadToken
            uiView.reload()
        }
        if needsFeedGlobals, context.coordinator.lastLabelsToken != labelsToken {
            context.coordinator.lastLabelsToken = labelsToken
            // Re-inject globals then dispatch a live config command to the JS bridge.
            let reloadScript = buildLabelsInjectionScript() + """
            (function() {
                var ns = window.StopScroll;
                if (ns && ns.bridge && typeof ns.bridge.receive === 'function') {
                    ns.bridge.receive('setLabels', window.__STOPSCROLL_AD_LABELS);
                    ns.bridge.receive('setFrequency', window.__STOPSCROLL_FREQUENCY);
                } else if (ns && ns.runtimeState && ns.runtimeState.applyConfigFromGlobals && ns._state) {
                    ns.runtimeState.applyConfigFromGlobals(ns._state);
                    if (window.__STOPSCROLL_SCHEDULE_SCAN) {
                        window.__STOPSCROLL_SCHEDULE_SCAN();
                    }
                } else if (ns && ns.config && ns.config.loadConfig && ns._state) {
                    ns._state.config = ns.config.loadConfig();
                    if (window.__STOPSCROLL_SCHEDULE_SCAN) {
                        window.__STOPSCROLL_SCHEDULE_SCAN();
                    }
                }
            })();
            """
            uiView.evaluateJavaScript(reloadScript)
            context.coordinator.applyRuntimeGovernorIfNeeded(force: true)
        }
        if context.coordinator.lastThemeRefreshToken != themeRefreshToken {
            context.coordinator.lastThemeRefreshToken = themeRefreshToken
            if isActive {
                uiView.evaluateJavaScript("(function(){var ns=window.StopScroll;if(ns&&ns.dom&&ns.dom.detectTheme){ns.dom.detectTheme();}if(ns&&ns.cardBuilder&&ns.cardBuilder.refreshInjectedCardColors){ns.cardBuilder.refreshInjectedCardColors();}})();")
            }
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
        if uiView.scrollView.contentInset.bottom != bottomOverlayInset {
            uiView.scrollView.contentInset.bottom = bottomOverlayInset
            uiView.scrollView.verticalScrollIndicatorInsets.bottom = bottomOverlayInset
        }
        if context.coordinator.lastIsActive != isActive {
            context.coordinator.lastIsActive = isActive
            LogManager.shared.log("👁️ Surface active state: \(isActive)", category: "WebView", level: .debug)
            context.coordinator.applyRuntimeActiveState(isActive)
        }
        if activeSectionTab == "messages" {
            context.coordinator.logMessagesDiagnosticsIfNeeded()
        }
        if activeSectionTab == "messages" && scriptProfile != .none {
            uiView.evaluateJavaScript(Self.messagingHeaderCleanupScript()) { _, error in
                if let error {
                    LogManager.shared.log(
                        "❌ Messaging cleanup injection failed: \(error.localizedDescription)",
                        category: "ScriptInjection",
                        level: .error
                    )
                } else {
                    LogManager.shared.log(
                        "✅ Messaging cleanup injection applied",
                        category: "ScriptInjection",
                        level: .debug
                    )
                }
            }
        }
    }

}
