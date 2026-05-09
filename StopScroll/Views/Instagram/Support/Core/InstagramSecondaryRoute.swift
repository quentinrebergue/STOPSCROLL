import Foundation

enum InstagramSecondaryRoute {
    static func url(for tab: String, username: String) -> String? {
        switch tab {
        case "messages":
            return "https://www.instagram.com/direct/inbox/"
        case "search":
            return "https://www.instagram.com/explore/"
        case "reels":
            return "https://www.instagram.com/reels/"
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
