import SwiftUI
import UIKit

extension InstagramView {
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
