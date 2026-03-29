import SwiftUI
import UniformTypeIdentifiers

// MARK: - Book Reader View

struct BookReaderView: View {
    let onDismiss: () -> Void

    @State private var cards: [BookCard] = []
    @State private var currentIndex: Int = 0
    @State private var showFilePicker = false
    @State private var bookTitle: String = ""
    @State private var bookmarkedIds: Set<Int> = []
    @State private var showModeSelector = false
    @State private var sessionCardsRead: Int = 0
    @State private var showPageComplete = false
    @State private var lastPage: Int = 0

    @AppStorage("savedCardIndex") private var savedCardIndex: Int = 0
    @AppStorage("savedBookTitle") private var savedBookTitle: String = ""
    @AppStorage("readingMode") private var readingModeRaw: String = ReadingMode.flow.rawValue

    private var mode: ReadingMode {
        ReadingMode(rawValue: readingModeRaw) ?? .flow
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

            // Page complete animation overlay
            if showPageComplete {
                pageCompleteOverlay
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
        .onAppear {
            loadLastBook()
            loadBookmarks()
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

            // Mode selector in empty state
            modeSelector
                .padding(.top, 10)

            Spacer()
        }
    }

    // MARK: - Mode selector

    private var modeSelector: some View {
        HStack(spacing: 16) {
            ForEach(ReadingMode.allCases) { m in
                Button {
                    readingModeRaw = m.rawValue
                    reloadWithMode(m)
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: m.icon)
                            .font(.system(size: 20))
                        Text(m.label)
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(m == mode ? .white : Color(white: 0.45))
                    .frame(width: 70, height: 56)
                    .background(m == mode ? Color(white: 0.18) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }

    // MARK: - Reader content

    private var readerContent: some View {
        VStack(spacing: 0) {
            // Header with title + mode + session counter
            VStack(spacing: 2) {
                HStack {
                    Text(bookTitle)
                        .font(.headline)
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Spacer()

                    // Session counter
                    Text("\(sessionCardsRead) cards")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(Color(white: 0.4))
                        .padding(.trailing, 8)

                    Button {
                        showFilePicker = true
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 16))
                            .foregroundColor(Color(white: 0.55))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)

                // Mode pills + progress bar
                HStack(spacing: 0) {
                    // Compact mode switcher
                    HStack(spacing: 8) {
                        ForEach(ReadingMode.allCases) { m in
                            Button {
                                readingModeRaw = m.rawValue
                                reloadWithMode(m)
                            } label: {
                                Image(systemName: m.icon)
                                    .font(.system(size: 13))
                                    .foregroundColor(m == mode ? .white : Color(white: 0.35))
                                    .padding(6)
                                    .background(m == mode ? Color(white: 0.2) : Color.clear)
                                    .clipShape(Circle())
                            }
                        }
                    }
                    .padding(.leading, 16)

                    Spacer()

                    // Page progress (Stories-style)
                    if let currentCard = cards.indices.contains(currentIndex) ? cards[currentIndex] : nil,
                       case .text = currentCard.type {
                        pageProgressBar(currentCard: currentCard)
                            .padding(.trailing, 16)
                    }
                }
                .padding(.vertical, 4)
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
                .onChange(of: currentIndex) { newValue in
                    savedCardIndex = newValue
                    sessionCardsRead += 1
                    checkPageTransition()
                }
            }
        }
    }

    // MARK: - Card content (text vs chapter)

    @ViewBuilder
    private func cardContent(card: BookCard) -> some View {
        switch card.type {
        case .chapterStart(let title, let number):
            ChapterCard(title: title, chapterNumber: number)
        case .text:
            TextCardView(
                card: card,
                mode: mode,
                isBookmarked: bookmarkedIds.contains(card.id),
                onBookmark: { toggleBookmark(card.id) }
            )
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

        return HStack(spacing: 2) {
            Text("p.\(page)")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(Color(white: 0.4))
                .frame(width: 26)

            ForEach(0..<total, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(i < currentOnPage ? Color.white : Color(white: 0.25))
                    .frame(height: 3)
            }
        }
        .frame(width: 160)
    }

    // MARK: - Page complete overlay

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
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                withAnimation(.easeOut(duration: 0.3)) {
                    showPageComplete = false
                }
            }
        }
    }

    // MARK: - Page transition detection

    private func checkPageTransition() {
        guard cards.indices.contains(currentIndex) else { return }
        let card = cards[currentIndex]
        if case .text = card.type, card.page != lastPage, lastPage > 0 {
            withAnimation(.spring(response: 0.4)) {
                showPageComplete = true
            }
        }
        if case .text = card.type {
            lastPage = card.page
        }
    }

    // MARK: - Bottom bar (mimics Instagram nav)

    private var bottomBar: some View {
        HStack {
            Spacer()
            navButton(icon: "house", isActive: false) { onDismiss() }
            Spacer()
            navButton(icon: "magnifyingglass", isActive: false) { onDismiss() }
            Spacer()
            navButton(icon: "book.fill", isActive: true) { }
            Spacer()
            navButton(icon: "bag", isActive: false) { onDismiss() }
            Spacer()
            navButton(icon: "person.circle", isActive: false) { onDismiss() }
            Spacer()
        }
        .padding(.top, 10)
        .padding(.bottom, 20)
        .background(Color.black)
        .overlay(
            Rectangle()
                .fill(Color(white: 0.2))
                .frame(height: 0.5),
            alignment: .top
        )
    }

    private func navButton(icon: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(isActive ? .white : Color(white: 0.55))
        }
    }

    // MARK: - Bookmarks

    private func toggleBookmark(_ id: Int) {
        if bookmarkedIds.contains(id) {
            bookmarkedIds.remove(id)
        } else {
            bookmarkedIds.insert(id)
        }
        saveBookmarks()
    }

    private func saveBookmarks() {
        UserDefaults.standard.set(Array(bookmarkedIds), forKey: "bookmarks")
    }

    private func loadBookmarks() {
        let saved = UserDefaults.standard.array(forKey: "bookmarks") as? [Int] ?? []
        bookmarkedIds = Set(saved)
    }

    // MARK: - Book loading

    private func loadBook(from url: URL) {
        let currentMode = mode
        DispatchQueue.global(qos: .userInitiated).async {
            guard let result = BookParser.loadBook(from: url, mode: currentMode) else { return }
            let bookmark = try? url.bookmarkData(options: .minimalBookmark)
            DispatchQueue.main.async {
                cards = result.cards
                bookTitle = result.title
                savedBookTitle = result.title
                currentIndex = 0
                savedCardIndex = 0
                sessionCardsRead = 0
                lastPage = 0
                if let bookmark {
                    UserDefaults.standard.set(bookmark, forKey: "lastBookBookmark")
                }
            }
        }
    }

    private func loadLastBook() {
        guard let bookmarkData = UserDefaults.standard.data(forKey: "lastBookBookmark") else { return }
        var isStale = false
        guard let url = try? URL(resolvingBookmarkData: bookmarkData, bookmarkDataIsStale: &isStale) else { return }
        let currentMode = mode
        DispatchQueue.global(qos: .userInitiated).async {
            guard let result = BookParser.loadBook(from: url, mode: currentMode) else { return }
            DispatchQueue.main.async {
                cards = result.cards
                bookTitle = savedBookTitle.isEmpty ? result.title : savedBookTitle
                currentIndex = min(savedCardIndex, max(0, cards.count - 1))
                if let card = cards.indices.contains(currentIndex) ? cards[currentIndex] : nil,
                   case .text = card.type {
                    lastPage = card.page
                }
            }
        }
    }

    private func reloadWithMode(_ newMode: ReadingMode) {
        guard let bookmarkData = UserDefaults.standard.data(forKey: "lastBookBookmark") else { return }
        var isStale = false
        guard let url = try? URL(resolvingBookmarkData: bookmarkData, bookmarkDataIsStale: &isStale) else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            guard let result = BookParser.loadBook(from: url, mode: newMode) else { return }
            DispatchQueue.main.async {
                // Try to keep approximate position
                let progress = cards.isEmpty ? 0.0 : Double(currentIndex) / Double(cards.count)
                cards = result.cards
                let newIdx = min(Int(progress * Double(cards.count)), max(0, cards.count - 1))
                currentIndex = newIdx
                savedCardIndex = newIdx
            }
        }
    }
}

// MARK: - Text Card View (with double-tap bookmark)

struct TextCardView: View {
    let card: BookCard
    let mode: ReadingMode
    let isBookmarked: Bool
    let onBookmark: () -> Void

    @State private var showBookmarkAnimation = false

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Card header
                HStack {
                    Text("Card \(card.cardNumber) / \(card.totalCards)")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(Color(white: 0.4))

                    Spacer()

                    if isBookmarked {
                        Image(systemName: "bookmark.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.yellow)
                            .padding(.trailing, 4)
                    }

                    Text("Page \(card.page)")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(Color(white: 0.4))
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 6)

                // Separator
                Rectangle()
                    .fill(Color(white: 0.15))
                    .frame(height: 0.5)
                    .padding(.horizontal, 20)

                // Card text — Charter font, mode-adaptive sizing
                Text(card.text)
                    .font(.custom("Charter", size: mode.fontSize))
                    .foregroundColor(Color(white: 0.92))
                    .lineSpacing(mode.lineSpacing)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(.horizontal, 22)
                    .padding(.top, 18)
                    .padding(.bottom, 20)

                Spacer(minLength: 0)
            }

            // Bookmark animation
            if showBookmarkAnimation {
                Image(systemName: "bookmark.fill")
                    .font(.system(size: 72))
                    .foregroundColor(.yellow.opacity(0.85))
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .background(Color(white: 0.09))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .onTapGesture(count: 2) {
            onBookmark()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                showBookmarkAnimation = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                withAnimation(.easeOut(duration: 0.2)) {
                    showBookmarkAnimation = false
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

            Text("Chapter \(chapterNumber)")
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundColor(Color.white.opacity(0.6))
                .textCase(.uppercase)
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
