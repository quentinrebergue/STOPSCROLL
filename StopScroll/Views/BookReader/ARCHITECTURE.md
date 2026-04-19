# BookReader Architecture

This folder is organized by feature responsibility to keep reading logic, UI components, and persistence isolated.

## Tree

- `Core/BookReaderView.swift`
- `Core/BookReaderTypes.swift`
- `Settings/SettingsSheet.swift`
- `Settings/BookReaderDataTransfer.swift`
- `Settings/BookDetailSheet.swift`
- `Models/StoredChapter.swift`
- `Models/LibraryBook.swift`
- `Progress/ProgressViews.swift`
- `Components/TextCardView.swift`
- `Components/ChapterCard.swift`
- `Details/PassageDetailView.swift`
- `Details/BookCoverViews.swift`
- `Completion/BookCompletionView.swift`

## File roles

- `Core/BookReaderView.swift`: Main reader screen orchestration (state, navigation, progress, bookmarks, loading).
- `Core/BookReaderTypes.swift`: File type support and article-id resolution helpers used by BookReaderView.
- `Settings/SettingsSheet.swift`: Reader settings UI (reading mode, library actions, import/export entry points).
- `Settings/BookReaderDataTransfer.swift`: Data import/export + library persistence helpers for SettingsSheet.
- `Settings/BookDetailSheet.swift`: Single-book action sheet (open, rename, reset, delete).
- `Models/StoredChapter.swift`: Persisted chapter format and BookStorage file persistence for chapters/covers.
- `Models/LibraryBook.swift`: Persisted library metadata model and progress computation.
- `Progress/ProgressViews.swift`: Page/chapter progress visuals and reset/confetti animation internals.
- `Components/TextCardView.swift`: Text card rendering and bookmark gesture animation.
- `Components/ChapterCard.swift`: Chapter and section transition cards.
- `Details/PassageDetailView.swift`: Saved passage detailed view.
- `Details/BookCoverViews.swift`: Thumbnail and large cover components.
- `Completion/BookCompletionView.swift`: Final completion celebration screen.

## Design notes

- UI composition is split into small focused views to reduce merge conflicts.
- Persistence models live under `Models/` to separate app state from rendering code.
- Heavy utility logic is extracted from large views into helper files for easier testing.
