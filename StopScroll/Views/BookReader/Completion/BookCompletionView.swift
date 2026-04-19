import SwiftUI

// MARK: - Completion Burst Particle

private struct CompletionParticle: Identifiable {
    let id: Int
    let color: Color
    let width: CGFloat
    let height: CGFloat
    let isCircle: Bool
    let radians: Double
    let distance: CGFloat
    let spinDeg: Double
    let burstDelay: Double

    static func makeAll() -> [CompletionParticle] {
        let palette: [Color] = [
            .white,
            Color(red: 1.0, green: 0.84, blue: 0.0),   // gold
            Color(red: 1.0, green: 0.60, blue: 0.0),   // orange
            Color(red: 1.0, green: 0.40, blue: 0.40),   // coral
            Color(red: 0.60, green: 1.0, blue: 0.20),   // lime
            Color(red: 0.0,  green: 1.0, blue: 0.62),   // spring green
            Color(red: 0.0,  green: 0.75, blue: 1.0),   // sky blue
            Color(red: 0.78, green: 0.48, blue: 1.0),   // lavender
            Color(red: 1.0,  green: 0.85, blue: 0.10),  // yellow
        ]
        return (0..<60).map { i in
            let angle = (Double(i) / 60.0) * 2.0 * .pi + Double.random(in: -0.18...0.18)
            let isCircle = i % 3 != 0
            let w: CGFloat = isCircle ? CGFloat.random(in: 7...14) : CGFloat.random(in: 5...9)
            let h: CGFloat = isCircle ? w : CGFloat.random(in: 14...24)
            return CompletionParticle(
                id: i,
                color: palette[i % palette.count],
                width: w, height: h,
                isCircle: isCircle,
                radians: angle,
                distance: CGFloat.random(in: 130...270),
                spinDeg: Double.random(in: -200...200),
                burstDelay: Double.random(in: 0...0.10)
            )
        }
    }
}

// MARK: - Book Completion View

struct BookCompletionView: View {
    let bookTitle: String
    let isArticle: Bool
    let hasCurrentBook: Bool
    let onDismiss: () -> Void
    let onSwitchToBook: () -> Void

    @State private var expanded = false
    @State private var faded = false
    @State private var appeared = false

    private static let particles = CompletionParticle.makeAll()

    var body: some View {
        GeometryReader { geo in
            let cx = geo.size.width / 2
            let cy = geo.size.height * 0.42  // burst origin near checkmark

            ZStack {
                // ── Vivid green gradient background ──────────────────
                LinearGradient(
                    colors: [
                        Color(red: 0.01, green: 0.30, blue: 0.16),
                        Color(red: 0.04, green: 0.52, blue: 0.27),
                        Color(red: 0.08, green: 0.75, blue: 0.40),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                // Subtle radial glow behind burst origin
                RadialGradient(
                    colors: [Color.white.opacity(0.18), Color.clear],
                    center: .init(x: cx / geo.size.width, y: cy / geo.size.height),
                    startRadius: 0,
                    endRadius: 180
                )
                .ignoresSafeArea()

                // ── Burst particles ───────────────────────────────────
                ForEach(Self.particles) { p in
                    let dx = cos(p.radians) * p.distance * (expanded ? 1 : 0)
                    let dy = sin(p.radians) * p.distance * (expanded ? 1 : 0)
                    Group {
                        if p.isCircle {
                            Circle().fill(p.color)
                        } else {
                            RoundedRectangle(cornerRadius: 2).fill(p.color)
                        }
                    }
                    .frame(width: p.width, height: p.height)
                    .rotationEffect(.degrees(expanded ? p.spinDeg : 0))
                    .position(x: cx + dx, y: cy + dy)
                    .opacity(faded ? 0 : (expanded ? 1 : 0))
                    .animation(
                        .spring(response: 0.55, dampingFraction: 0.72)
                            .delay(p.burstDelay),
                        value: expanded
                    )
                    .animation(.easeOut(duration: 0.5), value: faded)
                }

                // ── Content ───────────────────────────────────────────
                VStack(spacing: 0) {
                    Spacer()

                    // Checkmark circle
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.16))
                            .frame(width: 128, height: 128)
                        Circle()
                            .stroke(Color.white.opacity(0.32), lineWidth: 1.5)
                            .frame(width: 128, height: 128)
                        Image(systemName: "checkmark")
                            .font(.system(size: 58, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .scaleEffect(appeared ? 1 : 0.15)
                    .opacity(appeared ? 1 : 0)
                    .animation(.spring(response: 0.48, dampingFraction: 0.52).delay(0.10), value: appeared)

                    Spacer().frame(height: 32)

                    // Congratulations heading
                    Text("Congratulations!")
                        .font(.system(size: 36, weight: .black))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .scaleEffect(appeared ? 1 : 0.5)
                        .opacity(appeared ? 1 : 0)
                        .animation(.spring(response: 0.5, dampingFraction: 0.62).delay(0.24), value: appeared)

                    Spacer().frame(height: 10)

                    // "You finished …" sub-heading
                    Text(isArticle ? "You read the full article" : "You finished the book")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white.opacity(0.70))
                        .opacity(appeared ? 1 : 0)
                        .animation(.easeOut(duration: 0.4).delay(0.36), value: appeared)

                    Spacer().frame(height: 8)

                    // Book / article title
                    Text(bookTitle)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white.opacity(0.55))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .lineLimit(2)
                        .opacity(appeared ? 1 : 0)
                        .animation(.easeOut(duration: 0.4).delay(0.44), value: appeared)

                    Spacer()

                    // Back to feed / Continue reading button
                    Button(action: isArticle && hasCurrentBook ? onSwitchToBook : onDismiss) {
                        Text(isArticle && hasCurrentBook ? "Continue reading" : "Back to feed")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(Color(red: 0.04, green: 0.38, blue: 0.20))
                            .padding(.horizontal, 52)
                            .padding(.vertical, 17)
                            .background(Color.white)
                            .clipShape(Capsule())
                            .shadow(color: .black.opacity(0.18), radius: 12, y: 4)
                    }
                    .offset(y: appeared ? 0 : 48)
                    .opacity(appeared ? 1 : 0)
                    .animation(.spring(response: 0.52, dampingFraction: 0.78).delay(0.58), value: appeared)

                    Spacer().frame(height: 64)
                }
                .padding(.horizontal, 32)
            }
        }
        .onAppear {
            // Fire burst
            withAnimation { expanded = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                withAnimation { faded = true }
            }
            // Content entrance
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                appeared = true
            }
            // Auto-switch to book after 4 s when finishing an article
            if isArticle && hasCurrentBook {
                DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                    onSwitchToBook()
                }
            }
        }
    }
}
