import SwiftUI

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
