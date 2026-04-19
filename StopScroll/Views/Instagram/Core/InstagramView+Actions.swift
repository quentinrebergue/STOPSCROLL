import SwiftUI
import UIKit

extension InstagramView {
    func selectSection(_ tab: String) {
        if showingSettings {
            showingSettings = false
        }

        if tab == "home",
           currentSectionTab == "home",
           !showingReader,
           !showingDashboard,
           !showingSettings,
           !showingBookReaderSettings {
            nativeSelectedTab = "home"
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
            nativeSelectedTab = "book"
            return
        }

        if tab == "dashboard" {
            showingReader = false
            showingDashboard = true
            nativeSelectedTab = "dashboard"
            return
        }

        showingReader = false
        showingDashboard = false
        openInstagramTab(tab)
    }

    func openInstagramTab(_ tab: String) {
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
        case "home", "search", "messages", "profile":
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
        !showingSettings && !showingBookReaderSettings && tab == currentSectionTab
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
        case .profile:
            reloadTokenProfile += 1
        }

        LogManager.shared.log("♻️ Consumed lazy refresh for \(surface)", category: "WebView", level: .info)
    }

    func surfaceFor(tab: String) -> WebSurface {
        SurfaceRouter.surface(for: tab, webViewCount: normalizedWebViewCount)
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
        case .profile:
            if !hasProfileSurface {
                hasProfileSurface = true
                isLoadingProfile = true
            }
        }
    }

    func reconfigureSurfacesForCurrentMode() {
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

    func evictInactiveSurface() {
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
