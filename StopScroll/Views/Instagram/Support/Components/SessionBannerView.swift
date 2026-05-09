import SwiftUI

struct SessionBannerView: View {

    @ObservedObject private var tracker = DailyUsageTracker.shared

    var body: some View {
        HStack(spacing: 12) {
            metricItem(
                label: "Temps passé",
                value: tracker.formattedTime,
                level: tracker.levelForTime()
            )
            divider
            metricItem(
                label: "Ouvertures",
                value: "\(tracker.displayedOpens)×",
                level: tracker.levelForOpens()
            )
            if tracker.dailyReels > 0 {
                divider
                metricItem(
                    label: "Reels",
                    value: "\(tracker.dailyReels)",
                    level: tracker.levelForReels()
                )
            }
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

    // MARK: - Sub-components

    private var divider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.18))
            .frame(width: 1, height: 18)
    }

    private func metricItem(label: String, value: String, level: DailyUsageTracker.Level) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundColor(Color.white.opacity(0.5))
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(color(for: level))
                .contentTransition(.numericText())
                .animation(.spring(duration: 0.4, bounce: 0.25), value: value)
        }
    }

    private func color(for level: DailyUsageTracker.Level) -> Color {
        switch level {
        case .green:  return Color(red: 0.28, green: 0.92, blue: 0.46)
        case .orange: return Color(red: 1.0,  green: 0.65, blue: 0.15)
        case .red:    return Color(red: 1.0,  green: 0.30, blue: 0.30)
        }
    }
}
