import SwiftUI

struct XPDynamicIslandView: View {
    let gain: Int
    let level: Int
    let progress: Double
    let currentXPInLevel: Int
    let xpPerLevel: Int
    let infoPhase: XPInfoPhase

    var body: some View {
        HStack(spacing: 12) {
            metricItem(
                label: "XP gagné",
                value: infoPhase == .gain ? "+\(gain)" : "\(currentXPInLevel)/\(xpPerLevel)",
                color: Color(red: 0.28, green: 0.92, blue: 0.46)
            )
            divider
            metricItem(
                label: "Niveau",
                value: "\(level)",
                color: Color(red: 0.53, green: 0.88, blue: 1.0)
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.25), radius: 10, x: 0, y: 4)
        )
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.18))
            .frame(width: 1, height: 18)
    }

    private func metricItem(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundColor(Color.white.opacity(0.5))
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(color)
        }
    }
}

enum XPInfoPhase {
    case gain
    case progress
}

enum XPCutoutStyle {
    case dynamicIsland
    case notch

    static func from(topInset: CGFloat) -> XPCutoutStyle {
        topInset >= 55 ? .dynamicIsland : .notch
    }
}

struct XPCutoutAnchorView: View {
    let style: XPCutoutStyle

    var body: some View {
        Group {
            if style == .dynamicIsland {
                Capsule(style: .continuous)
                    .fill(Color.black)
                    .frame(width: 126, height: 35)
            } else {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(Color.black)
                    .frame(width: 170, height: 28)
            }
        }
        .shadow(color: Color.black.opacity(0.3), radius: 2, y: 1)
    }
}

private struct XPIslandTransitionModifier: ViewModifier {
    let opacity: Double
    let scale: CGFloat
    let yOffset: CGFloat

    func body(content: Content) -> some View {
        content
            .opacity(opacity)
            .scaleEffect(scale, anchor: .top)
            .offset(y: yOffset)
    }
}

extension AnyTransition {
    /// Classic iOS notification banner: springs in from above with slight overshoot, snaps back up on dismiss.
    static var appleNotificationBanner: AnyTransition {
        .asymmetric(
            insertion: .modifier(
                active:   XPIslandTransitionModifier(opacity: 0, scale: 0.88, yOffset: -80),
                identity: XPIslandTransitionModifier(opacity: 1, scale: 1,    yOffset: 0)
            ),
            removal: .modifier(
                active:   XPIslandTransitionModifier(opacity: 0, scale: 0.94, yOffset: -50),
                identity: XPIslandTransitionModifier(opacity: 1, scale: 1,    yOffset: 0)
            )
        )
    }

    static var xpIslandOrganic: AnyTransition {
        .asymmetric(
            insertion: .modifier(
                active: XPIslandTransitionModifier(opacity: 0, scale: 0.82, yOffset: -20),
                identity: XPIslandTransitionModifier(opacity: 1, scale: 1, yOffset: 0)
            ),
            removal: .modifier(
                active: XPIslandTransitionModifier(opacity: 0, scale: 0.96, yOffset: -8),
                identity: XPIslandTransitionModifier(opacity: 1, scale: 1, yOffset: 0)
            )
        )
    }
}
