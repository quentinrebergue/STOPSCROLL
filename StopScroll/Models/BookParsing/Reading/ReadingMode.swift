import Foundation

enum ReadingMode: String, CaseIterable, Identifiable {
    case sprint = "Sprint"
    case flow = "Flow"
    case deep = "Deep"

    var id: String { rawValue }

    var charsPerCard: Int {
        switch self {
        case .sprint: return 250
        case .flow:   return 500
        case .deep:   return 750
        }
    }

    var cardsPerPage: Int {
        switch self {
        case .sprint: return 6
        case .flow:   return 3
        case .deep:   return 2
        }
    }

    var fontSize: CGFloat {
        switch self {
        case .sprint: return 19
        case .flow:   return 17
        case .deep:   return 16
        }
    }

    var lineSpacing: CGFloat {
        switch self {
        case .sprint: return 9
        case .flow:   return 7
        case .deep:   return 6
        }
    }

    var icon: String {
        switch self {
        case .sprint: return "hare"
        case .flow:   return "figure.walk"
        case .deep:   return "tortoise"
        }
    }

    var label: String {
        switch self {
        case .sprint: return "Sprint"
        case .flow:   return "Flow"
        case .deep:   return "Deep"
        }
    }
}
