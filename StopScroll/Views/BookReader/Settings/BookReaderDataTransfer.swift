import Foundation

enum BookReaderDataTransfer {
    static func loadLibrary() -> [LibraryBook] {
        guard let data = UserDefaults.standard.data(forKey: "library"),
              let lib = try? JSONDecoder().decode([LibraryBook].self, from: data) else { return [] }
        return lib
    }

    static func saveLibrary(_ library: [LibraryBook]) {
        if let data = try? JSONEncoder().encode(library) {
            UserDefaults.standard.set(data, forKey: "library")
        }
    }

    static func exportDataAsJSON(library: [LibraryBook]) -> Data? {
        var exportData: [String: Any] = ["library": []]
        var libraryExport: [[String: Any]] = []

        for book in library {
            var bookData: [String: Any] = [
                "id": book.id,
                "title": book.title,
                "savedCardIndex": book.savedCardIndex,
                "totalCards": book.totalCards,
                "currentChapter": book.currentChapter,
                "totalPages": book.totalPages,
                "readingMode": book.readingMode
            ]
            let key = "bookmarks_\(book.id)"
            if let bookmarks = UserDefaults.standard.array(forKey: key) as? [Int] {
                bookData["bookmarks"] = bookmarks
            }
            libraryExport.append(bookData)
        }

        exportData["library"] = libraryExport
        exportData["exportDate"] = ISO8601DateFormatter().string(from: Date())
        return try? JSONSerialization.data(withJSONObject: exportData, options: .prettyPrinted)
    }

    static func importDataFromJSON(_ data: Data) -> Bool {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let libraryExport = json["library"] as? [[String: Any]] else { return false }

        var newLibrary: [LibraryBook] = []

        for bookData in libraryExport {
            guard let id = bookData["id"] as? String,
                  let title = bookData["title"] as? String,
                  let savedCardIndex = bookData["savedCardIndex"] as? Int,
                  let totalCards = bookData["totalCards"] as? Int,
                  let currentChapter = bookData["currentChapter"] as? Int,
                  let totalPages = bookData["totalPages"] as? Int,
                  let readingMode = bookData["readingMode"] as? String else { continue }

            let book = LibraryBook(
                id: id, title: title,
                savedCardIndex: savedCardIndex, totalCards: totalCards,
                currentChapter: currentChapter, totalPages: totalPages,
                readingMode: readingMode
            )
            newLibrary.append(book)

            let key = "bookmarks_\(id)"
            if let bookmarks = bookData["bookmarks"] as? [Int] {
                UserDefaults.standard.set(bookmarks, forKey: key)
            }
        }

        saveLibrary(newLibrary)
        return true
    }
}
