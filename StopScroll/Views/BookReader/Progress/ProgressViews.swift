import SwiftUI

// MARK: - Page Progress Reset Config

enum PageProgressResetConfig {
    static let delayPerSegment: Double = 0.12
    static let barDuration: Double = 0.3
    static let unifiedSwitchDelay: Double = 0.0
    static let mergeDuration: Double = 0.1
    static let postMergeDelay: Double = 0.2
    static let unifiedSpeedMultiplier: Double = 0.5
    static let mergeInnerOverlap: CGFloat = 1.2

    static func totalSpan(for segmentCount: Int) -> Double {
        delayPerSegment * Double(max(segmentCount - 1, 0))
    }

    static func totalDuration(for segmentCount: Int) -> Double {
        totalSpan(for: segmentCount) + barDuration
    }

    static func unifiedResetDuration(for segmentCount: Int) -> Double {
        max(totalDuration(for: segmentCount) * unifiedSpeedMultiplier, 0.12)
    }
}

// MARK: - Progress Bar Confetti

private struct ConfettiParticle: Identifiable {
    let id = UUID()
    let x: CGFloat
    let y: CGFloat
    let size: CGFloat
}

struct ProgressBarConfettiView: View {
    let horizontalDirection: CGFloat
    let verticalDirection: CGFloat
    @State private var burst = false

    private let particles: [ConfettiParticle] = [
        .init(x: -15, y: -9, size: 2),
        .init(x: -7, y: 6, size: 2),
        .init(x: 5, y: -7, size: 2),
        .init(x: 13, y: 8, size: 2)
    ]

    private func targetX(for particle: ConfettiParticle) -> CGFloat {
        if horizontalDirection == 0 { return particle.x }
        return abs(particle.x) * horizontalDirection
    }

    private func targetY(for particle: ConfettiParticle) -> CGFloat {
        if verticalDirection == 0 { return particle.y }
        return abs(particle.y) * verticalDirection
    }

    var body: some View {
        ZStack {
            ForEach(particles) { particle in
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.green)
                    .frame(width: particle.size, height: particle.size + 1)
                    .offset(
                        x: burst ? targetX(for: particle) : 0,
                        y: burst ? targetY(for: particle) : 0
                    )
                    .opacity(burst ? 0 : 1)
            }
        }
        .frame(width: 24, height: 18)
        .onAppear {
            withAnimation(.easeOut(duration: 0.3)) {
                burst = true
            }
        }
    }
}

struct ProgressBarConfettiBurstOverlay: View {
    private let horizontalEmitters: [CGFloat] = [0.02, 0.5, 0.98]
    private let verticalSideEmitters: [CGFloat] = [0.5]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(Array(horizontalEmitters.enumerated()), id: \.offset) { _, fraction in
                    ProgressBarConfettiView(horizontalDirection: 0, verticalDirection: -1)
                        .position(x: geo.size.width * fraction, y: 0)
                }

                ForEach(Array(horizontalEmitters.enumerated()), id: \.offset) { _, fraction in
                    ProgressBarConfettiView(horizontalDirection: 0, verticalDirection: 1)
                        .position(x: geo.size.width * fraction, y: geo.size.height)
                }

                ForEach(Array(verticalSideEmitters.enumerated()), id: \.offset) { _, fraction in
                    ProgressBarConfettiView(horizontalDirection: -1, verticalDirection: 0)
                        .position(x: 0, y: geo.size.height * fraction)
                }

                ForEach(Array(verticalSideEmitters.enumerated()), id: \.offset) { _, fraction in
                    ProgressBarConfettiView(horizontalDirection: 1, verticalDirection: 0)
                        .position(x: geo.size.width, y: geo.size.height * fraction)
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Page Progress Segment View

struct PageProgressSegmentView: View {
    let index: Int
    let total: Int
    let currentOnPage: Int
    let celebrate: Bool
    let resetActive: Bool
    let resetStart: Date?
    let mergeSegments: Bool

    private var normalFill: CGFloat {
        index < currentOnPage ? 1 : 0
    }

    private var mergeOverlap: CGFloat {
        guard mergeSegments, index > 0, index < total - 1 else { return 0 }
        return PageProgressResetConfig.mergeInnerOverlap
    }

    private func fillAmount(at now: Date) -> CGFloat {
        if celebrate {
            return 1
        }
        if resetActive {
            if index == 0 {
                return 1
            }

            guard let resetStart else { return normalFill }
            let totalSpan = PageProgressResetConfig.totalSpan(for: total)
            let barDuration = PageProgressResetConfig.barDuration
            let delayStep = totalSpan / Double(max(total - 1, 1))
            let stepsFromRight = Double(total - 1 - index)
            let delay = stepsFromRight * delayStep
            let elapsed = now.timeIntervalSince(resetStart)

            if elapsed <= delay {
                return 1
            }

            let localT = min(max((elapsed - delay) / barDuration, 0), 1)
            return CGFloat(1 - localT)
        }
        return normalFill
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Color(white: 0.25))
                        .frame(width: geo.size.width + mergeOverlap)
                        .offset(x: -mergeOverlap / 2)

                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(celebrate ? Color.green : Color.white)
                        .frame(width: (geo.size.width + mergeOverlap) * fillAmount(at: timeline.date))
                        .offset(x: -mergeOverlap / 2)
                }
            }
        }
        .frame(height: 3)
        .animation(.easeInOut(duration: 0.25), value: currentOnPage)
    }
}

// MARK: - Page Progress Unified Reset View

struct PageProgressUnifiedResetView: View {
    let total: Int
    let celebrate: Bool
    let resetStart: Date?

    private func fillAmount(at now: Date) -> CGFloat {
        guard let resetStart else { return 1 }
        let resetDuration = PageProgressResetConfig.unifiedResetDuration(for: total)
        let elapsed = now.timeIntervalSince(resetStart)
        let t = min(max(elapsed / max(resetDuration, 0.01), 0), 1)
        let easedT = t * t * (3 - 2 * t)
        let minimumFill = 1 / CGFloat(max(total, 1))
        return minimumFill + CGFloat(1 - easedT) * (1 - minimumFill)
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Color(white: 0.25))

                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(celebrate ? Color.green : Color.white)
                        .frame(width: geo.size.width * fillAmount(at: timeline.date))
                }
            }
        }
        .frame(height: 3)
    }
}
