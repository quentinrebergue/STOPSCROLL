import SwiftUI

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
