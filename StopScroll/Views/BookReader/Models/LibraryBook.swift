import Foundation

// MARK: - Library Book (persisted)

struct LibraryBook: Codable, Identifiable {
    let id: String  // UUID string
    let title: String
    var savedCardIndex: Int
    var totalCards: Int
    var currentChapter: Int
    var totalPages: Int
    var readingMode: String
    var isArticle: Bool

    var progressPercent: Double {
        guard totalCards > 0 else { return 0 }
        return Double(savedCardIndex) / Double(totalCards) * 100
    }

    // Backward-compatible decoding: existing entries default isArticle to false
    init(id: String, title: String, savedCardIndex: Int, totalCards: Int,
         currentChapter: Int, totalPages: Int, readingMode: String, isArticle: Bool = false) {
        self.id = id; self.title = title; self.savedCardIndex = savedCardIndex
        self.totalCards = totalCards; self.currentChapter = currentChapter
        self.totalPages = totalPages; self.readingMode = readingMode; self.isArticle = isArticle
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        savedCardIndex = try c.decode(Int.self, forKey: .savedCardIndex)
        totalCards = try c.decode(Int.self, forKey: .totalCards)
        currentChapter = try c.decode(Int.self, forKey: .currentChapter)
        totalPages = try c.decode(Int.self, forKey: .totalPages)
        readingMode = try c.decode(String.self, forKey: .readingMode)
        isArticle = try c.decodeIfPresent(Bool.self, forKey: .isArticle) ?? false
    }
}
