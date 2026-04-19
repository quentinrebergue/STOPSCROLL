import SwiftUI

struct XPDynamicIslandView: View {
    let gain: Int
    let level: Int
    let progress: Double
    let currentXPInLevel: Int
    let xpPerLevel: Int
    let infoPhase: XPInfoPhase

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Group {
                    if infoPhase == .gain {
                        Text("+\(gain) XP")
                    } else {
                        Text("\(currentXPInLevel) / \(xpPerLevel) XP")
                    }
                }
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Spacer(minLength: 6)
                Text("Lv \(level)")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(Color(red: 0.53, green: 0.88, blue: 1.0))
            }

            GeometryReader { geo in
                let clamped = max(0.0, min(1.0, progress))
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.14))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.20, green: 1.0, blue: 0.24),
                                    Color(red: 0.36, green: 1.0, blue: 0.42)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * clamped)
                }
            }
            .frame(height: 6)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(width: 164)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.black.opacity(0.88))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.45), radius: 20, y: 6)
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
