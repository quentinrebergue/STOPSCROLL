import SwiftUI
import UIKit

struct InstagramView: View {

    @ObservedObject private var settings = AppSettings.shared

    @State var isLoadingMain = true
    @State var isLoadingMessages = true
    @State var isLoadingSearch = true
    @State var isLoadingProfile = true
    @State var showingReader = false
    @State var reloadTokenMain = 0
    @State var reloadTokenMessages = 0
    @State var reloadTokenSearch = 0
    @State var reloadTokenProfile = 0
    @State var showingSettings = false
    @State var showingDashboard = false
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
    @State var profileNavigationURL: String? = nil
    @State var profileNavigationToken: Int = 0
    @State var showControlCenterChooser = false
    @State var activeSurface: WebSurface = .main
    @State var hasMainSurface = true
    @State var hasMessagesSurface = false
    @State var hasSearchSurface = false
    @State var hasProfileSurface = false
    @AppStorage("ss_instagram_username") var instagramUsername = ""
    @AppStorage("ss_webview_count") var webViewCount = 2
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

    var isActiveSurfaceLoading: Bool {
        switch activeSurface {
        case .main: return isLoadingMain
        case .messages: return isLoadingMessages
        case .search: return isLoadingSearch
        case .profile: return isLoadingProfile
        }
    }

    var normalizedWebViewCount: Int {
        min(max(webViewCount, 1), 4)
    }

    let webViewBottomOverscan: CGFloat = 116
    let sharedBottomNavReservedHeight: CGFloat = 92

    var currentSectionTab: String {
        VisibleSectionPolicy.currentTab(
            showingReader: showingReader,
            showingDashboard: showingDashboard,
            normalizedWebViewCount: normalizedWebViewCount,
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
                    handlesInstagramNavigation: normalizedWebViewCount == 1,
                    allowsHorizontalSurfaceSwipe: !showingSettings && !showingBookReaderSettings,
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
                .ignoresSafeArea(edges: .bottom)
                .offset(x: sectionOffset(for: "home"))
                .opacity(sectionOpacity(for: "home"))
                .allowsHitTesting(isInteractiveSection("home"))
                .id("surface-main")
            }

            if normalizedWebViewCount >= 2 && hasMessagesSurface {
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
                    scriptProfile: .reelBlocker,
                    handlesInstagramNavigation: true,
                    allowsHorizontalSurfaceSwipe: !showingSettings && !showingBookReaderSettings,
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
                .padding(.bottom, -WebViewLayoutPolicy.bottomOverscan(for: .messages, defaultOverscan: webViewBottomOverscan))
                .ignoresSafeArea(edges: .bottom)
                .offset(x: sectionOffset(for: "messages"))
                .opacity(sectionOpacity(for: "messages"))
                .allowsHitTesting(isInteractiveSection("messages"))
                .id("surface-messages")
            }

            if normalizedWebViewCount >= 3 && hasSearchSurface {
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
                    scriptProfile: .reelBlocker,
                    handlesInstagramNavigation: true,
                    allowsHorizontalSurfaceSwipe: !showingSettings && !showingBookReaderSettings,
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
                .ignoresSafeArea(edges: .bottom)
                .offset(x: sectionOffset(for: "search"))
                .opacity(sectionOpacity(for: "search"))
                .allowsHitTesting(isInteractiveSection("search"))
                .id("surface-search")
            }

            if normalizedWebViewCount == 4 && hasProfileSurface {
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
                    allowsHorizontalSurfaceSwipe: !showingSettings && !showingBookReaderSettings,
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
                .ignoresSafeArea(edges: .bottom)
                .offset(x: sectionOffset(for: "profile"))
                .opacity(sectionOpacity(for: "profile"))
                .allowsHitTesting(isInteractiveSection("profile"))
                .id("surface-profile")
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
                nativeSelectedTab = SurfaceRouter.tab(for: activeSurface)
            }, onOpenSettings: {
                // Show settings first to avoid one-frame feed flash.
                showingSettings = true
                showingDashboard = false
            })
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
                nativeSelectedTab = "dashboard"
            })
            .opacity(showingSettings ? 1 : 0)
            .allowsHitTesting(showingSettings)
            .ignoresSafeArea(edges: .bottom)
            .zIndex(13)

            GeometryReader { geo in
                instagramSurfaceColor
                    .frame(height: geo.safeAreaInsets.top)
                    .ignoresSafeArea(edges: .top)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .allowsHitTesting(false)
            .zIndex(5)

            if isActiveSurfaceLoading && !showingReader && !showingDashboard && !showingSettings {
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
                        selectSection(tab)
                    }
                )
            }
            .ignoresSafeArea(edges: .bottom)
            .zIndex(15)
        }
        .background(instagramSurfaceColor.ignoresSafeArea())
        .confirmationDialog("StopScroll", isPresented: $showControlCenterChooser, titleVisibility: .visible) {
            Button("Dashboard") {
                showingDashboard = true
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
        .onChange(of: webViewCount) { newValue in
            let clamped = min(max(newValue, 1), 4)
            if clamped != newValue {
                webViewCount = clamped
            }
            reconfigureSurfacesForCurrentMode()
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
                reloadTokenMain += 1
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
        }
    }

}
