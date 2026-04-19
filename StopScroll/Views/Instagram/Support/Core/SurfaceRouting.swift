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
