import SwiftUI

// MARK: - Book Reader View

struct BookReaderView: View {
    let onDismiss: () -> Void
    var bottomInset: CGFloat = 0

    @State private var cards: [BookCard] = []
    @State private var cachedChapters: [(title: String, text: String)] = []
    @State private var currentIndex: Int = 0
    @State private var showFilePicker = false
    @State private var bookTitle: String = ""
    @State private var bookmarkedIds: Set<Int> = []
    @State private var sessionCardsRead: Int = 0
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

    private var resolvedCurrentArticleId: String {
        Self.resolveCurrentArticleId(
            appStorageValue: currentArticleId,
            userDefaultsValue: UserDefaults.standard.string(forKey: "currentArticleId")
        )
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
            }
        }
        .ignoresSafeArea(edges: .bottom)
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
            if !resolvedCurrentArticleId.isEmpty {
                loadCurrentArticle()
            } else {
                loadLastBook()
            }
            loadBookmarks()
        }
        .onChange(of: currentBookId) { _ in
            if !resolvedCurrentArticleId.isEmpty {
                loadCurrentArticle()
            } else {
                loadLastBook()
            }
            loadBookmarks()
        }
        .onChange(of: currentArticleId) { newId in
            if newId.isEmpty {
                loadLastBook()
            } else {
                loadCurrentArticle()
            }
        }
        .onChange(of: currentArticleOpenToken) { _ in
            guard !resolvedCurrentArticleId.isEmpty else { return }
            loadCurrentArticle()
        }
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
                // Exclude bottom safe area + navbar so cards snap just above the bar,
                // while the TabView extends full height so swipe animation goes edge-to-edge.
                let totalH = geo.size.height
                let cardH = totalH - bottomInset + geo.safeAreaInsets.bottom

                TabView(selection: $currentIndex) {
                    ForEach(cards) { card in
                        cardContent(card: card)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 12)
                            .frame(width: w, height: cardH)
                            .rotationEffect(.degrees(-90))
                            .tag(card.id)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(width: cardH, height: w)
                .rotationEffect(.degrees(90))
                .frame(width: w, height: cardH)
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

    // MARK: - Page transition

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
        }
        if case .text = card.type {
            lastPage = card.page
        }
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
        let articleId = resolvedCurrentArticleId
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
