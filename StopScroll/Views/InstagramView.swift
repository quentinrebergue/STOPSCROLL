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
    @State private var xpLastGain = 0
    @State private var xpHideWorkItem: DispatchWorkItem?
    @State private var xpProgressWorkItem: DispatchWorkItem?
    @State private var xpInfoWorkItem: DispatchWorkItem?
    @State private var xpIslandNudge: CGFloat = 0
    @State private var xpDisplayedProgress: Double = 0
    @State private var xpInfoPhase: XPInfoPhase = .gain

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
                GeometryReader { geo in
                    let cutoutStyle = XPCutoutStyle.from(topInset: geo.safeAreaInsets.top)
                    let cutoutTopOffset: CGFloat = cutoutStyle == .dynamicIsland ? 4 : 6

                    VStack(spacing: 0) {
                        XPCutoutAnchorView(style: cutoutStyle)

                        XPDynamicIslandView(
                            gain: xpLastGain,
                            level: XPProgress.level(for: totalXP),
                            progress: xpDisplayedProgress,
                            currentXPInLevel: XPProgress.xpInCurrentLevel(for: totalXP),
                            xpPerLevel: XPProgress.xpPerLevel,
                            infoPhase: xpInfoPhase
                        )
                        .padding(.top, 2)
                        .scaleEffect(1 + xpIslandNudge, anchor: .top)
                        .offset(y: xpIslandNudge * -3)

                        Spacer(minLength: 0)
                    }
                    .padding(.top, cutoutTopOffset)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .compositingGroup()
                }
                .ignoresSafeArea(edges: .top)
                .transition(.xpIslandOrganic)
                .zIndex(20)
                .allowsHitTesting(false)
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
        let previousTotal = totalXP
        totalXP += safeAmount
        let targetProgress = XPProgress.progress(for: totalXP)
        xpLastGain = safeAmount
        _ = source // reserved for future reward categories
        xpInfoPhase = .gain

        xpHideWorkItem?.cancel()
        xpProgressWorkItem?.cancel()
        xpInfoWorkItem?.cancel()

        if xpIslandVisible {
            withAnimation(.interactiveSpring(response: 0.32, dampingFraction: 0.74, blendDuration: 0.16)) {
                xpIslandNudge = 0.045
            }
            withAnimation(.easeOut(duration: 0.28).delay(0.05)) {
                xpIslandNudge = 0
            }
            // Island already visible: animate from previous level ratio to target ratio.
            xpDisplayedProgress = XPProgress.progress(for: previousTotal)
            let progressItem = DispatchWorkItem {
                withAnimation(.easeOut(duration: 0.42)) {
                    xpDisplayedProgress = targetProgress
                }
            }
            xpProgressWorkItem = progressItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08, execute: progressItem)
        } else {
            // Two-step behavior: first island appears, then bar fills.
            xpDisplayedProgress = 0
            withAnimation(.interactiveSpring(response: 0.56, dampingFraction: 0.82, blendDuration: 0.2)) {
                xpIslandVisible = true
            }

            let progressItem = DispatchWorkItem {
                withAnimation(.easeOut(duration: 0.48)) {
                    xpDisplayedProgress = targetProgress
                }
            }
            xpProgressWorkItem = progressItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.34, execute: progressItem)
        }

        // Minimal timeline: quick gain text, then current/required XP ratio.
        let infoItem = DispatchWorkItem {
            withAnimation(.easeOut(duration: 0.2)) {
                xpInfoPhase = .progress
            }
        }
        xpInfoWorkItem = infoItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.72, execute: infoItem)

        let workItem = DispatchWorkItem {
            withAnimation(.easeOut(duration: 0.34)) {
                xpIslandVisible = false
            }
        }
        xpHideWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.15, execute: workItem)
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

private enum XPInfoPhase {
    case gain
    case progress
}

private enum XPCutoutStyle {
    case dynamicIsland
    case notch

    static func from(topInset: CGFloat) -> XPCutoutStyle {
        topInset >= 55 ? .dynamicIsland : .notch
    }
}

private struct XPCutoutAnchorView: View {
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

private extension AnyTransition {
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
