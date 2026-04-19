import SwiftUI

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
