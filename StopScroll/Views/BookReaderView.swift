import SwiftUI
import UniformTypeIdentifiers

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

private enum PageProgressResetConfig {
    static let delayPerSegment: Double = 0.12
    static let barDuration: Double = 0.3
    static let unifiedSwitchDelay: Double = 0.0
    static let mergeDuration: Double = 0.1
    static let postMergeDelay: Double = 0.2
    static let unifiedSpeedMultiplier: Double = 0.5
    static let mergeInnerOverlap: CGFloat = 1.2

    static func totalSpan(for segmentCount: Int) -> Double {
        delayPerSegment * Double(max(segmentCount - 1, 0))
    }

    static func totalDuration(for segmentCount: Int) -> Double {
        totalSpan(for: segmentCount) + barDuration
    }

    static func unifiedResetDuration(for segmentCount: Int) -> Double {
        max(totalDuration(for: segmentCount) * unifiedSpeedMultiplier, 0.12)
    }
}

// MARK: - Book Reader View

struct BookReaderView: View {
    let onDismiss: () -> Void

    @State private var cards: [BookCard] = []
    @State private var cachedChapters: [(title: String, text: String)] = []
    @State private var currentIndex: Int = 0
    @State private var showFilePicker = false
    @State private var bookTitle: String = ""
    @State private var bookmarkedIds: Set<Int> = []
    @State private var sessionCardsRead: Int = 0
    @State private var showPageComplete = false
    @State private var lastPage: Int = 0
    @State private var showSettings = false
    @State private var highlightSentence: String = ""
    @State private var highlightCardId: Int = -1
    @State private var showProgressConfetti = false
    @State private var pageProgressCelebrate = false
    @State private var pageProgressResetActive = false
    @State private var pageProgressUnifiedResetActive = false
    @State private var pageProgressMergeSegments = false
    @State private var pageProgressResetStart: Date? = nil
    @AppStorage("currentBookId") private var currentBookId: String = ""
    @AppStorage("currentArticleId") private var currentArticleId: String = ""
    @AppStorage("currentArticleOpenToken") private var currentArticleOpenToken: Int = 0

    @AppStorage("savedCardIndex") private var savedCardIndex: Int = 0
    @AppStorage("savedBookTitle") private var savedBookTitle: String = ""
    @AppStorage("readingMode") private var readingModeRaw: String = ReadingMode.flow.rawValue

    private var mode: ReadingMode {
        ReadingMode(rawValue: readingModeRaw) ?? .flow
    }

    private var totalPages: Int {
        cards.compactMap { card -> Int? in
            if case .text = card.type { return card.page }
            return nil
        }.max() ?? 0
    }

    private var currentChapterNumber: Int {
        guard cards.indices.contains(currentIndex) else { return 0 }
        return cards[currentIndex].chapter
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                if cards.isEmpty {
                    emptyState
                } else {
                    readerContent
                }
                bottomBar
            }
        }
        .background(Color.black)
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: Self.allowedTypes
        ) { result in
            if case .success(let url) = result {
                loadBook(from: url)
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsSheet(
                mode: mode,
                onModeChange: { newMode in
                    readingModeRaw = newMode.rawValue
                    reloadWithMode(newMode)
                },
                onLoadBook: { showSettings = false; showFilePicker = true },
                onSwitchBook: { bookId in
                    showSettings = false
                    switchToBook(bookId)
                },
                onDeleteBook: { bookId in
                    deleteBook(bookId)
                },
                onRenameBook: { bookId, newTitle in
                    renameBook(bookId: bookId, newTitle: newTitle)
                },
                onResetBook: { bookId in
                    resetBookProgress(bookId)
                },
                currentBookId: currentBookId,
                bookTitle: bookTitle,
                allBookmarkedCards: bookmarkedCards()
            )
        }
        .onAppear {
            loadLastBook()
            loadBookmarks()
        }
        .onChange(of: currentBookId) { _ in
            loadLastBook()
            loadBookmarks()
        }
        .onChange(of: currentArticleId) { newId in
            guard !newId.isEmpty else { return }
            loadCurrentArticle()
        }
        .onChange(of: currentArticleOpenToken) { _ in
            guard !currentArticleId.isEmpty else { return }
            loadCurrentArticle()
        }
    }

    // MARK: - Supported file types

    private static var allowedTypes: [UTType] {
        var types: [UTType] = [.plainText]
        if let epub = UTType("org.idpf.epub-container") {
            types.append(epub)
        } else if let epub = UTType(filenameExtension: "epub") {
            types.append(epub)
        }
        types.append(.data)
        return types
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "book.closed")
                .font(.system(size: 60))
                .foregroundColor(Color(white: 0.35))

            Text("No book loaded")
                .font(.title2)
                .foregroundColor(.white)

            Button {
                showFilePicker = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                    Text("Load a Book")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 12)
                .background(Color(red: 0, green: 0.58, blue: 0.96))
                .clipShape(Capsule())
            }

            Text("Supports EPUB and TXT files")
                .font(.caption)
                .foregroundColor(Color(white: 0.55))

            Spacer()
        }
    }

    // MARK: - Reader content

    private var readerContent: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(bookTitle)
                    .font(.headline)
                    .foregroundColor(.white)
                    .lineLimit(1)

                Spacer()

                Text("\(sessionCardsRead) cards")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(Color(white: 0.4))
                    .padding(.trailing, 8)

                Button { showSettings = true } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 16))
                        .foregroundColor(Color(white: 0.55))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)

            // Progress bars row
            if let currentCard = cards.indices.contains(currentIndex) ? cards[currentIndex] : nil,
               case .text = currentCard.type {
                HStack(spacing: 8) {
                    if mode == .deep {
                        chapterProgressBar(currentCard: currentCard)
                            .frame(maxWidth: .infinity)
                    } else {
                        pageProgressBar(currentCard: currentCard)
                        chapterProgressBar(currentCard: currentCard)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
            } else {
                Spacer().frame(height: 6)
            }

            // Cards — vertical paging (reel-style snap)
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height

                TabView(selection: $currentIndex) {
                    ForEach(cards) { card in
                        cardContent(card: card)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 12)
                            .frame(width: w, height: h)
                            .rotationEffect(.degrees(-90))
                            .tag(card.id)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(width: h, height: w)
                .rotationEffect(.degrees(90))
                .frame(width: w, height: h)
                .id(readingModeRaw)
                .onChange(of: currentIndex) { newValue in
                    savedCardIndex = newValue
                    sessionCardsRead += 1
                    checkPageTransition()
                    updateLibraryProgress()
                    // Clear highlight when user navigates to a different page
                    if highlightCardId >= 0,
                       let hlCard = cards.first(where: { $0.id == highlightCardId }),
                       cards.indices.contains(newValue) {
                        let cur = cards[newValue]
                        if case .text = hlCard.type, case .text = cur.type {
                            if cur.page != hlCard.page {
                                highlightSentence = ""
                                highlightCardId = -1
                            }
                        } else {
                            highlightSentence = ""
                            highlightCardId = -1
                        }
                    }
                }
            }
        }
    }

    // MARK: - Card content

    @ViewBuilder
    private func cardContent(card: BookCard) -> some View {
        switch card.type {
        case .chapterStart(let title, let number):
            ChapterCard(title: title, chapterNumber: number)
        case .sectionStart(let title):
            SectionCard(title: title)
        case .text:
            TextCardView(
                card: card,
                mode: mode,
                isBookmarked: bookmarkedIds.contains(card.id),
                onBookmark: { toggleBookmark(card.id) },
                highlightText: card.id == highlightCardId ? highlightSentence : nil
            )
        case .timer:
            VStack(spacing: 16) {
                Text("⏱")
                    .font(.system(size: 48))
                Text("Set a timer")
                    .font(.headline)
                Text("Take a intentional break")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemBackground))
        case .completion(let isArticle):
            BookCompletionView(
                bookTitle: bookTitle,
                isArticle: isArticle,
                hasCurrentBook: !currentBookId.isEmpty,
                onDismiss: onDismiss,
                onSwitchToBook: {
                    currentArticleId = ""
                    switchToBook(currentBookId)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    // MARK: - Page progress bar (Stories-style)

    private func pageProgressBar(currentCard: BookCard) -> some View {
        let page = currentCard.page
        let cardsOnPage = cards.filter {
            if case .text = $0.type { return $0.page == page }
            return false
        }
        let total = max(cardsOnPage.count, 1)
        let currentOnPage = cardsOnPage.firstIndex(where: { $0.id == currentCard.id }).map { $0 + 1 } ?? 1

        return HStack(spacing: 3) {
            Text("Page.\(page)")
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundColor(Color(white: 0.4))
                .fixedSize()

            Group {
                if pageProgressUnifiedResetActive {
                    PageProgressUnifiedResetView(
                        total: total,
                        celebrate: pageProgressCelebrate,
                        resetStart: pageProgressResetStart
                    )
                } else {
                    HStack(spacing: pageProgressMergeSegments ? 0 : 3) {
                        ForEach(0..<total, id: \.self) { i in
                            PageProgressSegmentView(
                                index: i,
                                total: total,
                                currentOnPage: currentOnPage,
                                celebrate: pageProgressCelebrate,
                                resetActive: pageProgressResetActive,
                                resetStart: pageProgressResetStart,
                                mergeSegments: pageProgressMergeSegments
                            )
                        }
                    }
                    .animation(.easeInOut(duration: PageProgressResetConfig.mergeDuration), value: pageProgressMergeSegments)
                }
            }
            .overlay {
                if showProgressConfetti {
                    ProgressBarConfettiBurstOverlay()
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Chapter progress bar

    private func chapterProgressBar(currentCard: BookCard) -> some View {
        let ch = currentCard.chapter
        let chapterCards = cards.filter {
            if case .text = $0.type { return $0.chapter == ch }
            return false
        }
        let total = max(chapterCards.count, 1)
        let currentInChapter = chapterCards.firstIndex(where: { $0.id >= currentCard.id }).map { $0 + 1 } ?? total
        let progress = CGFloat(currentInChapter) / CGFloat(total)

        let label: String = {
            if currentCard.chapter > 0 {
                return "Chap.\(currentCard.chapter)"
            }
            let t = currentCard.chapterTitle.lowercased()
            if t.hasPrefix("preface") { return "Prefa." }
            if t.hasPrefix("foreword") { return "Forew." }
            if t.hasPrefix("introduction") { return "Intro." }
            if t.hasPrefix("prologue") { return "Prolo." }
            if t.hasPrefix("epilogue") { return "Epilo." }
            if !currentCard.chapterTitle.isEmpty {
                return String(currentCard.chapterTitle.prefix(5)) + "."
            }
            return "Chap.1"
        }()

        return HStack(spacing: 3) {
            Text(label)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundColor(Color(white: 0.4))
                .fixedSize()

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(white: 0.2))
                    RoundedRectangle(cornerRadius: 2)
                        .fill(progress >= 1.0 ? Color.green : Color(red: 0.4, green: 0.6, blue: 1.0))
                        .frame(width: geo.size.width * min(progress, 1.0))
                        .animation(.easeInOut(duration: 0.3), value: progress)
                }
            }
            .frame(height: 4)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Page complete overlay

    // MARK: - Page Complete Overlay (Commented - Replaced with particle animation)
    /*
    private var pageCompleteOverlay: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 44))
                .foregroundColor(.green)
            Text("Page complete!")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
        }
        .padding(32)
        .background(.ultraThinMaterial.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .transition(.scale.combined(with: .opacity))
        .onTapGesture {
            withAnimation(.easeOut(duration: 0.3)) {
                showPageComplete = false
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                withAnimation(.easeOut(duration: 0.3)) {
                    showPageComplete = false
                }
            }
        }
    }
    */

    private func checkPageTransition() {
        guard cards.indices.contains(currentIndex) else { return }
        let card = cards[currentIndex]
        if case .text = card.type, card.page > lastPage, lastPage > 0 {
            // Small completion reward on page transition, disabled in Deep mode.
            if mode != .deep {
                let resetSegmentCount = max(cards.filter {
                    if case .text = $0.type { return $0.page == card.page }
                    return false
                }.count, 1)
                let resetDuration = PageProgressResetConfig.unifiedResetDuration(for: resetSegmentCount)
                let mergeLead = max(PageProgressResetConfig.unifiedSwitchDelay - PageProgressResetConfig.mergeDuration, 0)

                pageProgressResetActive = false
                pageProgressUnifiedResetActive = false
                pageProgressMergeSegments = false
                pageProgressResetStart = nil

                withAnimation(.easeInOut(duration: 0.3)) {
                    pageProgressCelebrate = true
                }
                showProgressConfetti = true

                // Phase 1: 0.3s green + confetti
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showProgressConfetti = false

                    // Phase 2: short hold, fuse segments, then unified white reset.
                    DispatchQueue.main.asyncAfter(deadline: .now() + mergeLead) {
                        withAnimation(.easeInOut(duration: PageProgressResetConfig.mergeDuration)) {
                            pageProgressMergeSegments = true
                        }

                        DispatchQueue.main.asyncAfter(deadline: .now() + PageProgressResetConfig.mergeDuration) {
                            DispatchQueue.main.asyncAfter(deadline: .now() + PageProgressResetConfig.postMergeDelay) {
                                pageProgressUnifiedResetActive = true
                                pageProgressResetActive = true
                                pageProgressResetStart = Date()

                                withAnimation(.easeInOut(duration: resetDuration)) {
                                    pageProgressCelebrate = false
                                }

                                DispatchQueue.main.asyncAfter(deadline: .now() + resetDuration) {
                                    pageProgressResetActive = false
                                    pageProgressUnifiedResetActive = false
                                    pageProgressMergeSegments = false
                                    pageProgressResetStart = nil
                                }
                            }
                        }
                    }
                }
            }
            // Old popup - commented out
            // withAnimation(.spring(response: 0.4)) {
            //     showPageComplete = true
            // }
        }
        if case .text = card.type {
            lastPage = card.page
        }
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        HStack(spacing: 42) {
            navIconButton(icon: "house", isActive: false) { onDismiss() }
            navIconButton(icon: "magnifyingglass", isActive: false) { onDismiss() }
            navIconButton(icon: "book.fill", isActive: true) { }
            navIconButton(icon: "paperplane", isActive: false) { onDismiss() }
            navProfileButton(isActive: false) { onDismiss() }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 10)
        .padding(.top, 13)
        .padding(.bottom, 36)
        .background(Color.black.opacity(0.98))
        .overlay(
            Rectangle()
                .fill(Color.white.opacity(0.14))
                .frame(height: 0.5),
            alignment: .top
        )
    }

    private func navIconButton(icon: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .regular))
                .foregroundColor(isActive ? .white : Color(white: 0.9))
                .frame(width: 34)
                .frame(height: 34, alignment: .top)
                .padding(.top, 1)
        }
        .buttonStyle(.plain)
    }

    private func navProfileButton(isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color(white: 0.16))
                    .overlay(
                        Circle()
                            .stroke(isActive ? Color.white : Color(white: 0.8), lineWidth: isActive ? 2 : 1)
                    )
                    .frame(width: 26, height: 26)

                Image(systemName: "person.fill")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundColor(Color(white: 0.93))
            }
            .frame(width: 34)
            .frame(height: 34, alignment: .top)
            .padding(.top, 1)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Bookmarks (per-book)

    private func toggleBookmark(_ id: Int) {
        if bookmarkedIds.contains(id) {
            bookmarkedIds.remove(id)
        } else {
            bookmarkedIds.insert(id)
        }
        saveBookmarks()
    }

    private func saveBookmarks() {
        let key = "bookmarks_\(currentBookId)"
        UserDefaults.standard.set(Array(bookmarkedIds), forKey: key)
    }

    private func loadBookmarks() {
        let key = "bookmarks_\(currentBookId)"
        let saved = UserDefaults.standard.array(forKey: key) as? [Int] ?? []
        bookmarkedIds = Set(saved)
    }

    private func bookmarkedCards() -> [BookCard] {
        cards.filter { bookmarkedIds.contains($0.id) }
    }

    // MARK: - Library management

    private func loadLibrary() -> [LibraryBook] {
        guard let data = UserDefaults.standard.data(forKey: "library"),
              let lib = try? JSONDecoder().decode([LibraryBook].self, from: data) else { return [] }
        return lib
    }

    /// Patches the last card's .completion isArticle flag so the end card
    /// knows whether it's finishing a book or an article.
    private func withCompletion(_ cards: [BookCard], isArticle: Bool) -> [BookCard] {
        guard !cards.isEmpty else { return cards }
        var result = cards
        let last = result.count - 1
        if case .completion = result[last].type {
            let c = result[last]
            result[last] = BookCard(
                id: c.id, text: c.text, cardNumber: c.cardNumber, totalCards: c.totalCards,
                page: c.page, chapter: c.chapter, type: .completion(isArticle: isArticle),
                chapterTitle: c.chapterTitle, cardIndexInPage: c.cardIndexInPage
            )
        }
        return result
    }

    private func saveLibrary(_ library: [LibraryBook]) {
        if let data = try? JSONEncoder().encode(library) {
            UserDefaults.standard.set(data, forKey: "library")
        }
    }

    private func updateLibraryProgress() {
        guard !currentBookId.isEmpty else { return }
        var library = loadLibrary()
        if let idx = library.firstIndex(where: { $0.id == currentBookId }) {
            library[idx].savedCardIndex = currentIndex
            library[idx].totalCards = cards.count
            library[idx].currentChapter = currentChapterNumber
            library[idx].totalPages = totalPages
            library[idx].readingMode = readingModeRaw
            saveLibrary(library)
        }
    }

    private func addToLibrary(bookId: String, title: String, isArticle: Bool = false) {
        var library = loadLibrary()
        if !library.contains(where: { $0.id == bookId }) {
            library.append(LibraryBook(
                id: bookId, title: title,
                savedCardIndex: 0, totalCards: cards.count,
                currentChapter: 1, totalPages: totalPages,
                readingMode: readingModeRaw, isArticle: isArticle
            ))
            saveLibrary(library)
        }
        currentBookId = bookId
    }

    private func deleteBook(_ bookId: String) {
        var library = loadLibrary()
        library.removeAll { $0.id == bookId }
        saveLibrary(library)
        UserDefaults.standard.removeObject(forKey: "bookmarks_\(bookId)")
        BookStorage.delete(bookId: bookId)
        if bookId == currentBookId {
            cards = []
            cachedChapters = []
            bookTitle = ""
            currentBookId = ""
        }
    }

    private func renameBook(bookId: String, newTitle: String) {
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        var library = loadLibrary()
        guard let idx = library.firstIndex(where: { $0.id == bookId }) else { return }
        library[idx] = LibraryBook(
            id: library[idx].id,
            title: trimmed,
            savedCardIndex: library[idx].savedCardIndex,
            totalCards: library[idx].totalCards,
            currentChapter: library[idx].currentChapter,
            totalPages: library[idx].totalPages,
            readingMode: library[idx].readingMode
        )
        saveLibrary(library)

        if currentBookId == bookId {
            bookTitle = trimmed
            savedBookTitle = trimmed
        }
    }

    private func resetBookProgress(_ bookId: String) {
        var library = loadLibrary()
        if let idx = library.firstIndex(where: { $0.id == bookId }) {
            library[idx].savedCardIndex = 0
            library[idx].currentChapter = 1
            library[idx].totalPages = totalPages
            saveLibrary(library)
        }
        UserDefaults.standard.removeObject(forKey: "bookmarks_\(bookId)")
        if bookId == currentBookId {
            currentIndex = 0
            savedCardIndex = 0
            bookmarkedIds.removeAll()
            updateLibraryProgress()
        }
    }

    private func allBookmarkedCards() -> [BookCard] {
        let library = loadLibrary()
        var allMarked: [BookCard] = []
        for book in library {
            guard let chapters = BookStorage.load(bookId: book.id) else { continue }
            let bookCards = BookParser.makeCards(from: chapters, mode: mode)
            let key = "bookmarks_\(book.id)"
            let bookmarkedIds = Set(UserDefaults.standard.array(forKey: key) as? [Int] ?? [])
            let marked = bookCards.filter { bookmarkedIds.contains($0.id) }
            allMarked.append(contentsOf: marked)
        }
        return allMarked.sorted { $0.id < $1.id }
    }

    private func exportDataAsJSON() -> Data? {
        let library = loadLibrary()
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

    private func importDataFromJSON(_ data: Data) -> Bool {
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

    private func switchToBook(_ bookId: String) {
        let library = loadLibrary()
        guard let book = library.first(where: { $0.id == bookId }) else { return }
        let savedIdx = book.savedCardIndex

        currentBookId = bookId
        loadBookmarks()

        // Load chapters from persistent storage
        guard let chapters = BookStorage.load(bookId: bookId) else { return }

        let currentMode = mode
        DispatchQueue.global(qos: .userInitiated).async {
            let newCards = BookParser.makeCards(from: chapters, mode: currentMode)
            DispatchQueue.main.async {
                cachedChapters = chapters
                cards = withCompletion(newCards, isArticle: book.isArticle)
                bookTitle = book.title
                savedBookTitle = book.title
                currentIndex = min(savedIdx, max(0, newCards.count - 1))
                savedCardIndex = currentIndex
                sessionCardsRead = 0
                lastPage = 0
            }
        }
    }

    // MARK: - Book loading

    private func loadBook(from url: URL) {
        let currentMode = mode
        DispatchQueue.global(qos: .userInitiated).async {
            guard let result = BookParser.loadBook(from: url, mode: currentMode) else { return }
            let bookId = UUID().uuidString
            // Persist chapters to app storage
            BookStorage.save(chapters: result.chapters, bookId: bookId)
            if let cover = result.coverData {
                BookStorage.saveCover(data: cover, bookId: bookId)
            }
            DispatchQueue.main.async {
                cachedChapters = result.chapters
                cards = withCompletion(result.cards, isArticle: false)
                bookTitle = result.title
                savedBookTitle = result.title
                currentIndex = 0
                savedCardIndex = 0
                sessionCardsRead = 0
                lastPage = 0
                addToLibrary(bookId: bookId, title: result.title)
            }
        }
    }

    private func loadLastBook() {
        guard !currentBookId.isEmpty else { return }
        let library = loadLibrary()
        guard let book = library.first(where: { $0.id == currentBookId }) else { return }

        // Clear stale content immediately so the reader doesn't flash old cards
        // while the new book is being parsed asynchronously.
        cards = []
        bookTitle = ""

        loadBookmarks()

        // Load chapters from persistent storage
        guard let chapters = BookStorage.load(bookId: currentBookId) else { return }

        let currentMode = mode
        DispatchQueue.global(qos: .userInitiated).async {
            let newCards = BookParser.makeCards(from: chapters, mode: currentMode)
            DispatchQueue.main.async {
                cachedChapters = chapters
                cards = withCompletion(newCards, isArticle: book.isArticle)
                bookTitle = book.title
                savedBookTitle = book.title
                currentIndex = min(savedCardIndex, max(0, newCards.count - 1))
                if let card = cards.indices.contains(currentIndex) ? cards[currentIndex] : nil,
                   case .text = card.type {
                    lastPage = card.page
                }
            }
        }
    }

    private func loadCurrentArticle() {
        let articleId = currentArticleId
        guard !articleId.isEmpty else { return }
        let library = loadLibrary()
        guard let book = library.first(where: { $0.id == articleId }) else { return }

        cards = []
        bookTitle = ""

        guard let chapters = BookStorage.load(bookId: articleId) else { return }

        let currentMode = mode
        DispatchQueue.global(qos: .userInitiated).async {
            let newCards = BookParser.makeCards(from: chapters, mode: currentMode)
            DispatchQueue.main.async {
                cachedChapters = chapters
                cards = withCompletion(newCards, isArticle: true)
                bookTitle = book.title
                savedBookTitle = book.title
                currentIndex = 0
                savedCardIndex = 0
                sessionCardsRead = 0
                lastPage = 0
            }
        }
    }

    private func firstSentence(of text: String) -> String {
        let enders: Set<Character> = [".", "!", "?", "\u{2026}"]
        for (i, ch) in text.enumerated() {
            if enders.contains(ch) {
                let idx = text.index(text.startIndex, offsetBy: i + 1)
                return String(text[text.startIndex..<idx]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return String(text.prefix(80)).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func reloadWithMode(_ newMode: ReadingMode) {
        guard !cachedChapters.isEmpty else { return }

        // Save context before reload
        let savedSentence: String
        if cards.indices.contains(currentIndex), case .text = cards[currentIndex].type {
            savedSentence = firstSentence(of: cards[currentIndex].text)
        } else {
            savedSentence = ""
        }
        let oldProgress = cards.isEmpty ? 0.0 : Double(currentIndex) / Double(cards.count)
        let chapters = cachedChapters

        DispatchQueue.global(qos: .userInitiated).async {
            let newCards = BookParser.makeCards(from: chapters, mode: newMode)
            let isArticle = self.loadLibrary().first(where: { $0.id == self.currentBookId })?.isArticle ?? false
            DispatchQueue.main.async {
                cards = withCompletion(newCards, isArticle: isArticle)

                // Find card containing the saved sentence
                if !savedSentence.isEmpty,
                   let matchIdx = newCards.firstIndex(where: {
                       if case .text = $0.type { return $0.text.contains(savedSentence) }
                       return false
                   }) {
                    currentIndex = matchIdx
                    highlightSentence = savedSentence
                    highlightCardId = newCards[matchIdx].id
                } else {
                    // Fallback: approximate position by progress ratio
                    let newIdx = min(Int(oldProgress * Double(newCards.count)), max(0, newCards.count - 1))
                    currentIndex = newIdx
                    highlightSentence = ""
                    highlightCardId = -1
                }

                savedCardIndex = currentIndex
                lastPage = 0
            }
        }
    }
}

// MARK: - Settings Sheet

struct SettingsSheet: View {
    let mode: ReadingMode
    let onModeChange: (ReadingMode) -> Void
    let onLoadBook: () -> Void
    let onSwitchBook: (String) -> Void
    let onDeleteBook: (String) -> Void
    let onRenameBook: (String, String) -> Void
    let onResetBook: (String) -> Void
    let currentBookId: String
    let bookTitle: String
    let allBookmarkedCards: [BookCard]

    @State private var selectedBook: LibraryBook?
    @State private var library: [LibraryBook] = []
    @State private var showImportFileImporter = false
    @Environment(\.dismiss) private var dismiss

    private func exportDataAsJSON() -> Data? {
        let library = loadLibraryForExport()
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

    private func importDataFromJSON(_ data: Data) -> Bool {
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

        saveLibraryForExport(newLibrary)
        return true
    }

    private func loadLibraryForExport() -> [LibraryBook] {
        guard let data = UserDefaults.standard.data(forKey: "library"),
              let lib = try? JSONDecoder().decode([LibraryBook].self, from: data) else { return [] }
        return lib
    }

    private func saveLibraryForExport(_ library: [LibraryBook]) {
        if let data = try? JSONEncoder().encode(library) {
            UserDefaults.standard.set(data, forKey: "library")
        }
    }

    private func exportData() {
        guard let jsonData = exportDataAsJSON() else { return }
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("StopScroll_Export.json")
        try? jsonData.write(to: tempURL, options: [.atomic])
    }

    private func handleImportedFile(_ result: Result<URL, Error>) {
        if case .success(let url) = result {
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            if let data = try? Data(contentsOf: url) {
                _ = importDataFromJSON(data)
                reloadLibrary()
            }
        }
    }

    private func reloadLibrary() {
        guard let data = UserDefaults.standard.data(forKey: "library"),
              let lib = try? JSONDecoder().decode([LibraryBook].self, from: data) else {
            library = []
            return
        }
        library = lib
    }

    var body: some View {
        NavigationView {
            List {
                Section("Reading Mode") {
                    ForEach(ReadingMode.allCases) { m in
                        Button {
                            onModeChange(m)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: m.icon)
                                    .font(.system(size: 18))
                                    .frame(width: 28)
                                    .foregroundColor(m == mode ? .white : .gray)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(m.label)
                                        .foregroundColor(.white)
                                    Text("\(m.charsPerCard) chars")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                Spacer()
                                if m == mode {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }

                Section("Library") {
                    Button {
                        onLoadBook()
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.blue)
                            Text("Add a Book")
                                .foregroundColor(.blue)
                        }
                    }

                    ForEach(library.filter { !$0.isArticle }) { book in
                        Button {
                            selectedBook = book
                        } label: {
                            HStack {
                                BookCoverThumbnail(bookId: book.id)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(book.title)
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                    HStack(spacing: 8) {
                                        Text("\(Int(book.progressPercent))%")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                        ProgressView(value: book.progressPercent, total: 100)
                                            .tint(book.progressPercent >= 100 ? .green : .blue)
                                            .frame(width: 80)
                                    }
                                }
                                Spacer()
                                if book.id == currentBookId {
                                    Text("Reading")
                                        .font(.caption2)
                                        .foregroundColor(.green)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.green.opacity(0.15))
                                        .clipShape(Capsule())
                                }
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(Color(white: 0.3))
                            }
                        }
                    }
                }

                let articles = library.filter { $0.isArticle }
                if !articles.isEmpty {
                    Section("Articles") {
                        ForEach(articles) { article in
                            Button {
                                selectedBook = article
                            } label: {
                                HStack {
                                    Image(systemName: "doc.text")
                                        .font(.system(size: 22))
                                        .foregroundColor(Color(red: 0.98, green: 0.66, blue: 0.15))
                                        .frame(width: 38, height: 38)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(article.title)
                                            .foregroundColor(.white)
                                            .lineLimit(1)
                                        HStack(spacing: 8) {
                                            Text("\(Int(article.progressPercent))%")
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                            ProgressView(value: article.progressPercent, total: 100)
                                                .tint(article.progressPercent >= 100 ? .green : .orange)
                                                .frame(width: 80)
                                        }
                                    }
                                    Spacer()
                                    if article.id == currentBookId {
                                        Text("Reading")
                                            .font(.caption2)
                                            .foregroundColor(.green)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.green.opacity(0.15))
                                            .clipShape(Capsule())
                                    }
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(Color(white: 0.3))
                                }
                            }
                        }
                    }
                }

                let allMarked = allBookmarkedCards
                if !allMarked.isEmpty {
                    Section("Saved Passages") {
                        ForEach(allMarked) { card in
                            NavigationLink {
                                PassageDetailView(card: card, bookTitle: bookTitle, bookId: currentBookId)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(String(card.text.prefix(120)) + "...")
                                        .font(.system(size: 14, design: .serif))
                                        .foregroundColor(Color(white: 0.7))
                                        .lineLimit(3)
                                    HStack(spacing: 4) {
                                        Text(card.chapterTitle.isEmpty ? "Page \(card.page)" : card.chapterTitle)
                                        Text("·")
                                        Text("p.\(card.page), Card \(card.cardIndexInPage)")
                                    }
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(Color(white: 0.35))
                                }
                            }
                        }
                    }
                }

                Section("Data") {
                    Button(action: exportData) {
                        HStack {
                            Image(systemName: "arrow.up.doc")
                                .foregroundColor(.blue)
                            Text("Export All Data")
                                .foregroundColor(.blue)
                        }
                    }

                    Button(action: { showImportFileImporter = true }) {
                        HStack {
                            Image(systemName: "arrow.down.doc")
                                .foregroundColor(.green)
                            Text("Import Data")
                                .foregroundColor(.green)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color(white: 0.08))
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $selectedBook) { book in
                BookDetailSheet(
                    book: book,
                    isCurrent: book.id == currentBookId,
                    onOpen: {
                        selectedBook = nil
                        onSwitchBook(book.id)
                    },
                    onDelete: {
                        selectedBook = nil
                        onDeleteBook(book.id)
                        reloadLibrary()
                    },
                    onRename: { newTitle in
                        onRenameBook(book.id, newTitle)
                        reloadLibrary()
                    },
                    onReset: {
                        selectedBook = nil
                        onResetBook(book.id)
                        reloadLibrary()
                    }
                )
            }
            .onAppear {
                reloadLibrary()
            }
            .fileImporter(
                isPresented: $showImportFileImporter,
                allowedContentTypes: [.json],
                onCompletion: handleImportedFile
            )
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Book Detail Sheet

struct BookDetailSheet: View {
    let book: LibraryBook
    let isCurrent: Bool
    let onOpen: () -> Void
    let onDelete: () -> Void
    let onRename: (String) -> Void
    let onReset: () -> Void

    @State private var showDeleteConfirm = false
    @State private var showResetConfirm = false
    @State private var showRenamePrompt = false
    @State private var renameText = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                BookCoverLarge(bookId: book.id)

                Text(book.title)
                    .font(.title2.bold())
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                VStack(spacing: 12) {
                    HStack {
                        Text("Progress")
                            .foregroundColor(.gray)
                        Spacer()
                        Text("\(Int(book.progressPercent))%")
                            .foregroundColor(.white)
                            .fontWeight(.semibold)
                    }
                    ProgressView(value: book.progressPercent, total: 100)
                        .tint(book.progressPercent >= 100 ? .green : .blue)

                    HStack {
                        Label("\(book.totalPages) pages", systemImage: "doc.text")
                        Spacer()
                        Label("Chapter \(book.currentChapter)", systemImage: "book")
                    }
                    .font(.caption)
                    .foregroundColor(.gray)
                }
                .padding()
                .background(Color(white: 0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)

                Spacer()

                VStack(spacing: 12) {
                    if !isCurrent {
                        Button {
                            onOpen()
                        } label: {
                            Text("Open Book")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }

                    Button(role: .destructive) {
                        showResetConfirm = true
                    } label: {
                        Text("Reset Progress")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.orange.opacity(0.15))
                            .foregroundColor(.orange)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    Button {
                        renameText = book.title
                        showRenamePrompt = true
                    } label: {
                        Text("Rename Book")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.blue.opacity(0.15))
                            .foregroundColor(.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Text("Delete from Library")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.red.opacity(0.15))
                            .foregroundColor(.red)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 30)
            }
            .background(Color(white: 0.08))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Reset Progress?", isPresented: $showResetConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Reset", role: .destructive) {
                    onReset()
                }
            } message: {
                Text("This will reset your progress on \"\(book.title)\" to the beginning.")
            }
            .alert("Rename Book", isPresented: $showRenamePrompt) {
                TextField("New title", text: $renameText)
                Button("Cancel", role: .cancel) {}
                Button("Save") {
                    onRename(renameText)
                }
            } message: {
                Text("Enter a new title for this book.")
            }
            .alert("Delete Book?", isPresented: $showDeleteConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) { onDelete(); dismiss() }
            } message: {
                Text("This will remove \"\(book.title)\" and all saved passages from your library.")
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Text Card View (with double-tap heart)

struct TextCardView: View {
    let card: BookCard
    let mode: ReadingMode
    let isBookmarked: Bool
    let onBookmark: () -> Void
    var highlightText: String? = nil

    @State private var showHeartAnimation = false

    private var highlightedText: AttributedString {
        var attr = AttributedString(card.text)
        if let hl = highlightText, !hl.isEmpty,
           let range = attr.range(of: hl) {
            attr[range].underlineStyle = .single
            attr[range].foregroundColor = .white
        }
        return attr
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Card header
                HStack {
                    Text(card.chapterTitle.isEmpty ? "Page \(card.page)" : card.chapterTitle)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(Color(white: 0.4))
                        .lineLimit(1)

                    Spacer()

                    if isBookmarked {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.red)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 6)

                Rectangle()
                    .fill(Color(white: 0.15))
                    .frame(height: 0.5)
                    .padding(.horizontal, 20)

                Text(highlightedText)
                    .font(.custom("Charter", size: mode.fontSize))
                    .foregroundColor(Color(white: 0.92))
                    .lineSpacing(mode.lineSpacing)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(.horizontal, 22)
                    .padding(.top, 18)
                    .padding(.bottom, 20)

                Spacer(minLength: 0)

                Rectangle()
                    .fill(Color(white: 0.15))
                    .frame(height: 0.5)
                    .padding(.horizontal, 20)

                HStack {
                    Text("Page \(card.page), Card \(card.cardIndexInPage)")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(Color(white: 0.3))
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 6)
                .padding(.bottom, 14)
            }

            if showHeartAnimation {
                Image(systemName: "heart.fill")
                    .font(.system(size: 72))
                    .foregroundColor(.red.opacity(0.85))
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .background(Color(white: 0.09))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .onTapGesture(count: 2) {
            onBookmark()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                showHeartAnimation = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                withAnimation(.easeOut(duration: 0.2)) {
                    showHeartAnimation = false
                }
            }
        }
    }
}

// MARK: - Chapter Card

struct ChapterCard: View {
    let title: String
    let chapterNumber: Int

    private var gradient: LinearGradient {
        let colors: [[Color]] = [
            [Color(red: 0.4, green: 0.2, blue: 0.8), Color(red: 0.2, green: 0.1, blue: 0.5)],
            [Color(red: 0.1, green: 0.5, blue: 0.7), Color(red: 0.05, green: 0.25, blue: 0.45)],
            [Color(red: 0.6, green: 0.3, blue: 0.1), Color(red: 0.35, green: 0.15, blue: 0.05)],
            [Color(red: 0.15, green: 0.55, blue: 0.35), Color(red: 0.08, green: 0.3, blue: 0.2)],
            [Color(red: 0.65, green: 0.15, blue: 0.3), Color(red: 0.35, green: 0.08, blue: 0.18)],
        ]
        let pair = colors[(chapterNumber - 1) % colors.count]
        return LinearGradient(colors: pair, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Text("CHAPTER \(chapterNumber)")
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundColor(Color.white.opacity(0.6))
                .tracking(3)

            Text(title)
                .font(.custom("Charter", size: 28))
                .fontWeight(.bold)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)

            Rectangle()
                .fill(Color.white.opacity(0.3))
                .frame(width: 40, height: 2)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(gradient)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Section Card (preface, foreword, etc.)

struct SectionCard: View {
    let title: String

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Text(title)
                .font(.custom("Charter", size: 24))
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)

            Rectangle()
                .fill(Color.white.opacity(0.2))
                .frame(width: 30, height: 1.5)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(white: 0.13))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Passage Detail View

struct PassageDetailView: View {
    let card: BookCard
    let bookTitle: String
    let bookId: String

    private var uiImage: UIImage? {
        guard let data = BookStorage.loadCover(bookId: bookId) else { return nil }
        return UIImage(data: data)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 8) {
                    if let uiImage {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 14, height: 20)
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    } else {
                        Image(systemName: "book.closed")
                            .font(.system(size: 11))
                    }
                    Text(bookTitle)
                        .lineLimit(1)
                }
                .font(.system(size: 12))
                .foregroundColor(Color(white: 0.5))

                HStack(spacing: 12) {
                    if !card.chapterTitle.isEmpty {
                        Label(card.chapterTitle, systemImage: "bookmark")
                    }
                    Label("Page \(card.page)", systemImage: "doc.text")
                    Label("Card \(card.cardIndexInPage)", systemImage: "square")
                }
                .font(.system(size: 12))
                .foregroundColor(Color(white: 0.45))

                Rectangle()
                    .fill(Color(white: 0.2))
                    .frame(height: 0.5)

                Text(card.text)
                    .font(.custom("Charter", size: 17))
                    .foregroundColor(Color(white: 0.9))
                    .lineSpacing(7)
            }
            .padding()
        }
        .background(Color(white: 0.08))
        .navigationTitle("Saved Passage")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Progress Bar Confetti

private struct ConfettiParticle: Identifiable {
    let id = UUID()
    let x: CGFloat
    let y: CGFloat
    let size: CGFloat
}

struct ProgressBarConfettiView: View {
    let horizontalDirection: CGFloat
    let verticalDirection: CGFloat
    @State private var burst = false

    private let particles: [ConfettiParticle] = [
        .init(x: -15, y: -9, size: 2),
        .init(x: -7, y: 6, size: 2),
        .init(x: 5, y: -7, size: 2),
        .init(x: 13, y: 8, size: 2)
    ]

    private func targetX(for particle: ConfettiParticle) -> CGFloat {
        if horizontalDirection == 0 { return particle.x }
        return abs(particle.x) * horizontalDirection
    }

    private func targetY(for particle: ConfettiParticle) -> CGFloat {
        if verticalDirection == 0 { return particle.y }
        return abs(particle.y) * verticalDirection
    }

    var body: some View {
        ZStack {
            ForEach(particles) { particle in
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.green)
                    .frame(width: particle.size, height: particle.size + 1)
                    .offset(
                        x: burst ? targetX(for: particle) : 0,
                        y: burst ? targetY(for: particle) : 0
                    )
                    .opacity(burst ? 0 : 1)
            }
        }
        .frame(width: 24, height: 18)
        .onAppear {
            withAnimation(.easeOut(duration: 0.3)) {
                burst = true
            }
        }
    }
}

private struct ProgressBarConfettiBurstOverlay: View {
    private let horizontalEmitters: [CGFloat] = [0.02, 0.5, 0.98]
    private let verticalSideEmitters: [CGFloat] = [0.5]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(Array(horizontalEmitters.enumerated()), id: \.offset) { _, fraction in
                    ProgressBarConfettiView(horizontalDirection: 0, verticalDirection: -1)
                        .position(x: geo.size.width * fraction, y: 0)
                }

                ForEach(Array(horizontalEmitters.enumerated()), id: \.offset) { _, fraction in
                    ProgressBarConfettiView(horizontalDirection: 0, verticalDirection: 1)
                        .position(x: geo.size.width * fraction, y: geo.size.height)
                }

                ForEach(Array(verticalSideEmitters.enumerated()), id: \.offset) { _, fraction in
                    ProgressBarConfettiView(horizontalDirection: -1, verticalDirection: 0)
                        .position(x: 0, y: geo.size.height * fraction)
                }

                ForEach(Array(verticalSideEmitters.enumerated()), id: \.offset) { _, fraction in
                    ProgressBarConfettiView(horizontalDirection: 1, verticalDirection: 0)
                        .position(x: geo.size.width, y: geo.size.height * fraction)
                }
            }
        }
        .allowsHitTesting(false)
    }
}

private struct PageProgressSegmentView: View {
    let index: Int
    let total: Int
    let currentOnPage: Int
    let celebrate: Bool
    let resetActive: Bool
    let resetStart: Date?
    let mergeSegments: Bool

    private var normalFill: CGFloat {
        index < currentOnPage ? 1 : 0
    }

    private var mergeOverlap: CGFloat {
        guard mergeSegments, index > 0, index < total - 1 else { return 0 }
        return PageProgressResetConfig.mergeInnerOverlap
    }

    private func fillAmount(at now: Date) -> CGFloat {
        if celebrate {
            return 1
        }
        if resetActive {
            if index == 0 {
                return 1
            }

            guard let resetStart else { return normalFill }
            let totalSpan = PageProgressResetConfig.totalSpan(for: total)
            let barDuration = PageProgressResetConfig.barDuration
            let delayStep = totalSpan / Double(max(total - 1, 1))
            let stepsFromRight = Double(total - 1 - index)
            let delay = stepsFromRight * delayStep
            let elapsed = now.timeIntervalSince(resetStart)

            if elapsed <= delay {
                return 1
            }

            let localT = min(max((elapsed - delay) / barDuration, 0), 1)
            return CGFloat(1 - localT)
        }
        return normalFill
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Color(white: 0.25))
                        .frame(width: geo.size.width + mergeOverlap)
                        .offset(x: -mergeOverlap / 2)

                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(celebrate ? Color.green : Color.white)
                        .frame(width: (geo.size.width + mergeOverlap) * fillAmount(at: timeline.date))
                        .offset(x: -mergeOverlap / 2)
                }
            }
        }
        .frame(height: 3)
        .animation(.easeInOut(duration: 0.25), value: currentOnPage)
    }
}

private struct PageProgressUnifiedResetView: View {
    let total: Int
    let celebrate: Bool
    let resetStart: Date?

    private func fillAmount(at now: Date) -> CGFloat {
        guard let resetStart else { return 1 }
        let resetDuration = PageProgressResetConfig.unifiedResetDuration(for: total)
        let elapsed = now.timeIntervalSince(resetStart)
        let t = min(max(elapsed / max(resetDuration, 0.01), 0), 1)
        let easedT = t * t * (3 - 2 * t)
        let minimumFill = 1 / CGFloat(max(total, 1))
        return minimumFill + CGFloat(1 - easedT) * (1 - minimumFill)
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Color(white: 0.25))

                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(celebrate ? Color.green : Color.white)
                        .frame(width: geo.size.width * fillAmount(at: timeline.date))
                }
            }
        }
        .frame(height: 3)
    }
}

private struct BookCoverThumbnail: View {
    let bookId: String

    private var uiImage: UIImage? {
        guard let data = BookStorage.loadCover(bookId: bookId) else { return nil }
        return UIImage(data: data)
    }

    var body: some View {
        Group {
            if let uiImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "book.closed")
                    .font(.system(size: 16))
                    .foregroundColor(Color(white: 0.65))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(white: 0.15))
            }
        }
        .frame(width: 34, height: 50)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

private struct BookCoverLarge: View {
    let bookId: String

    private var uiImage: UIImage? {
        guard let data = BookStorage.loadCover(bookId: bookId) else { return nil }
        return UIImage(data: data)
    }

    var body: some View {
        Group {
            if let uiImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "book.closed.fill")
                    .font(.system(size: 44))
                    .foregroundColor(Color(white: 0.7))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(white: 0.14))
            }
        }
        .frame(width: 90, height: 128)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

// MARK: - Completion Burst Particle

private struct CompletionParticle: Identifiable {
    let id: Int
    let color: Color
    let width: CGFloat
    let height: CGFloat
    let isCircle: Bool
    let radians: Double
    let distance: CGFloat
    let spinDeg: Double
    let burstDelay: Double

    static func makeAll() -> [CompletionParticle] {
        let palette: [Color] = [
            .white,
            Color(red: 1.0, green: 0.84, blue: 0.0),   // gold
            Color(red: 1.0, green: 0.60, blue: 0.0),   // orange
            Color(red: 1.0, green: 0.40, blue: 0.40),   // coral
            Color(red: 0.60, green: 1.0, blue: 0.20),   // lime
            Color(red: 0.0,  green: 1.0, blue: 0.62),   // spring green
            Color(red: 0.0,  green: 0.75, blue: 1.0),   // sky blue
            Color(red: 0.78, green: 0.48, blue: 1.0),   // lavender
            Color(red: 1.0,  green: 0.85, blue: 0.10),  // yellow
        ]
        return (0..<60).map { i in
            let angle = (Double(i) / 60.0) * 2.0 * .pi + Double.random(in: -0.18...0.18)
            let isCircle = i % 3 != 0
            let w: CGFloat = isCircle ? CGFloat.random(in: 7...14) : CGFloat.random(in: 5...9)
            let h: CGFloat = isCircle ? w : CGFloat.random(in: 14...24)
            return CompletionParticle(
                id: i,
                color: palette[i % palette.count],
                width: w, height: h,
                isCircle: isCircle,
                radians: angle,
                distance: CGFloat.random(in: 130...270),
                spinDeg: Double.random(in: -200...200),
                burstDelay: Double.random(in: 0...0.10)
            )
        }
    }
}

// MARK: - Book Completion View

struct BookCompletionView: View {
    let bookTitle: String
    let isArticle: Bool
    let hasCurrentBook: Bool
    let onDismiss: () -> Void
    let onSwitchToBook: () -> Void

    @State private var expanded = false
    @State private var faded = false
    @State private var appeared = false

    private static let particles = CompletionParticle.makeAll()

    var body: some View {
        GeometryReader { geo in
            let cx = geo.size.width / 2
            let cy = geo.size.height * 0.42  // burst origin near checkmark

            ZStack {
                // ── Vivid green gradient background ──────────────────
                LinearGradient(
                    colors: [
                        Color(red: 0.01, green: 0.30, blue: 0.16),
                        Color(red: 0.04, green: 0.52, blue: 0.27),
                        Color(red: 0.08, green: 0.75, blue: 0.40),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                // Subtle radial glow behind burst origin
                RadialGradient(
                    colors: [Color.white.opacity(0.18), Color.clear],
                    center: .init(x: cx / geo.size.width, y: cy / geo.size.height),
                    startRadius: 0,
                    endRadius: 180
                )
                .ignoresSafeArea()

                // ── Burst particles ───────────────────────────────────
                ForEach(Self.particles) { p in
                    let dx = cos(p.radians) * p.distance * (expanded ? 1 : 0)
                    let dy = sin(p.radians) * p.distance * (expanded ? 1 : 0)
                    Group {
                        if p.isCircle {
                            Circle().fill(p.color)
                        } else {
                            RoundedRectangle(cornerRadius: 2).fill(p.color)
                        }
                    }
                    .frame(width: p.width, height: p.height)
                    .rotationEffect(.degrees(expanded ? p.spinDeg : 0))
                    .position(x: cx + dx, y: cy + dy)
                    .opacity(faded ? 0 : (expanded ? 1 : 0))
                    .animation(
                        .spring(response: 0.55, dampingFraction: 0.72)
                            .delay(p.burstDelay),
                        value: expanded
                    )
                    .animation(.easeOut(duration: 0.5), value: faded)
                }

                // ── Content ───────────────────────────────────────────
                VStack(spacing: 0) {
                    Spacer()

                    // Checkmark circle
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.16))
                            .frame(width: 128, height: 128)
                        Circle()
                            .stroke(Color.white.opacity(0.32), lineWidth: 1.5)
                            .frame(width: 128, height: 128)
                        Image(systemName: "checkmark")
                            .font(.system(size: 58, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .scaleEffect(appeared ? 1 : 0.15)
                    .opacity(appeared ? 1 : 0)
                    .animation(.spring(response: 0.48, dampingFraction: 0.52).delay(0.10), value: appeared)

                    Spacer().frame(height: 32)

                    // Congratulations heading
                    Text("Congratulations!")
                        .font(.system(size: 36, weight: .black))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .scaleEffect(appeared ? 1 : 0.5)
                        .opacity(appeared ? 1 : 0)
                        .animation(.spring(response: 0.5, dampingFraction: 0.62).delay(0.24), value: appeared)

                    Spacer().frame(height: 10)

                    // "You finished …" sub-heading
                    Text(isArticle ? "You read the full article" : "You finished the book")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white.opacity(0.70))
                        .opacity(appeared ? 1 : 0)
                        .animation(.easeOut(duration: 0.4).delay(0.36), value: appeared)

                    Spacer().frame(height: 8)

                    // Book / article title
                    Text(bookTitle)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white.opacity(0.55))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .lineLimit(2)
                        .opacity(appeared ? 1 : 0)
                        .animation(.easeOut(duration: 0.4).delay(0.44), value: appeared)

                    Spacer()

                    // Back to feed / Continue reading button
                    Button(action: isArticle && hasCurrentBook ? onSwitchToBook : onDismiss) {
                        Text(isArticle && hasCurrentBook ? "Continue reading" : "Back to feed")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(Color(red: 0.04, green: 0.38, blue: 0.20))
                            .padding(.horizontal, 52)
                            .padding(.vertical, 17)
                            .background(Color.white)
                            .clipShape(Capsule())
                            .shadow(color: .black.opacity(0.18), radius: 12, y: 4)
                    }
                    .offset(y: appeared ? 0 : 48)
                    .opacity(appeared ? 1 : 0)
                    .animation(.spring(response: 0.52, dampingFraction: 0.78).delay(0.58), value: appeared)

                    Spacer().frame(height: 64)
                }
                .padding(.horizontal, 32)
            }
        }
        .onAppear {
            // Fire burst
            withAnimation { expanded = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                withAnimation { faded = true }
            }
            // Content entrance
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                appeared = true
            }
            // Auto-switch to book after 4 s when finishing an article
            if isArticle && hasCurrentBook {
                DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                    onSwitchToBook()
                }
            }
        }
    }
}
