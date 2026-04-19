import SwiftUI
import UIKit

struct InstagramView: View {

    @State private var isLoadingMain = true
    @State private var isLoadingMessages = true
    @State private var isLoadingSearch = true
    @State private var isLoadingProfile = true
    @State private var showingReader = false
    @State private var reloadToken = 0
    @State private var showingSettings = false
    @State private var showingDashboard = false
    @State private var returnToDashboardAfterSettings = false
    /// Incremented when the user closes Settings so the WebView re-injects the updated label list.
    @State private var labelsToken = 0
    @AppStorage("ss_xp_total") private var totalXP = 0
    @State private var xpIslandVisible = false
    @State private var xpLastGain = 0
    @State private var xpHideWorkItem: DispatchWorkItem?
    @State private var xpProgressWorkItem: DispatchWorkItem?
    @State private var xpInfoWorkItem: DispatchWorkItem?
    @State private var xpIslandNudge: CGFloat = 0
    @State private var xpDisplayedProgress: Double = 0
    @State private var xpInfoPhase: XPInfoPhase = .gain
    @State private var nativeSelectedTab: String = "home"
    @State private var nativeMessageBadgeCount: Int = 0
    @State private var nativeNavCommandToken: Int = 0
    @State private var messagesNavigationURL: String? = nil
    @State private var messagesNavigationToken: Int = 0
    @State private var searchNavigationURL: String? = nil
    @State private var searchNavigationToken: Int = 0
    @State private var profileNavigationURL: String? = nil
    @State private var profileNavigationToken: Int = 0
    @State private var showControlCenterChooser = false
    @State private var activeSurface: WebSurface = .main
    @State private var hasMainSurface = true
    @State private var hasMessagesSurface = false
    @State private var hasSearchSurface = false
    @State private var hasProfileSurface = false
    @AppStorage("ss_instagram_username") private var instagramUsername = ""
    @AppStorage("ss_webview_count") private var webViewCount = 2
    @State private var showInstagramUsernamePrompt = false
    @State private var instagramUsernameDraft = ""
    @AppStorage("ss_instagram_theme_dark") private var instagramThemeIsDark = true

    private var isActiveSurfaceLoading: Bool {
        switch activeSurface {
        case .main: return isLoadingMain
        case .messages: return isLoadingMessages
        case .search: return isLoadingSearch
        case .profile: return isLoadingProfile
        }
    }

    private var normalizedWebViewCount: Int {
        min(max(webViewCount, 1), 4)
    }

    private let webViewBottomOverscan: CGFloat = 116
    private let sharedBottomNavReservedHeight: CGFloat = 92

    private var instagramSurfaceColor: Color {
        instagramThemeIsDark ? .black : .white
    }

    var body: some View {
        ZStack {
            if hasMainSurface {
                InstagramWebView(
                    isLoading: $isLoadingMain,
                    showingReader: $showingReader,
                    showingSettings: $showingSettings,
                    showingDashboard: $showingDashboard,
                    reloadToken: $reloadToken,
                    labelsToken: $labelsToken,
                    selectedNativeTab: $nativeSelectedTab,
                    nativeMessageBadgeCount: $nativeMessageBadgeCount,
                    nativeNavCommandToken: $nativeNavCommandToken,
                    initialURLString: "https://www.instagram.com/",
                    isActive: activeSurface == .main,
                    tracksLoading: true,
                    scriptProfile: .full,
                    handlesInstagramNavigation: normalizedWebViewCount == 1,
                    requestedURLString: nil,
                    requestedURLToken: 0,
                    instagramThemeIsDark: $instagramThemeIsDark,
                    onGrantXP: { amount, source in
                        grantXP(amount: amount, source: source)
                    }
                )
                // Extend the webview below the bottom edge so Instagram's bottom nav
                // stays outside of the visible area behind our native bar.
                .padding(.bottom, -webViewBottomOverscan)
                .ignoresSafeArea(edges: .bottom)
                .opacity(activeSurface == .main && !showingReader && !showingDashboard ? 1 : 0)
                .allowsHitTesting(activeSurface == .main && !showingReader && !showingDashboard)
                .id("surface-main")
            }

            if normalizedWebViewCount >= 2 && hasMessagesSurface {
                InstagramWebView(
                    isLoading: $isLoadingMessages,
                    showingReader: $showingReader,
                    showingSettings: $showingSettings,
                    showingDashboard: $showingDashboard,
                    reloadToken: $reloadToken,
                    labelsToken: $labelsToken,
                    selectedNativeTab: $nativeSelectedTab,
                    nativeMessageBadgeCount: $nativeMessageBadgeCount,
                    nativeNavCommandToken: $nativeNavCommandToken,
                    initialURLString: "https://www.instagram.com/direct/inbox/",
                    isActive: activeSurface == .messages,
                    tracksLoading: true,
                    scriptProfile: .reelBlocker,
                    handlesInstagramNavigation: true,
                    requestedURLString: messagesNavigationURL,
                    requestedURLToken: messagesNavigationToken,
                    instagramThemeIsDark: $instagramThemeIsDark,
                    onGrantXP: { amount, source in
                        grantXP(amount: amount, source: source)
                    }
                )
                .padding(.bottom, -webViewBottomOverscan)
                .ignoresSafeArea(edges: .bottom)
                .opacity(activeSurface == .messages && !showingReader && !showingDashboard ? 1 : 0)
                .allowsHitTesting(activeSurface == .messages && !showingReader && !showingDashboard)
                .id("surface-messages")
            }

            if normalizedWebViewCount >= 3 && hasSearchSurface {
                InstagramWebView(
                    isLoading: $isLoadingSearch,
                    showingReader: $showingReader,
                    showingSettings: $showingSettings,
                    showingDashboard: $showingDashboard,
                    reloadToken: $reloadToken,
                    labelsToken: $labelsToken,
                    selectedNativeTab: $nativeSelectedTab,
                    nativeMessageBadgeCount: $nativeMessageBadgeCount,
                    nativeNavCommandToken: $nativeNavCommandToken,
                    initialURLString: "https://www.instagram.com/explore/",
                    isActive: activeSurface == .search,
                    tracksLoading: true,
                    scriptProfile: .reelBlocker,
                    handlesInstagramNavigation: true,
                    requestedURLString: searchNavigationURL,
                    requestedURLToken: searchNavigationToken,
                    instagramThemeIsDark: $instagramThemeIsDark,
                    onGrantXP: { amount, source in
                        grantXP(amount: amount, source: source)
                    }
                )
                .padding(.bottom, -webViewBottomOverscan)
                .ignoresSafeArea(edges: .bottom)
                .opacity(activeSurface == .search && !showingReader && !showingDashboard ? 1 : 0)
                .allowsHitTesting(activeSurface == .search && !showingReader && !showingDashboard)
                .id("surface-search")
            }

            if normalizedWebViewCount == 4 && hasProfileSurface {
                InstagramWebView(
                    isLoading: $isLoadingProfile,
                    showingReader: $showingReader,
                    showingSettings: $showingSettings,
                    showingDashboard: $showingDashboard,
                    reloadToken: $reloadToken,
                    labelsToken: $labelsToken,
                    selectedNativeTab: $nativeSelectedTab,
                    nativeMessageBadgeCount: $nativeMessageBadgeCount,
                    nativeNavCommandToken: $nativeNavCommandToken,
                    initialURLString: "https://www.instagram.com/",
                    isActive: activeSurface == .profile,
                    tracksLoading: true,
                    scriptProfile: .none,
                    handlesInstagramNavigation: true,
                    requestedURLString: profileNavigationURL,
                    requestedURLToken: profileNavigationToken,
                    instagramThemeIsDark: $instagramThemeIsDark,
                    onGrantXP: { amount, source in
                        grantXP(amount: amount, source: source)
                    }
                )
                .padding(.bottom, -webViewBottomOverscan)
                .ignoresSafeArea(edges: .bottom)
                .opacity(activeSurface == .profile && !showingReader && !showingDashboard ? 1 : 0)
                .allowsHitTesting(activeSurface == .profile && !showingReader && !showingDashboard)
                .id("surface-profile")
            }

            BookReaderView(onDismiss: { showingReader = false }, bottomInset: sharedBottomNavReservedHeight)
                .opacity(showingReader ? 1 : 0)
                .allowsHitTesting(showingReader)
                .ignoresSafeArea(edges: .bottom)

            DashboardView(onDismiss: {
                showingDashboard = false
            }, onOpenSettings: {
                returnToDashboardAfterSettings = true
                showingDashboard = false
                DispatchQueue.main.async {
                    showingSettings = true
                }
            })
            .opacity(showingDashboard ? 1 : 0)
            .allowsHitTesting(showingDashboard)
            .ignoresSafeArea(edges: .bottom)
            .zIndex(12)

            GeometryReader { geo in
                instagramSurfaceColor
                    .frame(height: geo.safeAreaInsets.top)
                    .ignoresSafeArea(edges: .top)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .allowsHitTesting(false)
            .zIndex(5)

            if isActiveSurfaceLoading && !showingReader && !showingDashboard {
                VStack(spacing: 0) {
                    LoadingBar()
                    Spacer()
                }
                .background(instagramSurfaceColor.ignoresSafeArea())
                .transition(.opacity)
            }

            if xpIslandVisible {
                GeometryReader { geo in
                    let cutoutStyle = XPCutoutStyle.from(topInset: geo.safeAreaInsets.top)
                    let cutoutTopOffset: CGFloat = cutoutStyle == .dynamicIsland ? 4 : 6

                    VStack(spacing: 0) {
                        XPCutoutAnchorView(style: cutoutStyle)

                        XPDynamicIslandView(
                            gain: xpLastGain,
                            level: XPProgress.level(for: totalXP),
                            progress: xpDisplayedProgress,
                            currentXPInLevel: XPProgress.xpInCurrentLevel(for: totalXP),
                            xpPerLevel: XPProgress.xpPerLevel,
                            infoPhase: xpInfoPhase
                        )
                        .padding(.top, 2)
                        .scaleEffect(1 + xpIslandNudge, anchor: .top)
                        .offset(y: xpIslandNudge * -3)

                        Spacer(minLength: 0)
                    }
                    .padding(.top, cutoutTopOffset)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .compositingGroup()
                }
                .ignoresSafeArea(edges: .top)
                .transition(.xpIslandOrganic)
                .zIndex(20)
                .allowsHitTesting(false)
            }

            VStack(spacing: 0) {
                Spacer()
                NativeInstagramTabBar(
                    selectedTab: nativeSelectedTab,
                    messageBadgeCount: nativeMessageBadgeCount,
                    onSelectTab: { tab in
                        // Any tab switch away from dashboard should reveal the target page.
                        if tab != "dashboard" {
                            showingDashboard = false
                        }
                        if tab == "book" {
                            showingReader = true
                            nativeSelectedTab = "book"
                            return
                        }
                        if tab == "dashboard" {
                            showingDashboard = true
                            nativeSelectedTab = "dashboard"
                            return
                        }
                        if tab == "home" || tab == "messages" || tab == "search" || tab == "profile" {
                            showingReader = false
                            openInstagramTab(tab)
                            return
                        }
                    }
                )
            }
            .ignoresSafeArea(edges: .bottom)
            .zIndex(15)
        }
        .background(instagramSurfaceColor.ignoresSafeArea())
        .fullScreenCover(isPresented: $showingSettings) {
            SettingsView(onDismiss: {
                showingSettings = false
                labelsToken += 1  // triggers label re-injection into the live WebView
                if returnToDashboardAfterSettings {
                    returnToDashboardAfterSettings = false
                    DispatchQueue.main.async {
                        showingDashboard = true
                        nativeSelectedTab = "dashboard"
                    }
                }
            }, onOpenDashboard: {
                returnToDashboardAfterSettings = false
                showingSettings = false
                showingDashboard = true
            })
        }
        .confirmationDialog("StopScroll", isPresented: $showControlCenterChooser, titleVisibility: .visible) {
            Button("Dashboard") {
                showingDashboard = true
            }
            Button("Parametres") {
                returnToDashboardAfterSettings = false
                showingSettings = true
            }
            Button("Cancel", role: .cancel) {}
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)) { _ in
            evictInactiveSurface()
        }
        .sheet(isPresented: $showInstagramUsernamePrompt) {
            InstagramUsernamePromptSheet(
                username: $instagramUsernameDraft,
                onCancel: {
                    showInstagramUsernamePrompt = false
                },
                onConfirm: {
                    let cleaned = instagramUsernameDraft
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .replacingOccurrences(of: "@", with: "")
                    guard !cleaned.isEmpty else { return }
                    instagramUsername = cleaned
                    labelsToken += 1
                    showInstagramUsernamePrompt = false
                    openInstagramTab("profile")
                }
            )
        }
        .onChange(of: instagramUsername) { _ in
            labelsToken += 1
        }
        .onChange(of: webViewCount) { newValue in
            let clamped = min(max(newValue, 1), 4)
            if clamped != newValue {
                webViewCount = clamped
            }
            reconfigureSurfacesForCurrentMode()
        }
        .onAppear {
            reconfigureSurfacesForCurrentMode()
        }
    }

    private func openInstagramTab(_ tab: String) {
        LogManager.shared.log("🔗 Tab selected: \(tab), mode: \(normalizedWebViewCount), surface: \(surfaceFor(tab: tab))", category: "Navigation", level: .info)
        
        if tab == "home" {
            ensureSurfaceAvailable(.main)
            activeSurface = .main
            nativeSelectedTab = "home"
            LogManager.shared.log("→ Home: activeSurface = main", category: "Navigation", level: .debug)
            return
        }

        if normalizedWebViewCount == 1 {
            ensureSurfaceAvailable(.main)
            activeSurface = .main
            nativeSelectedTab = tab
            nativeNavCommandToken += 1
            LogManager.shared.log("→ Mode 1: all tabs on main surface", category: "Navigation", level: .debug)
            return
        }

        if tab == "profile" && instagramUsername.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            instagramUsernameDraft = ""
            showInstagramUsernamePrompt = true
            LogManager.shared.log("⚠️ Profile tab: no username set, prompting", category: "Navigation", level: .warning)
            return
        }

        guard let targetURL = InstagramSecondaryRoute.url(for: tab, username: instagramUsername) else {
            LogManager.shared.log("❌ Failed to generate URL for tab: \(tab)", category: "Navigation", level: .error)
            return
        }

        let targetSurface = surfaceFor(tab: tab)
        ensureSurfaceAvailable(targetSurface)
        activeSurface = targetSurface
        nativeSelectedTab = tab
        LogManager.shared.log("→ Target surface: \(targetSurface), URL: \(targetURL)", category: "Navigation", level: .debug)

        switch targetSurface {
        case .main:
            break
        case .messages:
            isLoadingMessages = true
            messagesNavigationURL = targetURL
            messagesNavigationToken += 1
            LogManager.shared.log("→ Messages: loading started", category: "Navigation", level: .debug)
        case .search:
            isLoadingSearch = true
            searchNavigationURL = targetURL
            searchNavigationToken += 1
            LogManager.shared.log("→ Search: loading started", category: "Navigation", level: .debug)
        case .profile:
            isLoadingProfile = true
            profileNavigationURL = targetURL
            profileNavigationToken += 1
            LogManager.shared.log("→ Profile: loading started", category: "Navigation", level: .debug)
        }
    }

    private func surfaceFor(tab: String) -> WebSurface {
        SurfaceRouter.surface(for: tab, webViewCount: normalizedWebViewCount)
    }

    private func ensureSurfaceAvailable(_ surface: WebSurface) {
        switch surface {
        case .main:
            if !hasMainSurface {
                hasMainSurface = true
                isLoadingMain = true
            }
        case .messages:
            if !hasMessagesSurface {
                hasMessagesSurface = true
                isLoadingMessages = true
            }
        case .search:
            if !hasSearchSurface {
                hasSearchSurface = true
                isLoadingSearch = true
            }
        case .profile:
            if !hasProfileSurface {
                hasProfileSurface = true
                isLoadingProfile = true
            }
        }
    }

    private func reconfigureSurfacesForCurrentMode() {
        LogManager.shared.log("🔄 Reconfiguring surfaces for mode \(normalizedWebViewCount)", category: "Routing", level: .info)
        
        activeSurface = surfaceFor(tab: nativeSelectedTab)

        // Lazy mode: keep only the active surface mounted after config changes.
        hasMainSurface = false
        hasMessagesSurface = false
        hasSearchSurface = false
        hasProfileSurface = false

        ensureSurfaceAvailable(activeSurface)

        if normalizedWebViewCount < 2 {
            hasMessagesSurface = false
        }
        if normalizedWebViewCount < 3 {
            hasSearchSurface = false
        }
        if normalizedWebViewCount < 4 {
            hasProfileSurface = false
        }
    }

    private func evictInactiveSurface() {
        if normalizedWebViewCount < 2 {
            return
        }

        if activeSurface != .main {
            hasMainSurface = false
            isLoadingMain = true
        }
        if normalizedWebViewCount >= 2, activeSurface != .messages {
            hasMessagesSurface = false
            isLoadingMessages = true
        }
        if normalizedWebViewCount >= 3, activeSurface != .search {
            hasSearchSurface = false
            isLoadingSearch = true
        }
        if normalizedWebViewCount == 4, activeSurface != .profile {
            hasProfileSurface = false
            isLoadingProfile = true
        }
    }

    private func grantXP(amount: Int, source: String) {
        let progressStartDelayWhenVisible = 0.16
        let progressStartDelayOnAppear = 0.22
        let safeAmount = min(max(amount, 1), 200)
        let previousTotal = totalXP
        totalXP += safeAmount
        let targetProgress = XPProgress.progress(for: totalXP)
        xpLastGain = safeAmount
        _ = source // reserved for future reward categories
        xpInfoPhase = .gain

        xpHideWorkItem?.cancel()
        xpProgressWorkItem?.cancel()
        xpInfoWorkItem?.cancel()

        if xpIslandVisible {
            withAnimation(.interactiveSpring(response: 0.32, dampingFraction: 0.74, blendDuration: 0.16)) {
                xpIslandNudge = 0.045
            }
            withAnimation(.easeOut(duration: 0.28).delay(0.05)) {
                xpIslandNudge = 0
            }
            // Island already visible: animate from previous level ratio to target ratio.
            xpDisplayedProgress = XPProgress.progress(for: previousTotal)
            let progressItem = DispatchWorkItem {
                withAnimation(.easeOut(duration: 0.42)) {
                    xpDisplayedProgress = targetProgress
                }
            }
            xpProgressWorkItem = progressItem
            DispatchQueue.main.asyncAfter(deadline: .now() + progressStartDelayWhenVisible, execute: progressItem)
        } else {
            // Show the current ratio immediately, then animate only the gained progression.
            xpDisplayedProgress = XPProgress.progress(for: previousTotal)
            withAnimation(.interactiveSpring(response: 0.56, dampingFraction: 0.82, blendDuration: 0.2)) {
                xpIslandVisible = true
            }

            let progressItem = DispatchWorkItem {
                withAnimation(.easeOut(duration: 0.48)) {
                    xpDisplayedProgress = targetProgress
                }
            }
            xpProgressWorkItem = progressItem
            DispatchQueue.main.asyncAfter(deadline: .now() + progressStartDelayOnAppear, execute: progressItem)
        }

        // Minimal timeline: quick gain text, then current/required XP ratio.
        let infoItem = DispatchWorkItem {
            withAnimation(.easeOut(duration: 0.2)) {
                xpInfoPhase = .progress
            }
        }
        xpInfoWorkItem = infoItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.72, execute: infoItem)

        let workItem = DispatchWorkItem {
            withAnimation(.easeOut(duration: 0.34)) {
                xpIslandVisible = false
            }
        }
        xpHideWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.15, execute: workItem)
    }
}

