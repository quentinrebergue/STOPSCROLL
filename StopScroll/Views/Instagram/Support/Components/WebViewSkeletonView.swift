import SwiftUI

// MARK: - Shimmer block

/// A single skeleton block (rect or circle) that participates in a shared shimmer phase.
private struct SkeletonBlock: View {
    var width: CGFloat? = nil
    var height: CGFloat
    var cornerRadius: CGFloat = 8
    var isCircle: Bool = false
    var phase: CGFloat = 0
    var isDark: Bool = true

    var body: some View {
        let base: Color    = isDark ? .white.opacity(0.09) : .black.opacity(0.07)
        let shimmer: Color = isDark ? .white.opacity(0.20) : .black.opacity(0.14)
        let gradient = LinearGradient(
            stops: [
                .init(color: .clear,   location: phase - 0.3),
                .init(color: shimmer,  location: phase),
                .init(color: .clear,   location: phase + 0.3)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
        if isCircle {
            Circle().fill(base)
                .overlay(Circle().fill(gradient))
                .frame(width: width ?? height, height: height)
        } else {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).fill(base)
                .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).fill(gradient))
                .frame(width: width, height: height)
        }
    }
}

// MARK: - Feed / Home skeleton

private struct FeedSkeleton: View {
    let phase: CGFloat
    let isDark: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Stories row
            HStack(spacing: 14) {
                ForEach(0..<5, id: \.self) { _ in
                    VStack(spacing: 6) {
                        SkeletonBlock(height: 58, isCircle: true, phase: phase, isDark: isDark)
                        SkeletonBlock(width: 44, height: 9, cornerRadius: 4, phase: phase, isDark: isDark)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)

            Divider().opacity(isDark ? 0.06 : 0.08)

            postBlock
            Divider().opacity(isDark ? 0.06 : 0.08)
            postBlock

            Spacer()
        }
    }

    private var postBlock: some View {
        VStack(spacing: 0) {
            // Header row
            HStack(spacing: 10) {
                SkeletonBlock(height: 36, isCircle: true, phase: phase, isDark: isDark)
                VStack(alignment: .leading, spacing: 5) {
                    SkeletonBlock(width: 110, height: 13, cornerRadius: 5, phase: phase, isDark: isDark)
                    SkeletonBlock(width: 70, height: 10, cornerRadius: 4, phase: phase, isDark: isDark)
                }
                Spacer()
                SkeletonBlock(width: 22, height: 14, cornerRadius: 4, phase: phase, isDark: isDark)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            // Image block
            SkeletonBlock(height: 220, cornerRadius: 0, phase: phase, isDark: isDark)
                .frame(maxWidth: .infinity)

            // Actions row
            HStack {
                HStack(spacing: 18) {
                    ForEach(0..<3, id: \.self) { _ in
                        SkeletonBlock(width: 26, height: 22, cornerRadius: 5, phase: phase, isDark: isDark)
                    }
                }
                Spacer()
                SkeletonBlock(width: 22, height: 22, cornerRadius: 5, phase: phase, isDark: isDark)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
    }
}

// MARK: - Messages skeleton

private struct MessagesSkeleton: View {
    let phase: CGFloat
    let isDark: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Search/filter bar
            SkeletonBlock(height: 36, cornerRadius: 12, phase: phase, isDark: isDark)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)

            ForEach(0..<9, id: \.self) { _ in
                HStack(spacing: 12) {
                    SkeletonBlock(height: 52, isCircle: true, phase: phase, isDark: isDark)
                    VStack(alignment: .leading, spacing: 6) {
                        SkeletonBlock(width: 130, height: 13, cornerRadius: 5, phase: phase, isDark: isDark)
                        SkeletonBlock(height: 11, cornerRadius: 4, phase: phase, isDark: isDark)
                            .frame(maxWidth: 200)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 6) {
                        SkeletonBlock(width: 34, height: 10, cornerRadius: 4, phase: phase, isDark: isDark)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
            }

            Spacer()
        }
    }
}

// MARK: - Search / Explore skeleton

private struct SearchSkeleton: View {
    let phase: CGFloat
    let isDark: Bool

    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            SkeletonBlock(height: 36, cornerRadius: 12, phase: phase, isDark: isDark)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)

            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(0..<18, id: \.self) { _ in
                    SkeletonBlock(height: 130, cornerRadius: 1, phase: phase, isDark: isDark)
                        .frame(maxWidth: .infinity)
                }
            }

            Spacer()
        }
    }
}

// MARK: - Reels skeleton

private struct ReelsSkeleton: View {
    let phase: CGFloat
    let isDark: Bool

    var body: some View {
        ZStack {
            // Right action column
            VStack(spacing: 22) {
                Spacer()
                ForEach(0..<4, id: \.self) { _ in
                    VStack(spacing: 5) {
                        SkeletonBlock(height: 34, isCircle: true, phase: phase, isDark: isDark)
                        SkeletonBlock(width: 26, height: 9, cornerRadius: 4, phase: phase, isDark: isDark)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.trailing, 12)
            .padding(.bottom, 100)

            // Bottom-left: username + caption + sound
            VStack(alignment: .leading, spacing: 8) {
                SkeletonBlock(width: 130, height: 14, cornerRadius: 6, phase: phase, isDark: isDark)
                SkeletonBlock(height: 11, cornerRadius: 4, phase: phase, isDark: isDark)
                    .frame(maxWidth: 220)
                SkeletonBlock(height: 11, cornerRadius: 4, phase: phase, isDark: isDark)
                    .frame(maxWidth: 170)
                HStack(spacing: 8) {
                    SkeletonBlock(height: 20, isCircle: true, phase: phase, isDark: isDark)
                    SkeletonBlock(width: 140, height: 11, cornerRadius: 4, phase: phase, isDark: isDark)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            .padding(.leading, 14)
            .padding(.bottom, 110)
        }
    }
}

// MARK: - Profile skeleton

private struct ProfileSkeleton: View {
    let phase: CGFloat
    let isDark: Bool

    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Avatar + stats
            HStack(alignment: .center) {
                SkeletonBlock(height: 80, isCircle: true, phase: phase, isDark: isDark)
                    .padding(.leading, 16)

                Spacer()

                ForEach(0..<3, id: \.self) { _ in
                    VStack(spacing: 5) {
                        SkeletonBlock(width: 38, height: 18, cornerRadius: 6, phase: phase, isDark: isDark)
                        SkeletonBlock(width: 52, height: 10, cornerRadius: 4, phase: phase, isDark: isDark)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical, 18)
            .padding(.trailing, 16)

            // Name + bio lines
            VStack(alignment: .leading, spacing: 7) {
                SkeletonBlock(width: 130, height: 14, cornerRadius: 5, phase: phase, isDark: isDark)
                SkeletonBlock(height: 11, cornerRadius: 4, phase: phase, isDark: isDark)
                    .frame(maxWidth: 240)
                SkeletonBlock(height: 11, cornerRadius: 4, phase: phase, isDark: isDark)
                    .frame(maxWidth: 170)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.bottom, 14)

            // Edit profile / Follow button
            SkeletonBlock(height: 34, cornerRadius: 10, phase: phase, isDark: isDark)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 16)
                .padding(.bottom, 14)

            // Photo grid
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(0..<12, id: \.self) { _ in
                    SkeletonBlock(height: 125, cornerRadius: 0, phase: phase, isDark: isDark)
                        .frame(maxWidth: .infinity)
                }
            }

            Spacer()
        }
    }
}

// MARK: - Entry point

struct WebViewSkeletonView: View {
    let surface: WebSurface
    let isDark: Bool

    @State private var phase: CGFloat = -0.3

    var body: some View {
        Group {
            switch surface {
            case .main:     FeedSkeleton(phase: phase, isDark: isDark)
            case .messages: MessagesSkeleton(phase: phase, isDark: isDark)
            case .search:   SearchSkeleton(phase: phase, isDark: isDark)
            case .reels:    ReelsSkeleton(phase: phase, isDark: true)   // reels always dark
            case .profile:  ProfileSkeleton(phase: phase, isDark: isDark)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            withAnimation(.linear(duration: 1.6).repeatForever(autoreverses: false)) {
                phase = 1.3
            }
        }
    }
}
