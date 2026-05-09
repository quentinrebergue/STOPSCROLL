import SwiftUI

struct DashboardView: View {
    let onDismiss: () -> Void
    var onOpenSettings: (() -> Void)? = nil
    var showsToolbarButton: Bool = true
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var streak = ReadingStreakManager.shared

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
                    streakCard
                    sessionLimitsCard
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

    private var streakCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                Text("🔥")
                    .font(.system(size: 30))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Reading Streak")
                        .font(.headline)
                        .foregroundColor(palette.primaryText)
                    Text(streak.currentStreak == 0
                         ? "Start your streak today"
                         : "\(streak.currentStreak) day\(streak.currentStreak == 1 ? "" : "s") in a row")
                        .font(.caption)
                        .foregroundColor(palette.secondaryText)
                }
                Spacer()
                Text("\(streak.currentStreak)")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundColor(streak.currentStreak > 0
                                     ? Color(red: 1.0, green: 0.55, blue: 0.1)
                                     : palette.secondaryText)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("\(streak.pagesReadToday) / \(streak.dailyGoal) pages read today")
                        .font(.caption)
                        .foregroundColor(palette.secondaryText)
                    Spacer()
                    if streak.goalMet {
                        Label("Goal met!", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(Color(red: 0.28, green: 0.85, blue: 0.46))
                    }
                }
                ProgressView(value: Double(streak.pagesReadToday), total: Double(streak.dailyGoal))
                    .tint(streak.goalMet
                          ? Color(red: 0.28, green: 0.85, blue: 0.46)
                          : Color(red: 1.0, green: 0.55, blue: 0.1))
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(palette.surface))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(palette.border, lineWidth: 1))
    }

    private var sessionLimitsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Session Limits")
                .font(.headline)
                .foregroundColor(palette.primaryText)

            VStack(spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Normal session")
                            .font(.caption)
                            .foregroundColor(palette.secondaryText)
                        Text("Resets after 10 min away")
                            .font(.caption2)
                            .foregroundColor(palette.secondaryText.opacity(0.6))
                    }
                    Spacer()
                    Stepper(value: $settings.normalSessionMaxMinutes, in: 5...120, step: 5) {
                        Text("\(settings.normalSessionMaxMinutes) min")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(palette.primaryText)
                    }
                    .onChange(of: settings.normalSessionMaxMinutes) { newNormal in
                        if settings.longSessionMaxMinutes < newNormal {
                            settings.longSessionMaxMinutes = newNormal
                        }
                    }
                }

                Divider().background(palette.border)

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Long session")
                            .font(.caption)
                            .foregroundColor(palette.secondaryText)
                        Text("Once per day credit")
                            .font(.caption2)
                            .foregroundColor(palette.secondaryText.opacity(0.6))
                    }
                    Spacer()
                    Stepper(
                        value: $settings.longSessionMaxMinutes,
                        in: settings.normalSessionMaxMinutes...240,
                        step: 5
                    ) {
                        Text("\(settings.longSessionMaxMinutes) min")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(palette.primaryText)
                    }
                }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(palette.surface))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(palette.border, lineWidth: 1))
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
