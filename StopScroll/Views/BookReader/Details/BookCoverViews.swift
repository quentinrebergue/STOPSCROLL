import SwiftUI

// MARK: - Book Cover Thumbnail

struct BookCoverThumbnail: View {
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

// MARK: - Book Cover Large

struct BookCoverLarge: View {
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
