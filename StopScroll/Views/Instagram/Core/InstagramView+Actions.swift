import SwiftUI
import UIKit

extension InstagramView {
    func selectSection(_ tab: String) {
        // Redirect consuming tabs to timer when session is locked
        if SessionLimitManager.isConsumingTab(tab) && SessionLimitManager.shared.isLocked {
            nativeSelectedTab = "timer"
            return
        }

        // Timer tab: show the lock screen
        if tab == "timer" {
            showingReader = false
            showingDashboard = false
            nativeSelectedTab = "timer"
            SessionLimitManager.shared.notifyTabChange(to: "timer")
            return
        }

        if tab != "book" {
            showingBookReaderSettings = false
        }

        if showingSettings {
            showingSettings = false
        }

        if tab == "home",
           currentSectionTab == "home",
           !showingReader,
           !showingDashboard,
           !showingSettings,
           !showingBookReaderSettings {
            LogManager.shared.log("🏠 Home re-tap: dispatch native command", category: "Navigation", level: .debug)
            nativeSelectedTab = "home"
            nativeNavCommandToken += 1
            return
        }

        if tab == "search",
           currentSectionTab == "search",
           !showingReader,
           !showingDashboard,
           !showingSettings,
           !showingBookReaderSettings {
            LogManager.shared.log("🔎 Search re-tap: dispatch native command", category: "Navigation", level: .debug)
            nativeSelectedTab = "search"
            nativeNavCommandToken += 1
            return
        }

        if tab == "reels",
           currentSectionTab == "reels",
           !showingReader,
           !showingDashboard,
           !showingSettings,
           !showingBookReaderSettings {
            LogManager.shared.log("🎞️ Reels re-tap: dispatch native command", category: "Navigation", level: .debug)
            nativeSelectedTab = "reels"
            nativeNavCommandToken += 1
            return
        }

        sectionSwipeTargetTab = nil
        sectionSwipeTranslation = 0

        if tab != "dashboard" {
            showingDashboard = false
        }

        if tab == "book" {
            showingReader = true
            showingDashboard = false
            profileMode = .instagram
            nativeSelectedTab = "book"
            SessionLimitManager.shared.notifyTabChange(to: "book")
            return
        }

        if tab == "dashboard" {
            showingReader = false
            showingDashboard = true
            profileMode = .stopScroll
            nativeSelectedTab = "profile"
            SessionLimitManager.shared.notifyTabChange(to: "dashboard")
            return
        }

        showingReader = false
        showingDashboard = false

        if tab == "profile" {
            profileMode = .instagram
        }

        openInstagramTab(tab)
    }

    func openInstagramTab(_ tab: String) {
        LogManager.shared.log("🔗 Tab selected: \(tab), surface: \(surfaceFor(tab: tab))", category: "Navigation", level: .info)
        
        if tab == "home" {
            ensureSurfaceAvailable(.main)
            activeSurface = .main
            profileMode = .instagram
            nativeSelectedTab = "home"
            SessionLimitManager.shared.notifyTabChange(to: "home")
            LogManager.shared.log("→ Home: activeSurface = main", category: "Navigation", level: .debug)
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

        let reelsWasMounted = hasReelsSurface
        let targetSurface = surfaceFor(tab: tab)
        ensureSurfaceAvailable(targetSurface)
        activeSurface = targetSurface
        nativeSelectedTab = tab
        SessionLimitManager.shared.notifyTabChange(to: tab)
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
        case .reels:
            if reelsWasMounted {
                // Preserve the currently viewed reel + scroll position when returning to this surface.
                isLoadingReels = false
                LogManager.shared.log("→ Reels: preserving existing WebView state", category: "Navigation", level: .debug)
            } else {
                // First mount uses initialURLString (reels home) from InstagramWebView.
                isLoadingReels = true
                LogManager.shared.log("→ Reels: first mount loading", category: "Navigation", level: .debug)
            }
        case .profile:
            isLoadingProfile = true
            profileNavigationURL = targetURL
            profileNavigationToken += 1
            LogManager.shared.log("→ Profile: loading started", category: "Navigation", level: .debug)
        }
    }

    func handleHorizontalSurfaceDragChanged(_ translation: CGFloat) {
        guard !showingSettings && !showingBookReaderSettings else { return }

        let clamped = max(-sectionPageWidth, min(sectionPageWidth, translation))
        sectionSwipeTranslation = clamped
        sectionSwipeTargetTab = NativeTabLayout.adjacentTab(to: currentSectionTab, swipeTranslation: clamped)
        prepareSwipePreviewTargetIfNeeded()
    }

    func handleHorizontalSurfaceDragEnded(_ translation: CGFloat, velocity: CGFloat) {
        guard !showingSettings && !showingBookReaderSettings else {
            withAnimation(.interactiveSpring(response: 0.28, dampingFraction: 0.9)) {
                sectionSwipeTranslation = 0
                sectionSwipeTargetTab = nil
            }
                        return
                }

        let targetTab = NativeTabLayout.adjacentTab(to: currentSectionTab, swipeTranslation: translation)
        let shouldCommit = targetTab != nil && HorizontalSwipePolicy.shouldCommit(
            translation: translation,
            velocity: velocity,
            pageWidth: sectionPageWidth
        )

        guard shouldCommit, let targetTab else {
            withAnimation(.interactiveSpring(response: 0.28, dampingFraction: 0.9)) {
                sectionSwipeTranslation = 0
                sectionSwipeTargetTab = nil
            }
            return
        }

        let finalTranslation = translation < 0 ? -sectionPageWidth : sectionPageWidth
        withAnimation(.easeOut(duration: 0.22)) {
            sectionSwipeTargetTab = targetTab
            sectionSwipeTranslation = finalTranslation
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            self.selectSection(targetTab)
        }
    }

    func horizontalSectionDragGesture(enabledFor tab: String) -> some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                guard currentSectionTab == tab else { return }
                guard HorizontalSwipeRecognizerPolicy.shouldTrackDrag(
                    translationX: value.translation.width,
                    translationY: value.translation.height,
                    activeTab: currentSectionTab
                ) else {
                    return
                }
                handleHorizontalSurfaceDragChanged(value.translation.width)
            }
            .onEnded { value in
                guard currentSectionTab == tab else { return }
                guard HorizontalSwipeRecognizerPolicy.shouldTrackDrag(
                    translationX: value.translation.width,
                    translationY: value.translation.height,
                    activeTab: currentSectionTab
                ) else {
                    withAnimation(.interactiveSpring(response: 0.28, dampingFraction: 0.9)) {
                        sectionSwipeTranslation = 0
                        sectionSwipeTargetTab = nil
                    }
                    return
                }
                handleHorizontalSurfaceDragEnded(
                    value.translation.width,
                    velocity: value.predictedEndTranslation.width - value.translation.width
                )
            }
    }

    func prepareSwipePreviewTargetIfNeeded() {
        guard let targetTab = sectionSwipeTargetTab else { return }
        switch targetTab {
        case "home", "search", "reels", "messages", "profile":
            ensureSurfaceAvailable(surfaceFor(tab: targetTab))
        default:
            break
        }
    }

    func sectionOffset(for tab: String) -> CGFloat {
        if tab == currentSectionTab {
            return sectionSwipeTranslation
        }

        if let sectionSwipeTargetTab, tab == sectionSwipeTargetTab {
            return HorizontalSwipeAnimation.previewTargetOffset(
                translation: sectionSwipeTranslation,
                pageWidth: sectionPageWidth
            )
        }

        let relative = NativeTabLayout.relativeOffset(from: currentSectionTab, to: tab)
        if relative == 0 { return sectionSwipeTranslation }
        return CGFloat(relative < 0 ? -1 : 1) * sectionPageWidth
    }

    func sectionOpacity(for tab: String) -> Double {
        if tab == currentSectionTab { return showingSettings ? 0 : 1 }
        if tab == sectionSwipeTargetTab { return showingSettings ? 0 : 1 }
        return 0
    }

    func isInteractiveSection(_ tab: String) -> Bool {
        !showingSettings && tab == currentSectionTab
        }

    func consumePendingLazyReloadIfNeeded(for surface: WebSurface) {
        guard WebRefreshPolicy.shouldConsumeLazyReload(
            for: surface,
            pendingSurfaces: pendingLazyReloadSurfaces
        ) else {
            return
        }

        pendingLazyReloadSurfaces.remove(surface)
        ensureSurfaceAvailable(surface)

        switch surface {
        case .main:
            reloadTokenMain += 1
        case .messages:
            reloadTokenMessages += 1
        case .search:
            reloadTokenSearch += 1
        case .reels:
            reloadTokenReels += 1
        case .profile:
            reloadTokenProfile += 1
        }

        LogManager.shared.log("♻️ Consumed lazy refresh for \(surface)", category: "WebView", level: .info)
    }

    func surfaceFor(tab: String) -> WebSurface {
        SurfaceRouter.surface(for: tab)
    }

    func ensureSurfaceAvailable(_ surface: WebSurface) {
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
        case .reels:
            if !hasReelsSurface {
                hasReelsSurface = true
                isLoadingReels = true
            }
        case .profile:
            if !hasProfileSurface {
                hasProfileSurface = true
                isLoadingProfile = true
            }
        }
    }

    func reconfigureSurfacesForCurrentMode() {
        LogManager.shared.log("🔄 Reconfiguring surfaces", category: "Routing", level: .info)
        
        activeSurface = surfaceFor(tab: nativeSelectedTab)

        hasMainSurface = false
        hasMessagesSurface = false
        hasSearchSurface = false
        hasReelsSurface = false
        hasProfileSurface = false

        ensureSurfaceAvailable(activeSurface)
    }

    func evictInactiveSurface() {
        if activeSurface != .main {
            hasMainSurface = false
            isLoadingMain = true
        }
        if activeSurface != .messages {
            hasMessagesSurface = false
            isLoadingMessages = true
        }
        if activeSurface != .search {
            hasSearchSurface = false
            isLoadingSearch = true
        }
        if activeSurface != .reels {
            hasReelsSurface = false
            isLoadingReels = true
        }
        if activeSurface != .profile {
            hasProfileSurface = false
            isLoadingProfile = true
        }
    }

    func grantXP(amount: Int, source: String) {
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
            withAnimation(.spring(duration: 0.52, bounce: 0.28)) {
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
            withAnimation(.spring(duration: 0.36, bounce: 0)) {
                xpIslandVisible = false
            }
        }
        xpHideWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.15, execute: workItem)
    }

    func showSessionBanner() {
        sessionBannerWorkItem?.cancel()
        // Show 0.4s after open, auto-dismiss after 2.5s
        let showItem = DispatchWorkItem {
            withAnimation(.spring(duration: 0.52, bounce: 0.28)) {
                sessionBannerVisible = true
            }
            // Tick the counter 0.6s after banner settles in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                withAnimation(.spring(duration: 0.4, bounce: 0.25)) {
                    DailyUsageTracker.shared.tickDisplayedOpens()
                }
            }
            let hideItem = DispatchWorkItem {
                withAnimation(.spring(duration: 0.36, bounce: 0)) {
                    sessionBannerVisible = false
                }
            }
            self.sessionBannerWorkItem = hideItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5, execute: hideItem)
        }
        sessionBannerWorkItem = showItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: showItem)
    }
}
