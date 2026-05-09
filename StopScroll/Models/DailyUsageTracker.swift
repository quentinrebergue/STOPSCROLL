import Foundation
import Combine

/// Tracks daily usage metrics: session time, app opens, and reels scrolled.
/// All counters reset at midnight. Persists in UserDefaults.
final class DailyUsageTracker: ObservableObject {

    static let shared = DailyUsageTracker()

    // MARK: - Published

    @Published private(set) var dailySeconds: Int = 0
    @Published private(set) var dailyOpens: Int = 0
    @Published private(set) var displayedOpens: Int = 0   // lags behind dailyOpens until tickDisplayedOpens()
    @Published private(set) var dailyReels: Int = 0

    // MARK: - Private

    private var sessionStartDate: Date?
    private var accumulationTimer: Timer?
    private var midnightTimer: Timer?

    private enum Keys {
        static let seconds  = "ss_daily_seconds"
        static let opens    = "ss_daily_opens"
        static let reels    = "ss_daily_reels"
        static let date     = "ss_daily_date"
    }

    // MARK: - Init

    private init() {
        loadOrReset()
        scheduleMidnightReset()
    }

    // MARK: - Public API

    /// Call when the Instagram view appears (app opened / foregrounded).
    func recordOpen() {
        loadOrReset()
        displayedOpens = dailyOpens   // show old value in banner first
        dailyOpens += 1
        persist()
        startSessionTimer()
    }

    /// Advance displayedOpens to match dailyOpens — call this inside a withAnimation block.
    func tickDisplayedOpens() {
        displayedOpens = dailyOpens
    }

    /// Call when the Instagram view disappears (backgrounded / closed).
    func recordBackground() {
        flushElapsedTime()
        stopSessionTimer()
    }

    /// Call when a new reel is viewed.
    func recordReel() {
        loadOrReset()
        dailyReels += 1
        persist()
    }

    // MARK: - Color helpers

    enum Level { case green, orange, red }

    func levelForTime() -> Level {
        if dailySeconds < 20 * 60 { return .green }
        if dailySeconds < 45 * 60 { return .orange }
        return .red
    }

    func levelForOpens() -> Level {
        if dailyOpens < 5  { return .green }
        if dailyOpens < 13 { return .orange }
        return .red
    }

    func levelForReels() -> Level {
        if dailyReels < 15 { return .green }
        if dailyReels < 40 { return .orange }
        return .red
    }

    var formattedTime: String {
        let minutes = dailySeconds / 60
        if minutes < 60 { return "\(minutes) min" }
        let h = minutes / 60
        let m = minutes % 60
        return m == 0 ? "\(h)h" : "\(h)h\(m)"
    }

    // MARK: - Private helpers

    private func startSessionTimer() {
        sessionStartDate = Date()
        accumulationTimer?.invalidate()
        // Flush elapsed time every 30s to survive crashes
        accumulationTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.flushElapsedTime()
        }
    }

    private func stopSessionTimer() {
        accumulationTimer?.invalidate()
        accumulationTimer = nil
    }

    private func flushElapsedTime() {
        guard let start = sessionStartDate else { return }
        let elapsed = Int(Date().timeIntervalSince(start))
        dailySeconds += elapsed
        persist()
        sessionStartDate = Date() // reset so next flush doesn't double-count
    }

    private func loadOrReset() {
        let ud = UserDefaults.standard
        let today = Calendar.current.startOfDay(for: Date())
        if let saved = ud.object(forKey: Keys.date) as? Date,
           Calendar.current.isDate(saved, inSameDayAs: today) {
            dailySeconds = ud.integer(forKey: Keys.seconds)
            dailyOpens   = ud.integer(forKey: Keys.opens)
            dailyReels   = ud.integer(forKey: Keys.reels)
            displayedOpens = dailyOpens
        } else {
            dailySeconds   = 0
            dailyOpens     = 0
            displayedOpens = 0
            dailyReels     = 0
            persist()
        }
    }

    private func persist() {
        let ud = UserDefaults.standard
        ud.set(dailySeconds, forKey: Keys.seconds)
        ud.set(dailyOpens,   forKey: Keys.opens)
        ud.set(dailyReels,   forKey: Keys.reels)
        ud.set(Calendar.current.startOfDay(for: Date()), forKey: Keys.date)
    }

    private func scheduleMidnightReset() {
        midnightTimer?.invalidate()
        let now = Date()
        let tomorrow = Calendar.current.nextDate(after: now,
                                                  matching: DateComponents(hour: 0, minute: 0, second: 0),
                                                  matchingPolicy: .nextTime)!
        let delay = tomorrow.timeIntervalSince(now)
        midnightTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            self?.dailySeconds = 0
            self?.dailyOpens   = 0
            self?.dailyReels   = 0
            self?.persist()
            self?.scheduleMidnightReset()
        }
    }
}
