import SwiftUI

struct DashboardView: View {
    let onDismiss: () -> Void
    var onOpenSettings: (() -> Void)? = nil
    var showsToolbarButton: Bool = true
    @ObservedObject private var settings = AppSettings.shared

    @AppStorage("ss_xp_total") private var totalXP = 0
    @AppStorage("ss_goal_sessions_per_day") private var goalSessionsPerDay = 3
    @AppStorage("ss_goal_minutes_per_day") private var goalMinutesPerDay = 30
    @AppStorage("ss_usage_sessions_today") private var sessionsToday = 0
    @AppStorage("ss_usage_minutes_today") private var minutesToday = 0

    private var xpLevel: Int {
        XPProgress.level(for: totalXP)
    }

    private var xpProgress: Double {
        XPProgress.progress(for: totalXP)
    }

    private var xpInLevel: Int {
        XPProgress.xpInCurrentLevel(for: totalXP)
    }

    private var appBackgroundColor: Color {
        settings.adaptivePalette.background
    }

    private var palette: AppSettings.AdaptivePalette {
        settings.adaptivePalette
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    goalsCard
                    usageCard
                    progressionCard
                }
                .padding(16)
                .padding(.bottom, 104)
            }
            .background(appBackgroundColor.ignoresSafeArea())
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if showsToolbarButton {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            onOpenSettings?()
                        } label: {
                            Image(systemName: "gearshape")
                        }
                        .accessibilityIdentifier("dashboard.openSettings")
                    }
                }
            }
        }
    }

    private var goalsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Objectifs")
                .font(.headline)
                .foregroundColor(palette.primaryText)

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Sessions / jour")
                        .font(.caption)
                        .foregroundColor(palette.secondaryText)
                    Stepper(value: $goalSessionsPerDay, in: 1...12) {
                        Text("\(goalSessionsPerDay)")
                            .foregroundColor(palette.primaryText)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Minutes / jour")
                        .font(.caption)
                        .foregroundColor(palette.secondaryText)
                    Stepper(value: $goalMinutesPerDay, in: 5...180, step: 5) {
                        Text("\(goalMinutesPerDay) min")
                            .foregroundColor(palette.primaryText)
                    }
                }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(palette.surface))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(palette.border, lineWidth: 1))
    }

    private var usageCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Usage du jour")
                .font(.headline)
                .foregroundColor(palette.primaryText)

            HStack(spacing: 12) {
                dashboardMetric(title: "Sessions", value: "\(sessionsToday)", target: "Objectif \(goalSessionsPerDay)")
                dashboardMetric(title: "Minutes", value: "\(minutesToday)", target: "Objectif \(goalMinutesPerDay)")
            }

            ProgressView(value: usageProgress)
                .tint(Color(red: 0.35, green: 0.85, blue: 0.45))
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(palette.surface))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(palette.border, lineWidth: 1))
    }

    private var progressionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Progression")
                .font(.headline)
                .foregroundColor(palette.primaryText)

            HStack(alignment: .firstTextBaseline) {
                Text("Niveau \(xpLevel)")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(palette.primaryText)
                Spacer()
                Text("\(xpInLevel) / \(XPProgress.xpPerLevel) XP")
                    .font(.caption)
                    .foregroundColor(palette.secondaryText)
            }

            ProgressView(value: xpProgress)
                .tint(Color(red: 0.42, green: 0.9, blue: 1.0))

            Text("Total XP: \(totalXP)")
                .font(.caption)
                .foregroundColor(palette.secondaryText)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(palette.surface))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(palette.border, lineWidth: 1))
    }

    private var usageProgress: Double {
        let sessionRatio = goalSessionsPerDay > 0 ? Double(sessionsToday) / Double(goalSessionsPerDay) : 0
        let minuteRatio = goalMinutesPerDay > 0 ? Double(minutesToday) / Double(goalMinutesPerDay) : 0
        return max(0, min(1, (sessionRatio + minuteRatio) / 2.0))
    }

    private func dashboardMetric(title: String, value: String, target: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(palette.secondaryText)
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(palette.primaryText)
            Text(target)
                .font(.caption2)
                .foregroundColor(palette.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(palette.elevatedSurface))
    }
}
