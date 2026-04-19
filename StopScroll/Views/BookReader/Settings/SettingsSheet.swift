import SwiftUI
import UniformTypeIdentifiers

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

    @State private var library: [LibraryBook] = []
    @State private var showImportFileImporter = false
    @State private var renameTarget: LibraryBook?
    @State private var renameText: String = ""
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var settings = AppSettings.shared
    private var palette: AppSettings.AdaptivePalette { settings.adaptivePalette }

    private func exportDataAsJSON() -> Data? {
        BookReaderDataTransfer.exportDataAsJSON(library: loadLibraryForExport())
    }

    private func importDataFromJSON(_ data: Data) -> Bool {
        BookReaderDataTransfer.importDataFromJSON(data)
    }

    private func loadLibraryForExport() -> [LibraryBook] {
        BookReaderDataTransfer.loadLibrary()
    }

    private func saveLibraryForExport(_ library: [LibraryBook]) {
        BookReaderDataTransfer.saveLibrary(library)
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
                                    .foregroundColor(m == mode ? palette.primaryText : palette.secondaryText)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(m.label)
                                        .foregroundColor(palette.primaryText)
                                    Text("\(m.charsPerCard) chars")
                                        .font(.caption)
                                        .foregroundColor(palette.secondaryText)
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
                            onSwitchBook(book.id)
                        } label: {
                            HStack {
                                BookCoverThumbnail(bookId: book.id)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(book.title)
                                        .foregroundColor(palette.primaryText)
                                        .lineLimit(1)
                                    HStack(spacing: 8) {
                                        Text("\(Int(book.progressPercent))%")
                                            .font(.caption)
                                            .foregroundColor(palette.secondaryText)
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
                                    .foregroundColor(palette.secondaryText)
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                onDeleteBook(book.id)
                                reloadLibrary()
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }

                            Button {
                                onResetBook(book.id)
                                reloadLibrary()
                            } label: {
                                Label("Reset", systemImage: "arrow.counterclockwise")
                            }
                            .tint(.orange)

                            Button {
                                renameTarget = book
                                renameText = book.title
                            } label: {
                                Label("Rename", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                    }
                }

                let articles = library.filter { $0.isArticle }
                if !articles.isEmpty {
                    Section("Articles") {
                        ForEach(articles) { article in
                            Button {
                                onSwitchBook(article.id)
                            } label: {
                                HStack {
                                    Image(systemName: "doc.text")
                                        .font(.system(size: 22))
                                        .foregroundColor(Color(red: 0.98, green: 0.66, blue: 0.15))
                                        .frame(width: 38, height: 38)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(article.title)
                                            .foregroundColor(palette.primaryText)
                                            .lineLimit(1)
                                        HStack(spacing: 8) {
                                            Text("\(Int(article.progressPercent))%")
                                                .font(.caption)
                                                .foregroundColor(palette.secondaryText)
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
                                        .foregroundColor(palette.secondaryText)
                                }
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    onDeleteBook(article.id)
                                    reloadLibrary()
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }

                                Button {
                                    onResetBook(article.id)
                                    reloadLibrary()
                                } label: {
                                    Label("Reset", systemImage: "arrow.counterclockwise")
                                }
                                .tint(.orange)

                                Button {
                                    renameTarget = article
                                    renameText = article.title
                                } label: {
                                    Label("Rename", systemImage: "pencil")
                                }
                                .tint(.blue)
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
                                        .foregroundColor(palette.secondaryText)
                                        .lineLimit(3)
                                    HStack(spacing: 4) {
                                        Text(card.chapterTitle.isEmpty ? "Page \(card.page)" : card.chapterTitle)
                                        Text("·")
                                        Text("p.\(card.page), Card \(card.cardIndexInPage)")
                                    }
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(palette.secondaryText)
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
            .background(palette.surface)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                reloadLibrary()
            }
            .alert("Rename Item", isPresented: Binding(
                get: { renameTarget != nil },
                set: { isPresented in
                    if !isPresented { renameTarget = nil }
                }
            )) {
                TextField("Title", text: $renameText)
                Button("Save") {
                    guard let target = renameTarget else { return }
                    let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        onRenameBook(target.id, trimmed)
                        reloadLibrary()
                    }
                    renameTarget = nil
                }
                Button("Cancel", role: .cancel) {
                    renameTarget = nil
                }
            } message: {
                Text("Choose a new title")
            }
            .fileImporter(
                isPresented: $showImportFileImporter,
                allowedContentTypes: [.json],
                onCompletion: handleImportedFile
            )
        }
    }
}
