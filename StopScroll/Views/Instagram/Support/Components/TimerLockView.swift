import SwiftUI

/// Full-screen view shown when the user has consumed their session time limit.
/// Displays a 10-minute restore countdown and a once-per-day long session button.
struct TimerLockView: View {
    @ObservedObject private var limiter = SessionLimitManager.shared
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Header
                VStack(spacing: 8) {
                    Text("Take a break")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("Step away for 10 minutes to unlock.")
                        .font(.system(size: 15))
                        .foregroundColor(Color.white.opacity(0.45))
                        .multilineTextAlignment(.center)
                }
                .padding(.bottom, 44)

                // Circle countdown
                circleCountdown
                    .padding(.bottom, 28)

                // Unlock time hint
                Text(unlockHintText)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.35))
                    .multilineTextAlignment(.center)

                Spacer()

                // Long session button
                longSessionButton
                    .padding(.horizontal, 28)
                    .padding(.bottom, 48)
            }
        }
    }

    // MARK: - Circle countdown

    private var circleCountdown: some View {
        let remaining = limiter.restoreSecondsRemaining
        let total = Double(10 * 60)
        let progress = max(0, min(1, 1.0 - Double(remaining) / total))
        let minutes = remaining / 60
        let seconds = remaining % 60

        return ZStack {
            Circle()
                .stroke(Color.white.opacity(0.07), lineWidth: 14)
                .frame(width: 224, height: 224)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color(red: 0.0, green: 0.78, blue: 1.0),
                            Color(red: 0.2, green: 0.38, blue: 1.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 14, lineCap: .round)
                )
                .frame(width: 224, height: 224)
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: progress)

            VStack(spacing: 4) {
                Text(String(format: "%d:%02d", minutes, seconds))
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.none, value: remaining)

                Text("remaining")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.3))
            }
        }
    }

    // MARK: - Long session button

    private var longSessionButton: some View {
        let canUse = limiter.canUseLongSession
        let extra  = settings.longSessionMaxMinutes

        return Button {
            guard canUse else { return }
            limiter.useLongSession()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: canUse ? "bolt.fill" : "lock.fill")
                    .font(.system(size: 14, weight: .semibold))
                Text(canUse
                     ? "Use long session (+\(extra) min)"
                     : "Long session already used today")
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundColor(canUse ? .white : Color.white.opacity(0.28))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .background(buttonBackground(canUse: canUse))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .disabled(!canUse)
    }

    @ViewBuilder
    private func buttonBackground(canUse: Bool) -> some View {
        if canUse {
            LinearGradient(
                colors: [
                    Color(red: 0.0, green: 0.78, blue: 1.0).opacity(0.72),
                    Color(red: 0.2, green: 0.38, blue: 1.0).opacity(0.72)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        } else {
            Color.white.opacity(0.07)
        }
    }

    // MARK: - Helpers

    private var unlockHintText: String {
        let remaining = limiter.restoreSecondsRemaining
        guard remaining > 0 else { return "Unlocking…" }
        let minutes = remaining / 60
        let seconds = remaining % 60
        if minutes > 0 {
            return "Unlocks in \(minutes) min \(seconds) s"
        }
        return "Unlocks in \(seconds) s"
    }
}
