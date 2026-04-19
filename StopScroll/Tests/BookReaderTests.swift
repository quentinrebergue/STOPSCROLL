import XCTest
@testable import StopScroll

// MARK: - LibraryBook Tests

final class LibraryBookTests: XCTestCase {

    func test_progressPercent_zero_when_noCards() {
        let book = LibraryBook(id: "1", title: "T", savedCardIndex: 0, totalCards: 0,
                               currentChapter: 1, totalPages: 10, readingMode: "flow")
        XCTAssertEqual(book.progressPercent, 0)
    }

    func test_progressPercent_halfwayThrough() {
        let book = LibraryBook(id: "1", title: "T", savedCardIndex: 50, totalCards: 100,
                               currentChapter: 1, totalPages: 10, readingMode: "flow")
        XCTAssertEqual(book.progressPercent, 50.0, accuracy: 0.001)
    }

    func test_progressPercent_atEnd() {
        let book = LibraryBook(id: "1", title: "T", savedCardIndex: 100, totalCards: 100,
                               currentChapter: 1, totalPages: 10, readingMode: "flow")
        XCTAssertEqual(book.progressPercent, 100.0, accuracy: 0.001)
    }

    func test_progressPercent_canExceed100_ifIndexBeyondTotal() {
        let book = LibraryBook(id: "1", title: "T", savedCardIndex: 110, totalCards: 100,
                               currentChapter: 1, totalPages: 10, readingMode: "flow")
        XCTAssertGreaterThan(book.progressPercent, 100.0)
    }

    func test_isArticle_defaultsFalse() {
        let book = LibraryBook(id: "1", title: "T", savedCardIndex: 0, totalCards: 10,
                               currentChapter: 1, totalPages: 5, readingMode: "flow")
        XCTAssertFalse(book.isArticle)
    }

    func test_isArticle_trueWhenSet() {
        let book = LibraryBook(id: "1", title: "T", savedCardIndex: 0, totalCards: 10,
                               currentChapter: 1, totalPages: 5, readingMode: "flow", isArticle: true)
        XCTAssertTrue(book.isArticle)
    }

    func test_decodingWithoutIsArticle_defaultsFalse() throws {
        let json = """
        {"id":"abc","title":"Test","savedCardIndex":5,"totalCards":20,
         "currentChapter":2,"totalPages":10,"readingMode":"flow"}
        """.data(using: .utf8)!
        let book = try JSONDecoder().decode(LibraryBook.self, from: json)
        XCTAssertFalse(book.isArticle)
        XCTAssertEqual(book.id, "abc")
        XCTAssertEqual(book.savedCardIndex, 5)
    }

    func test_decodingWithIsArticleTrue() throws {
        let json = """
        {"id":"xyz","title":"Article","savedCardIndex":0,"totalCards":30,
         "currentChapter":1,"totalPages":2,"readingMode":"flash","isArticle":true}
        """.data(using: .utf8)!
        let book = try JSONDecoder().decode(LibraryBook.self, from: json)
        XCTAssertTrue(book.isArticle)
    }

    func test_roundTripEncoding() throws {
        let original = LibraryBook(id: "round", title: "Round Trip", savedCardIndex: 7,
                                   totalCards: 14, currentChapter: 3, totalPages: 8,
                                   readingMode: "deep", isArticle: false)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(LibraryBook.self, from: data)
        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.title, original.title)
        XCTAssertEqual(decoded.savedCardIndex, original.savedCardIndex)
        XCTAssertEqual(decoded.readingMode, original.readingMode)
        XCTAssertEqual(decoded.isArticle, original.isArticle)
    }
}

// MARK: - BookStorage Tests

final class BookStorageTests: XCTestCase {

    private let testBookId = "test_book_\(UUID().uuidString)"

    override func tearDown() {
        super.tearDown()
        BookStorage.delete(bookId: testBookId)
    }

    func test_saveAndLoad_roundTrip() {
        let chapters: [(title: String, text: String)] = [
            ("Chapter 1", "Once upon a time..."),
            ("Chapter 2", "And then...")
        ]
        BookStorage.save(chapters: chapters, bookId: testBookId)
        let loaded = BookStorage.load(bookId: testBookId)
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.count, 2)
        XCTAssertEqual(loaded?[0].title, "Chapter 1")
        XCTAssertEqual(loaded?[1].text, "And then...")
    }

    func test_load_returnsNil_whenNotSaved() {
        let result = BookStorage.load(bookId: "nonexistent_\(UUID().uuidString)")
        XCTAssertNil(result)
    }

    func test_delete_removesBook() {
        BookStorage.save(chapters: [("T", "text")], bookId: testBookId)
        XCTAssertNotNil(BookStorage.load(bookId: testBookId))
        BookStorage.delete(bookId: testBookId)
        XCTAssertNil(BookStorage.load(bookId: testBookId))
    }

    func test_saveCoverAndLoad_roundTrip() {
        let coverData = Data([0xFF, 0xD8, 0xFF, 0xE0]) // fake JPEG header
        BookStorage.saveCover(data: coverData, bookId: testBookId)
        let loaded = BookStorage.loadCover(bookId: testBookId)
        XCTAssertEqual(loaded, coverData)
    }

    func test_loadCover_returnsNil_whenNotSaved() {
        let result = BookStorage.loadCover(bookId: "nocover_\(UUID().uuidString)")
        XCTAssertNil(result)
    }

    func test_delete_alsoRemovesCover() {
        BookStorage.save(chapters: [("T", "text")], bookId: testBookId)
        BookStorage.saveCover(data: Data([1, 2, 3]), bookId: testBookId)
        BookStorage.delete(bookId: testBookId)
        XCTAssertNil(BookStorage.loadCover(bookId: testBookId))
    }

    func test_save_emptyChapters() {
        BookStorage.save(chapters: [], bookId: testBookId)
        let loaded = BookStorage.load(bookId: testBookId)
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.count, 0)
    }
}

// MARK: - PageProgressResetConfig Tests

final class PageProgressResetConfigTests: XCTestCase {

    func test_totalSpan_zeroForSingleSegment() {
        XCTAssertEqual(PageProgressResetConfig.totalSpan(for: 1), 0.0, accuracy: 0.001)
    }

    func test_totalSpan_zeroForZeroSegments() {
        XCTAssertEqual(PageProgressResetConfig.totalSpan(for: 0), 0.0, accuracy: 0.001)
    }

    func test_totalSpan_linearlyScalesWithSegments() {
        let span2 = PageProgressResetConfig.totalSpan(for: 2)
        let span3 = PageProgressResetConfig.totalSpan(for: 3)
        XCTAssertEqual(span2, PageProgressResetConfig.delayPerSegment, accuracy: 0.001)
        XCTAssertEqual(span3, 2 * PageProgressResetConfig.delayPerSegment, accuracy: 0.001)
    }

    func test_totalDuration_includesBarDuration() {
        let span = PageProgressResetConfig.totalSpan(for: 5)
        let duration = PageProgressResetConfig.totalDuration(for: 5)
        XCTAssertEqual(duration, span + PageProgressResetConfig.barDuration, accuracy: 0.001)
    }

    func test_unifiedResetDuration_neverBelowMinimum() {
        // Even for 1 segment (span=0, barDuration=0.3), unified = max(0.3*0.5, 0.12) = 0.15
        let d = PageProgressResetConfig.unifiedResetDuration(for: 1)
        XCTAssertGreaterThanOrEqual(d, 0.12)
    }

    func test_unifiedResetDuration_scalesWithSegments() {
        let d1 = PageProgressResetConfig.unifiedResetDuration(for: 1)
        let d5 = PageProgressResetConfig.unifiedResetDuration(for: 5)
        XCTAssertLessThan(d1, d5)
    }

    func test_unifiedResetDuration_isHalfOfTotalDuration_forLargeSegmentCount() {
        // For 20 segments, totalDuration is large enough that the max(,0.12) doesn't apply
        let total = PageProgressResetConfig.totalDuration(for: 20)
        let unified = PageProgressResetConfig.unifiedResetDuration(for: 20)
        XCTAssertEqual(unified, total * PageProgressResetConfig.unifiedSpeedMultiplier, accuracy: 0.001)
    }
}

// MARK: - BookReaderView.resolveCurrentArticleId Tests

final class ResolveCurrentArticleIdTests: XCTestCase {

    func test_prefersUserDefaultsOverAppStorage() {
        let result = BookReaderView.resolveCurrentArticleId(
            appStorageValue: "app-value",
            userDefaultsValue: "defaults-value"
        )
        XCTAssertEqual(result, "defaults-value")
    }

    func test_fallsBackToAppStorage_whenDefaultsEmpty() {
        let result = BookReaderView.resolveCurrentArticleId(
            appStorageValue: "app-value",
            userDefaultsValue: ""
        )
        XCTAssertEqual(result, "app-value")
    }

    func test_fallsBackToAppStorage_whenDefaultsNil() {
        let result = BookReaderView.resolveCurrentArticleId(
            appStorageValue: "app-value",
            userDefaultsValue: nil
        )
        XCTAssertEqual(result, "app-value")
    }

    func test_returnsEmpty_whenBothEmpty() {
        let result = BookReaderView.resolveCurrentArticleId(
            appStorageValue: "",
            userDefaultsValue: ""
        )
        XCTAssertEqual(result, "")
    }

    func test_stripsWhitespaceFromDefaults() {
        let result = BookReaderView.resolveCurrentArticleId(
            appStorageValue: "app-value",
            userDefaultsValue: "  \n  "
        )
        // Whitespace-only defaults value → treated as empty → fallback to appStorage
        XCTAssertEqual(result, "app-value")
    }

    func test_preservesNonEmptyDefaultsWithLeadingSpaceStripped() {
        let result = BookReaderView.resolveCurrentArticleId(
            appStorageValue: "app-value",
            userDefaultsValue: "  article-123  "
        )
        XCTAssertEqual(result, "article-123")
    }
}
