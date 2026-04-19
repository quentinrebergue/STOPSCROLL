import Foundation

// MARK: - Stored Chapter (Codable for persistence)

struct StoredChapter: Codable {
    let title: String
    let text: String
}

// MARK: - Book Storage (persists chapters to Documents)

enum BookStorage {
    private static var booksDir: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dir = docs.appendingPathComponent("Books", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func save(chapters: [(title: String, text: String)], bookId: String) {
        let stored = chapters.map { StoredChapter(title: $0.title, text: $0.text) }
        let url = booksDir.appendingPathComponent("\(bookId).json")
        if let data = try? JSONEncoder().encode(stored) {
            try? data.write(to: url, options: [.atomic])
        }
    }

    static func load(bookId: String) -> [(title: String, text: String)]? {
        let url = booksDir.appendingPathComponent("\(bookId).json")
        guard let data = try? Data(contentsOf: url),
              let stored = try? JSONDecoder().decode([StoredChapter].self, from: data) else { return nil }
        return stored.map { ($0.title, $0.text) }
    }

    static func delete(bookId: String) {
        let url = booksDir.appendingPathComponent("\(bookId).json")
        try? FileManager.default.removeItem(at: url)
        try? FileManager.default.removeItem(at: coverURL(bookId: bookId))
    }

    private static func coverURL(bookId: String) -> URL {
        booksDir.appendingPathComponent("\(bookId)_cover.bin")
    }

    static func saveCover(data: Data, bookId: String) {
        try? data.write(to: coverURL(bookId: bookId), options: [.atomic])
    }

    static func loadCover(bookId: String) -> Data? {
        try? Data(contentsOf: coverURL(bookId: bookId))
    }
}
