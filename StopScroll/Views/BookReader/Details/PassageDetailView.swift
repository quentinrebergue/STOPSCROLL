import SwiftUI

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
