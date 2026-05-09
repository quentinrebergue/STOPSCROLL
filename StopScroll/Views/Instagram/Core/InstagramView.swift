import SwiftUI
import UIKit

struct InstagramView: View {

    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var sessionLimiter = SessionLimitManager.shared

    @State var isLoadingMain = true
    @State var isLoadingMessages = true
    @State var isLoadingSearch = true
    @State var isLoadingReels = true
    @State var isLoadingProfile = true
    @State var showingReader = false
    @State var reloadTokenMain = 0
    @State var reloadTokenMessages = 0
    @State var reloadTokenSearch = 0
    @State var reloadTokenReels = 0
    @State var reloadTokenProfile = 0
    @State var showingSettings = false
    @State var showingDashboard = false
    @State var profileMode: NativeInstagramTabBar.ProfileMode = .instagram
    /// Incremented when the user closes Settings so the WebView re-injects the updated label list.
    @State var labelsToken = 0
    @AppStorage("ss_xp_total") var totalXP = 0
    @State var xpIslandVisible = false
    @State var xpLastGain = 0
    @State var xpHideWorkItem: DispatchWorkItem?
    @State var xpProgressWorkItem: DispatchWorkItem?
    @State var xpInfoWorkItem: DispatchWorkItem?
    @State var xpIslandNudge: CGFloat = 0
    @State var xpDisplayedProgress: Double = 0
    @State var xpInfoPhase: XPInfoPhase = .gain
    @State var nativeSelectedTab: String = "home"
    @State var nativeMessageBadgeCount: Int = 0
    @State var nativeNavCommandToken: Int = 0
    @State var messagesNavigationURL: String? = nil
    @State var messagesNavigationToken: Int = 0
    @State var searchNavigationURL: String? = nil
    @State var searchNavigationToken: Int = 0
    @State var reelsNavigationURL: String? = nil
    @State var reelsNavigationToken: Int = 0
    @State var profileNavigationURL: String? = nil
    @State var profileNavigationToken: Int = 0
    @State var showControlCenterChooser = false
    @State var activeSurface: WebSurface = .main
    @State var hasMainSurface = true
    @State var hasMessagesSurface = false
    @State var hasSearchSurface = false
    @State var hasReelsSurface = false
    @State var hasProfileSurface = false
    @AppStorage("ss_instagram_username") var instagramUsername = ""
    @State var showInstagramUsernamePrompt = false
    @State var instagramUsernameDraft = ""
    @AppStorage("ss_instagram_theme_dark") var instagramThemeIsDark = true
    @State var themeRefreshToken = 0
    @State private var lastObservedInjectionFrequency = AppSettings.shared.injectionFrequency
    @State var pendingLazyReloadSurfaces: Set<WebSurface> = []
    @State private var lastObservedLazyWebViewRefreshToken = AppSettings.shared.lazyWebViewRefreshToken
    @State var sectionSwipeTranslation: CGFloat = 0
    @State var sectionSwipeTargetTab: String? = nil
    @State var showingBookReaderSettings = false
    @State var sessionBannerVisible = false
    @State var sessionBannerWorkItem: DispatchWorkItem?

    var isActiveSurfaceLoading: Bool {
        switch activeSurface {
        case .main: return isLoadingMain
        case .messages: return isLoadingMessages
        case .search: return isLoadingSearch
        case .reels: return isLoadingReels
        case .profile: return isLoadingProfile
        }
    }

    let normalizedWebViewCount = 5

    let webViewBottomOverscan: CGFloat = 116
    let webViewTopInset: CGFloat = 0.17
    let sharedBottomNavReservedHeight: CGFloat = 92
    let messagesBottomReservedHeight: CGFloat = 62

    var currentSectionTab: String {
        VisibleSectionPolicy.currentTab(
            showingReader: showingReader,
            showingDashboard: showingDashboard,
            nativeSelectedTab: nativeSelectedTab,
            activeSurface: activeSurface
        )
    }

    var sectionPageWidth: CGFloat {
        UIScreen.main.bounds.width
    }

    var instagramSurfaceColor: Color {
        if let rgba = settings.instagramBackgroundRGBA {
            return Color(
                .sRGB,
                red: max(0, min(255, rgba.red)) / 255.0,
                green: max(0, min(255, rgba.green)) / 255.0,
                blue: max(0, min(255, rgba.blue)) / 255.0,
                opacity: max(0, min(1, rgba.alpha))
            )
        }
        return instagramThemeIsDark ? .black : .white
    }

    var body: some View {
        ZStack {
            if hasMainSurface {
                GeometryReader { geo in
                    InstagramWebView(
                        isLoading: $isLoadingMain,
                        showingReader: $showingReader,
                        showingSettings: $showingSettings,
                        showingDashboard: $showingDashboard,
                        reloadToken: $reloadTokenMain,
                        labelsToken: $labelsToken,
                        themeRefreshToken: $themeRefreshToken,
                        selectedNativeTab: $nativeSelectedTab,
                        nativeMessageBadgeCount: $nativeMessageBadgeCount,
                        nativeNavCommandToken: $nativeNavCommandToken,
                        initialURLString: "https://www.instagram.com/",
                        isActive: currentSectionTab == "home" && activeSurface == .main,
                        tracksLoading: true,
                        scriptProfile: .full,
                        handlesInstagramNavigation: true,
                        allowsHorizontalSurfaceSwipe: !showingSettings,
                        bottomOverlayInset: 0,
                        activeSectionTab: currentSectionTab,
                        onHorizontalSurfaceDragChanged: handleHorizontalSurfaceDragChanged,
                        onHorizontalSurfaceDragEnded: handleHorizontalSurfaceDragEnded,
                        requestedURLString: nil,
                        requestedURLToken: 0,
                        instagramThemeIsDark: $instagramThemeIsDark,
                        onGrantXP: { amount, source in
                            grantXP(amount: amount, source: source)
                        }
                    )
                    // Extend the webview below the bottom edge so Instagram's bottom nav
                    // stays outside of the visible area behind our native bar.
                    .padding(.bottom, -WebViewLayoutPolicy.bottomOverscan(for: .main, defaultOverscan: webViewBottomOverscan))
                    .ignoresSafeArea(edges: [.top, .bottom])
                    .padding(.top, webViewTopInset)
                    .offset(x: sectionOffset(for: "home"))
                    .opacity(sectionOpacity(for: "home"))
                    .allowsHitTesting(isInteractiveSection("home"))
                    .id("surface-main")
                }
            }

            if hasMessagesSurface {
                GeometryReader { geo in
                    InstagramWebView(
                        isLoading: $isLoadingMessages,
                        showingReader: $showingReader,
                        showingSettings: $showingSettings,
                        showingDashboard: $showingDashboard,
                        reloadToken: $reloadTokenMessages,
                        labelsToken: $labelsToken,
                        themeRefreshToken: $themeRefreshToken,
                        selectedNativeTab: $nativeSelectedTab,
                        nativeMessageBadgeCount: $nativeMessageBadgeCount,
                        nativeNavCommandToken: $nativeNavCommandToken,
                        initialURLString: "https://www.instagram.com/direct/inbox/",
                        isActive: currentSectionTab == "messages" && activeSurface == .messages,
                        tracksLoading: true,
                        scriptProfile: .none,
                        handlesInstagramNavigation: true,
                        allowsHorizontalSurfaceSwipe: !showingSettings,
                        bottomOverlayInset: 0,
                        activeSectionTab: currentSectionTab,
                        onHorizontalSurfaceDragChanged: handleHorizontalSurfaceDragChanged,
                        onHorizontalSurfaceDragEnded: handleHorizontalSurfaceDragEnded,
                        requestedURLString: messagesNavigationURL,
                        requestedURLToken: messagesNavigationToken,
                        instagramThemeIsDark: $instagramThemeIsDark,
                        onGrantXP: { amount, source in
                            grantXP(amount: amount, source: source)
                        }
                    )
                    .frame(
                        width: geo.size.width,
                        height: max(0, geo.size.height - messagesBottomReservedHeight),
                        alignment: .top
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(.top, webViewTopInset)
                    .clipped()
                    .overlay(alignment: .bottom) {
                        instagramSurfaceColor
                            .frame(height: messagesBottomReservedHeight)
                            .allowsHitTesting(false)
                    }
                }
                .offset(x: sectionOffset(for: "messages"))
                .opacity(sectionOpacity(for: "messages"))
                .allowsHitTesting(isInteractiveSection("messages"))
                .id("surface-messages")
            }

            if hasSearchSurface {
                GeometryReader { geo in
                    InstagramWebView(
                        isLoading: $isLoadingSearch,
                        showingReader: $showingReader,
                        showingSettings: $showingSettings,
                        showingDashboard: $showingDashboard,
                        reloadToken: $reloadTokenSearch,
                        labelsToken: $labelsToken,
                        themeRefreshToken: $themeRefreshToken,
                        selectedNativeTab: $nativeSelectedTab,
                        nativeMessageBadgeCount: $nativeMessageBadgeCount,
                        nativeNavCommandToken: $nativeNavCommandToken,
                        initialURLString: "https://www.instagram.com/explore/",
                        isActive: currentSectionTab == "search" && activeSurface == .search,
                        tracksLoading: true,
                        scriptProfile: .searchLite,
                        handlesInstagramNavigation: true,
                        allowsHorizontalSurfaceSwipe: !showingSettings,
                        bottomOverlayInset: 0,
                        activeSectionTab: currentSectionTab,
                        onHorizontalSurfaceDragChanged: handleHorizontalSurfaceDragChanged,
                        onHorizontalSurfaceDragEnded: handleHorizontalSurfaceDragEnded,
                        requestedURLString: searchNavigationURL,
                        requestedURLToken: searchNavigationToken,
                        instagramThemeIsDark: $instagramThemeIsDark,
                        onGrantXP: { amount, source in
                            grantXP(amount: amount, source: source)
                        }
                    )
                    .padding(.bottom, -WebViewLayoutPolicy.bottomOverscan(for: .search, defaultOverscan: webViewBottomOverscan))
                    .ignoresSafeArea(edges: [.top, .bottom])
                    .padding(.top, webViewTopInset)
                    .offset(x: sectionOffset(for: "search"))
                    .opacity(sectionOpacity(for: "search"))
                    .allowsHitTesting(isInteractiveSection("search"))
                    .id("surface-search")
                }
            }

            if hasReelsSurface {
                GeometryReader { geo in
                    InstagramWebView(
                        isLoading: $isLoadingReels,
                        showingReader: $showingReader,
                        showingSettings: $showingSettings,
                        showingDashboard: $showingDashboard,
                        reloadToken: $reloadTokenReels,
                        labelsToken: $labelsToken,
                        themeRefreshToken: $themeRefreshToken,
                        selectedNativeTab: $nativeSelectedTab,
                        nativeMessageBadgeCount: $nativeMessageBadgeCount,
                        nativeNavCommandToken: $nativeNavCommandToken,
                        initialURLString: "https://www.instagram.com/reels/",
                        isActive: currentSectionTab == "reels" && activeSurface == .reels,
                        tracksLoading: true,
                        scriptProfile: .reelsLite,
                        handlesInstagramNavigation: true,
                        allowsHorizontalSurfaceSwipe: !showingSettings,
                        bottomOverlayInset: 0,
                        activeSectionTab: currentSectionTab,
                        onHorizontalSurfaceDragChanged: handleHorizontalSurfaceDragChanged,
                        onHorizontalSurfaceDragEnded: handleHorizontalSurfaceDragEnded,
                        requestedURLString: reelsNavigationURL,
                        requestedURLToken: reelsNavigationToken,
                        instagramThemeIsDark: $instagramThemeIsDark,
                        onGrantXP: { amount, source in
                            grantXP(amount: amount, source: source)
                        }
                    )
                    .padding(.bottom, -WebViewLayoutPolicy.bottomOverscan(for: .reels, defaultOverscan: webViewBottomOverscan))
                    .ignoresSafeArea(edges: [.top, .bottom])
                    .padding(.top, 0)
                    .offset(x: sectionOffset(for: "reels"))
                    .opacity(sectionOpacity(for: "reels"))
                    .allowsHitTesting(isInteractiveSection("reels"))
                    .id("surface-reels")
                }
            }

            if hasProfileSurface {
                GeometryReader { geo in
                    InstagramWebView(
                        isLoading: $isLoadingProfile,
                        showingReader: $showingReader,
                        showingSettings: $showingSettings,
                        showingDashboard: $showingDashboard,
                        reloadToken: $reloadTokenProfile,
                        labelsToken: $labelsToken,
                        themeRefreshToken: $themeRefreshToken,
                        selectedNativeTab: $nativeSelectedTab,
                        nativeMessageBadgeCount: $nativeMessageBadgeCount,
                        nativeNavCommandToken: $nativeNavCommandToken,
                        initialURLString: "https://www.instagram.com/",
                        isActive: currentSectionTab == "profile" && activeSurface == .profile,
                        tracksLoading: true,
                        scriptProfile: .navigationLite,
                        handlesInstagramNavigation: true,
                        allowsHorizontalSurfaceSwipe: !showingSettings,
                        bottomOverlayInset: 0,
                        activeSectionTab: currentSectionTab,
                        onHorizontalSurfaceDragChanged: handleHorizontalSurfaceDragChanged,
                        onHorizontalSurfaceDragEnded: handleHorizontalSurfaceDragEnded,
                        requestedURLString: profileNavigationURL,
                        requestedURLToken: profileNavigationToken,
                        instagramThemeIsDark: $instagramThemeIsDark,
                        onGrantXP: { amount, source in
                            grantXP(amount: amount, source: source)
                        }
                    )
                    .padding(.bottom, -WebViewLayoutPolicy.bottomOverscan(for: .profile, defaultOverscan: webViewBottomOverscan))
                    .ignoresSafeArea(edges: [.top, .bottom])
                    .padding(.top, webViewTopInset)
                    .offset(x: sectionOffset(for: "profile"))
                    .opacity(sectionOpacity(for: "profile"))
                    .allowsHitTesting(isInteractiveSection("profile"))
                    .id("surface-profile")
                }
            }

            BookReaderView(onDismiss: {
                showingReader = false
                showingBookReaderSettings = false
                nativeSelectedTab = SurfaceRouter.tab(for: activeSurface)
            },
            bottomInset: sharedBottomNavReservedHeight,
            onSettingsVisibilityChanged: { isVisible in
                showingBookReaderSettings = isVisible
            })
                .offset(x: sectionOffset(for: "book"))
                .opacity(sectionOpacity(for: "book"))
                .allowsHitTesting(isInteractiveSection("book"))
                .ignoresSafeArea(edges: .bottom)
                .simultaneousGesture(horizontalSectionDragGesture(enabledFor: "book"))

            DashboardView(onDismiss: {
                showingDashboard = false
                let resumedTab = SurfaceRouter.tab(for: activeSurface)
                nativeSelectedTab = resumedTab
                if resumedTab == "profile" {
                    profileMode = .instagram
                }
            }, onOpenSettings: {
                // Show settings first to avoid one-frame feed flash.
                showingSettings = true
                showingDashboard = false
                profileMode = .stopScroll
            }, showsToolbarButton: isInteractiveSection("dashboard"))
            .offset(x: sectionOffset(for: "dashboard"))
            .opacity(sectionOpacity(for: "dashboard"))
            .allowsHitTesting(isInteractiveSection("dashboard"))
            .ignoresSafeArea(edges: .bottom)
            .zIndex(12)
            .simultaneousGesture(horizontalSectionDragGesture(enabledFor: "dashboard"))

            SettingsView(onDismiss: {
                showingSettings = false
                labelsToken += 1
            }, onOpenDashboard: {
                showingSettings = false
                showingDashboard = true
                profileMode = .stopScroll
                nativeSelectedTab = "profile"
            }, showsToolbarButton: showingSettings)
            .opacity(showingSettings ? 1 : 0)
            .allowsHitTesting(showingSettings)
            .ignoresSafeArea(edges: .bottom)
            .zIndex(13)

            TimerLockView()
                .opacity(currentSectionTab == "timer" ? 1 : 0)
                .allowsHitTesting(currentSectionTab == "timer")
                .ignoresSafeArea(edges: .bottom)
                .zIndex(11)

            if isActiveSurfaceLoading && !showingReader && !showingDashboard && !showingSettings {
                VStack(spacing: 0) {
                    LoadingBar()
                    WebViewSkeletonView(surface: activeSurface, isDark: instagramThemeIsDark)
                }
                .background(instagramSurfaceColor.ignoresSafeArea())
                .transition(.opacity)
            }

            if xpIslandVisible {
                VStack {
                    XPDynamicIslandView(
                        gain: xpLastGain,
                        level: XPProgress.level(for: totalXP),
                        progress: xpDisplayedProgress,
                        currentXPInLevel: XPProgress.xpInCurrentLevel(for: totalXP),
                        xpPerLevel: XPProgress.xpPerLevel,
                        infoPhase: xpInfoPhase
                    )
                    .scaleEffect(1 + xpIslandNudge, anchor: .top)
                    .offset(y: xpIslandNudge * -3)
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.top, 6)
                .transition(.appleNotificationBanner)
                .zIndex(20)
                .allowsHitTesting(false)
            }

            if sessionBannerVisible {
                VStack {
                    SessionBannerView()
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.top, 6)
                .transition(.appleNotificationBanner)
                .zIndex(18)
                .allowsHitTesting(false)
            }

            VStack(spacing: 0) {
                Spacer()
                NativeInstagramTabBar(
                    selectedTab: nativeSelectedTab,
                    messageBadgeCount: nativeMessageBadgeCount,
                    isLocked: sessionLimiter.isLocked,
                    onSelectTab: { tab in
                        selectSection(tab)
                    },
                    onSelectInstagramProfile: {
                        selectSection("profile")
                    },
                    onSelectStopScrollProfile: {
                        selectSection("dashboard")
                    },
                    profileMode: profileMode
                )
            }
            .zIndex(15)
        }
        .background(instagramSurfaceColor.ignoresSafeArea())
        .confirmationDialog("StopScroll", isPresented: $showControlCenterChooser, titleVisibility: .visible) {
            Button("Dashboard") {
                showingDashboard = true
                profileMode = .stopScroll
                nativeSelectedTab = "profile"
            }
            Button("Parametres") {
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
        .onReceive(settings.$adLabels) { _ in
            labelsToken += 1
        }
        .onReceive(settings.$articleSources) { _ in
            labelsToken += 1
        }
        .onReceive(settings.$devMode) { _ in
            labelsToken += 1
        }
        .onReceive(settings.$injectionFrequency) { newValue in
            if WebRefreshPolicy.shouldReloadFeedOnInjectionChange(
                oldValue: lastObservedInjectionFrequency,
                newValue: newValue
            ) {
                labelsToken += 1
                lastObservedInjectionFrequency = newValue
            }
        }
        .onReceive(settings.$backgroundRefreshToken) { _ in
            themeRefreshToken += 1
        }
        .onReceive(settings.$lazyWebViewRefreshToken) { newToken in
            guard newToken != lastObservedLazyWebViewRefreshToken else { return }
            pendingLazyReloadSurfaces.formUnion(
                WebRefreshPolicy.lazyReloadTargets(excluding: activeSurface)
            )
            lastObservedLazyWebViewRefreshToken = newToken
        }
        .onChange(of: activeSurface) { newSurface in
            consumePendingLazyReloadIfNeeded(for: newSurface)
        }
        .onAppear {
            reconfigureSurfacesForCurrentMode()
            consumePendingLazyReloadIfNeeded(for: activeSurface)
            DailyUsageTracker.shared.recordOpen()
            SessionLimitManager.shared.notifyTabChange(to: nativeSelectedTab)
            showSessionBanner()
        }
        .onDisappear {
            DailyUsageTracker.shared.recordBackground()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            DailyUsageTracker.shared.recordOpen()
            SessionLimitManager.shared.notifyTabChange(to: nativeSelectedTab)
            showSessionBanner()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
            DailyUsageTracker.shared.recordBackground()
            SessionLimitManager.shared.notifyBackground()
        }
        .onChange(of: sessionLimiter.isLocked) { locked in
            if locked {
                withAnimation { selectSection("timer") }
            } else if nativeSelectedTab == "timer" {
                withAnimation { selectSection("home") }
            }
        }
    }

}
