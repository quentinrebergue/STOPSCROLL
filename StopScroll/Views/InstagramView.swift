import SwiftUI
import UIKit

enum XPProgress {
    static let xpPerLevel = 100

    static func level(for totalXP: Int) -> Int {
        max(1, (max(totalXP, 0) / xpPerLevel) + 1)
    }

    static func xpInCurrentLevel(for totalXP: Int) -> Int {
        max(totalXP, 0) % xpPerLevel
    }

    static func progress(for totalXP: Int) -> Double {
        Double(xpInCurrentLevel(for: totalXP)) / Double(xpPerLevel)
    }

    static func remainingToNextLevel(for totalXP: Int) -> Int {
        xpPerLevel - xpInCurrentLevel(for: totalXP)
    }
}

enum WebSurface {
    case main
    case messages
    case search
    case profile
}

/// Extracted routing logic — isolated here so it can be unit-tested.
enum SurfaceRouter {
    static func surface(for tab: String, webViewCount: Int) -> WebSurface {
        let normalized = min(max(webViewCount, 1), 4)
        guard tab == "home" || tab == "search" || tab == "messages" || tab == "profile" else {
            return .main
        }
        switch normalized {
        case 1:
            return .main
        case 2:
            return tab == "home" ? .main : .messages
        case 3:
            if tab == "home" { return .main }
            if tab == "search" { return .search }
            return .messages // messages + profile share this surface
        default:
            if tab == "home" { return .main }
            if tab == "search" { return .search }
            if tab == "profile" { return .profile }
            return .messages
        }
    }
}

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

enum InstagramSecondaryRoute {
    static func url(for tab: String, username: String) -> String? {
        switch tab {
        case "messages":
            return "https://www.instagram.com/direct/inbox/"
        case "search":
            return "https://www.instagram.com/explore/"
        case "profile":
            let cleaned = username
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "@", with: "")
                .filter { $0.isLetter || $0.isNumber || $0 == "." || $0 == "_" }
            if cleaned.isEmpty { return nil }
            return "https://www.instagram.com/\(cleaned)/"
        default:
            return nil
        }
    }
}

private struct InstagramUsernamePromptSheet: View {
    @Binding var username: String
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Entrez votre pseudo Instagram pour ouvrir votre profil depuis la navbar native.")
                    .font(.subheadline)
                    .foregroundColor(.gray)

                TextField("pseudo_instagram", text: $username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.white.opacity(0.08)))

                Spacer()
            }
            .padding(16)
            .background(Color(white: 0.08).ignoresSafeArea())
            .navigationTitle("Pseudo Instagram")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Annuler") { onCancel() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Valider") { onConfirm() }
                        .disabled(username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

private struct NativeInstagramTabBar: View {
    let selectedTab: String
    let messageBadgeCount: Int
    let onSelectTab: (String) -> Void

    var body: some View {
        HStack(spacing: 2) {
            tabButton(id: "home", icon: "house")
            tabButton(id: "search", icon: "magnifyingglass")
            tabButton(id: "book", icon: "book.closed")
            tabButton(id: "messages", icon: "paperplane", badge: messageBadgeCount)
            tabButton(id: "dashboard", icon: "square.grid.2x2")
            tabButton(id: "profile", icon: "person.crop.circle")
        }
        .padding(.horizontal, 10)
        .padding(.top, 10)
        .padding(.bottom, 10)
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .padding(.horizontal, 12)
        .padding(.bottom, 10)
    }

    private func tabButton(id: String, icon: String, badge: Int = 0) -> some View {
        Button {
            onSelectTab(id)
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(selectedTab == id ? .white : Color.white.opacity(0.65))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)

                if badge > 0 {
                    Text(badgeLabel(for: badge))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.red)
                        .clipShape(Capsule())
                        .offset(x: 4, y: -2)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func badgeLabel(for count: Int) -> String {
        if count > 99 { return "99+" }
        return "\(count)"
    }
}

// MARK: - Instagram-style loading bar

private struct LoadingBar: View {
    @State private var animating = false

    var body: some View {
        GeometryReader { geo in
            LinearGradient(
                colors: [
                    Color(red: 0.94, green: 0.58, blue: 0.20),
                    Color(red: 0.86, green: 0.15, blue: 0.26),
                    Color(red: 0.74, green: 0.09, blue: 0.53),
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: geo.size.width * 0.35)
            .offset(x: animating ? geo.size.width * 0.65 : 0)
        }
        .frame(height: 2)
        .clipped()
        .onAppear {
            withAnimation(
                .easeInOut(duration: 1.0)
                .repeatForever(autoreverses: true)
            ) {
                animating = true
            }
        }
    }
}

private struct XPDynamicIslandView: View {
    let gain: Int
    let level: Int
    let progress: Double
    let currentXPInLevel: Int
    let xpPerLevel: Int
    let infoPhase: XPInfoPhase

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Group {
                    if infoPhase == .gain {
                        Text("+\(gain) XP")
                    } else {
                        Text("\(currentXPInLevel) / \(xpPerLevel) XP")
                    }
                }
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Spacer(minLength: 6)
                Text("Lv \(level)")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(Color(red: 0.53, green: 0.88, blue: 1.0))
            }

            GeometryReader { geo in
                let clamped = max(0.0, min(1.0, progress))
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.14))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.20, green: 1.0, blue: 0.24),
                                    Color(red: 0.36, green: 1.0, blue: 0.42)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * clamped)
                }
            }
            .frame(height: 6)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(width: 164)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.black.opacity(0.88))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.45), radius: 20, y: 6)
    }
}

private enum XPInfoPhase {
    case gain
    case progress
}

private enum XPCutoutStyle {
    case dynamicIsland
    case notch

    static func from(topInset: CGFloat) -> XPCutoutStyle {
        topInset >= 55 ? .dynamicIsland : .notch
    }
}

private struct XPCutoutAnchorView: View {
    let style: XPCutoutStyle

    var body: some View {
        Group {
            if style == .dynamicIsland {
                Capsule(style: .continuous)
                    .fill(Color.black)
                    .frame(width: 126, height: 35)
            } else {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(Color.black)
                    .frame(width: 170, height: 28)
            }
        }
        .shadow(color: Color.black.opacity(0.3), radius: 2, y: 1)
    }
}

private struct XPIslandTransitionModifier: ViewModifier {
    let opacity: Double
    let scale: CGFloat
    let yOffset: CGFloat

    func body(content: Content) -> some View {
        content
            .opacity(opacity)
            .scaleEffect(scale, anchor: .top)
            .offset(y: yOffset)
    }
}

private extension AnyTransition {
    static var xpIslandOrganic: AnyTransition {
        .asymmetric(
            insertion: .modifier(
                active: XPIslandTransitionModifier(opacity: 0, scale: 0.82, yOffset: -20),
                identity: XPIslandTransitionModifier(opacity: 1, scale: 1, yOffset: 0)
            ),
            removal: .modifier(
                active: XPIslandTransitionModifier(opacity: 0, scale: 0.96, yOffset: -8),
                identity: XPIslandTransitionModifier(opacity: 1, scale: 1, yOffset: 0)
            )
        )
    }
}

struct DashboardView: View {
    let onDismiss: () -> Void
    var onOpenSettings: (() -> Void)? = nil

    @AppStorage("ss_xp_total") private var totalXP = 0
    @AppStorage("ss_goal_sessions_per_day") private var goalSessionsPerDay = 3
    @AppStorage("ss_goal_minutes_per_day") private var goalMinutesPerDay = 30
    @AppStorage("ss_usage_sessions_today") private var sessionsToday = 0
    @AppStorage("ss_usage_minutes_today") private var minutesToday = 0

    private var xpLevel: Int {
        XPProgress.level(for: totalXP)
    }

    private var xpProgress: Double {
        XPProgress.progress(for: totalXP)
    }

    private var xpInLevel: Int {
        XPProgress.xpInCurrentLevel(for: totalXP)
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    goalsCard
                    usageCard
                    progressionCard
                }
                .padding(16)
                .padding(.bottom, 104)
            }
            .background(Color(white: 0.06).ignoresSafeArea())
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        onOpenSettings?()
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { onDismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var goalsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Objectifs")
                .font(.headline)
                .foregroundColor(.white)

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Sessions / jour")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Stepper(value: $goalSessionsPerDay, in: 1...12) {
                        Text("\(goalSessionsPerDay)")
                            .foregroundColor(.white)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Minutes / jour")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Stepper(value: $goalMinutesPerDay, in: 5...180, step: 5) {
                        Text("\(goalMinutesPerDay) min")
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color(white: 0.1)))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }

    private var usageCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Usage du jour")
                .font(.headline)
                .foregroundColor(.white)

            HStack(spacing: 12) {
                dashboardMetric(title: "Sessions", value: "\(sessionsToday)", target: "Objectif \(goalSessionsPerDay)")
                dashboardMetric(title: "Minutes", value: "\(minutesToday)", target: "Objectif \(goalMinutesPerDay)")
            }

            ProgressView(value: usageProgress)
                .tint(Color(red: 0.35, green: 0.85, blue: 0.45))
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color(white: 0.1)))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }

    private var progressionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Progression")
                .font(.headline)
                .foregroundColor(.white)

            HStack(alignment: .firstTextBaseline) {
                Text("Niveau \(xpLevel)")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Spacer()
                Text("\(xpInLevel) / \(XPProgress.xpPerLevel) XP")
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            ProgressView(value: xpProgress)
                .tint(Color(red: 0.42, green: 0.9, blue: 1.0))

            Text("Total XP: \(totalXP)")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color(white: 0.1)))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }

    private var usageProgress: Double {
        let sessionRatio = goalSessionsPerDay > 0 ? Double(sessionsToday) / Double(goalSessionsPerDay) : 0
        let minuteRatio = goalMinutesPerDay > 0 ? Double(minutesToday) / Double(goalMinutesPerDay) : 0
        return max(0, min(1, (sessionRatio + minuteRatio) / 2.0))
    }

    private func dashboardMetric(title: String, value: String, target: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Text(target)
                .font(.caption2)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.white.opacity(0.03)))
    }
}
