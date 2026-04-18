import SwiftUI

enum XPProgress {
    static let xpPerLevel = 100

    static func level(for totalXP: Int) -> Int {
        max(1, (max(totalXP, 0) / xpPerLevel) + 1)
    }

    static func xpInCurrentLevel(for totalXP: Int) -> Int {
        max(totalXP, 0) % xpPerLevel
    }

    static func progress(for totalXP: Int) -> Double {
        Double(xpInCurrentLevel(for: totalXP)) / Double(xpPerLevel)
    }

    static func remainingToNextLevel(for totalXP: Int) -> Int {
        xpPerLevel - xpInCurrentLevel(for: totalXP)
    }
}

struct InstagramView: View {
    @State private var isLoading = true
    @State private var showingReader = false
    @State private var reloadToken = 0
    @State private var showingSettings = false
    /// Incremented when the user closes Settings so the WebView re-injects the updated label list.
    @State private var labelsToken = 0
    @AppStorage("ss_xp_total") private var totalXP = 0
    @State private var xpIslandVisible = false
    @State private var xpIslandPhase: XPIslandPhase = .compact
    @State private var xpLastGain = 0
    @State private var xpSourceLabel = "Action"
    @State private var xpHideWorkItem: DispatchWorkItem?
    @State private var xpExpandWorkItem: DispatchWorkItem?
    @State private var xpCompactWorkItem: DispatchWorkItem?
    @State private var xpIslandNudge: CGFloat = 0

    var body: some View {
        ZStack {
            InstagramWebView(
                isLoading: $isLoading,
                showingReader: $showingReader,
                showingSettings: $showingSettings,
                reloadToken: $reloadToken,
                labelsToken: $labelsToken,
                onGrantXP: { amount, source in
                    grantXP(amount: amount, source: source)
                }
            )
            .ignoresSafeArea(edges: .bottom)

            BookReaderView(onDismiss: { showingReader = false })
                .opacity(showingReader ? 1 : 0)
                .allowsHitTesting(showingReader)
                .ignoresSafeArea(edges: .bottom)

            if isLoading {
                VStack(spacing: 0) {
                    LoadingBar()
                    Spacer()
                }
                .background(Color.black.ignoresSafeArea())
                .transition(.opacity)
            }

            if xpIslandVisible {
                VStack {
                    XPDynamicIslandView(
                        gain: xpLastGain,
                        sourceLabel: xpSourceLabel,
                        level: XPProgress.level(for: totalXP),
                        progress: XPProgress.progress(for: totalXP),
                        remainingToNextLevel: XPProgress.remainingToNextLevel(for: totalXP),
                        phase: xpIslandPhase
                    )
                    .padding(.top, 8)
                    .scaleEffect(1 + xpIslandNudge, anchor: .top)
                    .offset(y: xpIslandNudge * -4)

                    Spacer()
                }
                .transition(.xpIslandOrganic)
                .zIndex(20)
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(onDismiss: {
                showingSettings = false
                labelsToken += 1  // triggers label re-injection into the live WebView
            })
        }
    }

    private func grantXP(amount: Int, source: String) {
        let safeAmount = min(max(amount, 1), 200)
        totalXP += safeAmount
        xpLastGain = safeAmount
        xpSourceLabel = source == "card_button" ? "Interaction" : "Action"

        xpHideWorkItem?.cancel()
        xpExpandWorkItem?.cancel()
        xpCompactWorkItem?.cancel()

        if xpIslandVisible {
            withAnimation(.interactiveSpring(response: 0.32, dampingFraction: 0.74, blendDuration: 0.16)) {
                xpIslandPhase = .expanded
                xpIslandNudge = 0.045
            }
            withAnimation(.easeOut(duration: 0.28).delay(0.05)) {
                xpIslandNudge = 0
            }
        } else {
            xpIslandPhase = .compact
            withAnimation(.interactiveSpring(response: 0.56, dampingFraction: 0.82, blendDuration: 0.2)) {
                xpIslandVisible = true
            }
        }

        let expandItem = DispatchWorkItem {
            withAnimation(.interactiveSpring(response: 0.5, dampingFraction: 0.84, blendDuration: 0.2)) {
                xpIslandPhase = .expanded
            }
        }
        xpExpandWorkItem = expandItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: expandItem)

        let compactItem = DispatchWorkItem {
            withAnimation(.interactiveSpring(response: 0.42, dampingFraction: 0.9, blendDuration: 0.16)) {
                xpIslandPhase = .compact
            }
        }
        xpCompactWorkItem = compactItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.72, execute: compactItem)

        let workItem = DispatchWorkItem {
            withAnimation(.easeOut(duration: 0.34)) {
                xpIslandVisible = false
            }
        }
        xpHideWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5, execute: workItem)
    }
}

// MARK: - Instagram-style loading bar

private struct LoadingBar: View {
    @State private var animating = false

    var body: some View {
        GeometryReader { geo in
            LinearGradient(
                colors: [
                    Color(red: 0.94, green: 0.58, blue: 0.20),
                    Color(red: 0.86, green: 0.15, blue: 0.26),
                    Color(red: 0.74, green: 0.09, blue: 0.53),
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: geo.size.width * 0.35)
            .offset(x: animating ? geo.size.width * 0.65 : 0)
        }
        .frame(height: 2)
        .clipped()
        .onAppear {
            withAnimation(
                .easeInOut(duration: 1.0)
                .repeatForever(autoreverses: true)
            ) {
                animating = true
            }
        }
    }
}

private struct XPDynamicIslandView: View {
    let gain: Int
    let sourceLabel: String
    let level: Int
    let progress: Double
    let remainingToNextLevel: Int
    let phase: XPIslandPhase

    var body: some View {
        let isExpanded = phase == .expanded

        return VStack(alignment: .leading, spacing: isExpanded ? 8 : 5) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("+\(gain) XP")
                    .font(.system(size: isExpanded ? 16 : 14, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                if isExpanded {
                    Text(sourceLabel)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(Color.white.opacity(0.72))
                }
                Spacer(minLength: 6)
                Text("Lv \(level)")
                    .font(.system(size: isExpanded ? 12 : 11, weight: .semibold, design: .rounded))
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
                                    Color(red: 0.40, green: 0.87, blue: 1.0),
                                    Color(red: 0.53, green: 1.0, blue: 0.68)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * clamped)
                }
            }
            .frame(height: isExpanded ? 8 : 6)

            if isExpanded {
                Text("\(remainingToNextLevel) XP before next level")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(Color.white.opacity(0.62))
            }
        }
        .padding(.horizontal, isExpanded ? 16 : 14)
        .padding(.vertical, isExpanded ? 12 : 10)
        .frame(width: isExpanded ? 320 : 178)
        .background(
            RoundedRectangle(cornerRadius: isExpanded ? 24 : 20, style: .continuous)
                .fill(Color.black.opacity(0.88))
        )
        .overlay(
            RoundedRectangle(cornerRadius: isExpanded ? 24 : 20, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.45), radius: 20, y: 6)
    }
}

private enum XPIslandPhase {
    case compact
    case expanded
}

private struct XPIslandTransitionModifier: ViewModifier {
    let opacity: Double
    let scale: CGFloat
    let yOffset: CGFloat
    let blur: CGFloat

    func body(content: Content) -> some View {
        content
            .opacity(opacity)
            .scaleEffect(scale, anchor: .top)
            .offset(y: yOffset)
            .blur(radius: blur)
    }
}

private extension AnyTransition {
    static var xpIslandOrganic: AnyTransition {
        .asymmetric(
            insertion: .modifier(
                active: XPIslandTransitionModifier(opacity: 0, scale: 0.78, yOffset: -26, blur: 9),
                identity: XPIslandTransitionModifier(opacity: 1, scale: 1, yOffset: 0, blur: 0)
            ),
            removal: .modifier(
                active: XPIslandTransitionModifier(opacity: 0, scale: 0.93, yOffset: -12, blur: 6),
                identity: XPIslandTransitionModifier(opacity: 1, scale: 1, yOffset: 0, blur: 0)
            )
        )
    }
}
