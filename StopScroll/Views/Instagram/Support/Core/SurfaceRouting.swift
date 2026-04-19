import Foundation
import CoreGraphics

struct NativeTabItem: Equatable {
    let id: String
    let icon: String
}

enum NativeTabLayout {
    static let items: [NativeTabItem] = [
        NativeTabItem(id: "home", icon: "house"),
        NativeTabItem(id: "search", icon: "magnifyingglass"),
        NativeTabItem(id: "book", icon: "book.closed"),
        NativeTabItem(id: "messages", icon: "paperplane"),
        NativeTabItem(id: "dashboard", icon: "square.grid.2x2"),
        NativeTabItem(id: "profile", icon: "person.crop.circle")
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
        normalizedWebViewCount: Int,
        nativeSelectedTab: String,
        activeSurface: WebSurface
    ) -> String {
        if showingReader { return "book" }
        if showingDashboard { return "dashboard" }
        if normalizedWebViewCount == 1 { return nativeSelectedTab }
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
    static func shouldBegin(velocityX: CGFloat, velocityY: CGFloat, activeTab: String) -> Bool {
        let ratio = activeTab == "search" ? 1.05 : 1.2
        let minSpeed: CGFloat = activeTab == "search" ? 40 : 120
        return abs(velocityX) > abs(velocityY) * ratio && abs(velocityX) > minSpeed
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
    case profile
}

enum SurfaceSwipeDirection {
    case previous
    case next
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

    static func tab(for surface: WebSurface) -> String {
        switch surface {
        case .main:
            return "home"
        case .search:
            return "search"
        case .messages:
            return "messages"
        case .profile:
            return "profile"
        }
    }
}

enum WebViewLayoutPolicy {
    static func bottomOverscan(for surface: WebSurface, defaultOverscan: CGFloat) -> CGFloat {
        surface == .messages ? 0 : defaultOverscan
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
