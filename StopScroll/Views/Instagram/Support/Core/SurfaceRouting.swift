import Foundation

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
}
