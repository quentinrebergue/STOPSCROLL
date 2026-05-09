import Foundation
import CoreGraphics

struct NativeTabItem: Equatable {
    let id: String
    let icon: String
}

enum NativeTabLayout {
    static let items: [NativeTabItem] = [
        NativeTabItem(id: "home",     icon: "house"),
        NativeTabItem(id: "search",   icon: "magnifyingglass"),
        NativeTabItem(id: "reels",    icon: "play.square"),
        NativeTabItem(id: "book",     icon: "book.closed"),
        NativeTabItem(id: "messages", icon: "paperplane"),
        NativeTabItem(id: "profile",  icon: "person.crop.circle")
    ]

    /// Tab bar shown when the session limit is reached.
    static let lockedItems: [NativeTabItem] = [
        NativeTabItem(id: "book",     icon: "book.closed"),
        NativeTabItem(id: "messages", icon: "paperplane"),
        NativeTabItem(id: "profile",  icon: "person.crop.circle"),
        NativeTabItem(id: "timer",    icon: "timer")
    ]

    static func index(of tab: String) -> Int? {
        items.firstIndex { $0.id == tab }
    }

    static func relativeOffset(from currentTab: String, to tab: String) -> Int {
        guard let currentIndex = index(of: currentTab),
              let targetIndex = index(of: tab) else {
            return 0
        }
        return targetIndex - currentIndex
    }

    static func adjacentTab(to tab: String, swipeTranslation: CGFloat) -> String? {
        guard let currentIndex = index(of: tab), swipeTranslation != 0 else {
            return nil
        }

        // Finger moves right -> reveal the tab on the left.
        // Finger moves left  -> reveal the tab on the right.
        let targetIndex = swipeTranslation > 0 ? currentIndex - 1 : currentIndex + 1
        guard items.indices.contains(targetIndex) else { return nil }
        return items[targetIndex].id
    }
}

enum VisibleSectionPolicy {
    static func currentTab(
        showingReader: Bool,
        showingDashboard: Bool,
        nativeSelectedTab: String,
        activeSurface: WebSurface
    ) -> String {
        if showingReader { return "book" }
        if showingDashboard { return "dashboard" }
        if nativeSelectedTab == "timer" { return "timer" }
        return SurfaceRouter.tab(for: activeSurface)
    }
}

enum HorizontalSwipePolicy {
    static func shouldCommit(
        translation: CGFloat,
        velocity: CGFloat,
        pageWidth: CGFloat
    ) -> Bool {
        let distanceThreshold = max(pageWidth * 0.18, 56)
        return abs(translation) >= distanceThreshold || abs(velocity) >= 700
    }
}

enum HorizontalSwipeRecognizerPolicy {
    static func shouldAllowSectionSwipe(activeTab: String) -> Bool {
        return true
    }

    static func shouldBegin(velocityX: CGFloat, velocityY: CGFloat, activeTab: String) -> Bool {
        let ratio: CGFloat
        let minSpeed: CGFloat

        switch activeTab {
        case "home":
            // Feed cards use horizontal gestures; require a stronger intent
            // before we switch sections.
            ratio = 1.7
            minSpeed = 280
        case "search":
            // Explore must win against inner Instagram horizontal gestures.
            ratio = 0.9
            minSpeed = 10
        case "messages":
            // In chat threads, prioritize vertical scrolling over section swipes.
            ratio = 1.8
            minSpeed = 220
        default:
            ratio = 1.2
            minSpeed = 120
        }

        return abs(velocityX) > abs(velocityY) * ratio && abs(velocityX) > minSpeed
    }

    static func shouldTrackDrag(translationX: CGFloat, translationY: CGFloat, activeTab: String) -> Bool {
        let ratio: CGFloat
        let minDistance: CGFloat
        switch activeTab {
        case "home":
            ratio = 1.7
            minDistance = 32
        case "search":
            ratio = 1.1
            minDistance = 12
        default:
            ratio = 1.35
            minDistance = 16
        }
        return abs(translationX) >= minDistance && abs(translationX) > abs(translationY) * ratio
    }
}

enum HorizontalSwipeAnimation {
    static func previewTargetOffset(translation: CGFloat, pageWidth: CGFloat) -> CGFloat {
        (translation < 0 ? pageWidth : -pageWidth) + translation
    }
}

enum WebSurface: CaseIterable, Hashable {
    case main
    case messages
    case search
    case reels
    case profile
}

enum SurfaceSwipeDirection {
    case previous
    case next
}

/// Extracted routing logic — isolated here so it can be unit-tested.
enum SurfaceRouter {
    static func surface(for tab: String) -> WebSurface {
        switch tab {
        case "home":     return .main
        case "search":   return .search
        case "reels":    return .reels
        case "messages": return .messages
        case "profile":  return .profile
        default:         return .main
        }
    }

    static func tab(for surface: WebSurface) -> String {
        switch surface {
        case .main:
            return "home"
        case .search:
            return "search"
        case .messages:
            return "messages"
        case .reels:
            return "reels"
        case .profile:
            return "profile"
        }
    }
}

enum WebViewLayoutPolicy {
    /// Extra height added below the visible frame so Instagram's own bottom nav is pushed off-screen.
    /// Messages gets 0 (it needs its own composer visible at the bottom).
    /// Reels has its own value since the UI layout differs from the feed.
    static let reelsBottomOverscan: CGFloat = 5

    static func bottomOverscan(for surface: WebSurface, defaultOverscan: CGFloat) -> CGFloat {
        switch surface {
        case .messages: return 0
        case .reels:    return reelsBottomOverscan
        default:        return defaultOverscan
        }
    }
}

/// Small pure helpers for deciding when to refresh one/all webviews.
enum WebRefreshPolicy {
    static func shouldReloadFeedOnInjectionChange(oldValue: Int, newValue: Int) -> Bool {
        oldValue != newValue
    }

    static func shouldReloadAllWebViewsOnBackgroundChange(previousCSS: String, newCSS: String) -> Bool {
        let oldTrimmed = previousCSS.trimmingCharacters(in: .whitespacesAndNewlines)
        let newTrimmed = newCSS.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !newTrimmed.isEmpty else { return false }
        return oldTrimmed != newTrimmed
    }

    static func lazyReloadTargets(excluding sourceSurface: WebSurface) -> Set<WebSurface> {
        Set(WebSurface.allCases.filter { $0 != sourceSurface })
    }

    static func shouldConsumeLazyReload(for surface: WebSurface, pendingSurfaces: Set<WebSurface>) -> Bool {
        pendingSurfaces.contains(surface)
    }
}
