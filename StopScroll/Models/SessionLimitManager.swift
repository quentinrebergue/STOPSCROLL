import Foundation

/// Manages daily session time limits for consuming Instagram tabs (Home, Search, Reels).
///
/// State machine:
///   Unlocked → consumes seconds while on home/search/reels.
///   Consumed ≥ normalLimit → Locked.
///   On safe tabs (book/messages/profile/dashboard/timer) or background → restore countdown runs.
///   After 10 min on safe tabs → session resets (unlocked, fresh budget).
///   Long session (once/day): unlocks with extended budget when locked.
///
/// All state persists in UserDefaults and survives app kills.
final class SessionLimitManager: ObservableObject {
    static let shared = SessionLimitManager()

    // MARK: - Published

    @Published private(set) var isLocked: Bool = false
    /// Seconds remaining until session restores (0–600). Drives the TimerLockView circle.
    @Published private(set) var restoreSecondsRemaining: Int = 600

    // MARK: - Private state

    private var consumedSeconds: Int = 0
    private var safeAreaStartedAt: Date?
    private var longSessionUsedDate: Date?
    private var usingLongSession: Bool = false

    private var consumeTimer: Timer?
    private var restoreDisplayTimer: Timer?

    private let restoreDuration = 10 * 60  // 600 s

    // MARK: - Keys

    private enum Keys {
        static let consumed      = "ss_limit_consumed"
        static let locked        = "ss_limit_locked"
        static let safeStartedAt = "ss_limit_safe_started"
        static let longUsedDate  = "ss_limit_long_date"
        static let usingLong     = "ss_limit_using_long"
    }

    // MARK: - Computed

    var normalLimitSeconds: Int { AppSettings.shared.normalSessionMaxMinutes * 60 }
    var longLimitSeconds: Int   { AppSettings.shared.longSessionMaxMinutes * 60 }
    var effectiveLimitSeconds: Int { usingLongSession ? longLimitSeconds : normalLimitSeconds }

    var canUseLongSession: Bool {
        guard let used = longSessionUsedDate else { return true }
        return !Calendar.current.isDateInToday(used)
    }

    // MARK: - Init

    private init() {
        loadAndReconstruct()
    }

    // MARK: - Public API

    /// Call whenever the active section tab changes, and on app foreground.
    func notifyTabChange(to tab: String) {
        if Self.isConsumingTab(tab) && !isLocked {
            // Entering a consuming tab while unlocked: cancel restore, start consuming
            safeAreaStartedAt = nil
            stopRestoreDisplayTimer()
            persist()
            startConsumeTimer()
        } else {
            // Safe tab, locked state, or non-consuming surface: stop consuming, start restore
            stopConsumeTimer()
            if safeAreaStartedAt == nil {
                safeAreaStartedAt = Date()
                persist()
            }
            startRestoreDisplayTimer()
        }
    }

    /// Call when the app enters background.
    func notifyBackground() {
        stopConsumeTimer()
        if safeAreaStartedAt == nil {
            safeAreaStartedAt = Date()
            persist()
        }
        startRestoreDisplayTimer()
    }

    /// Activates the once-per-day long session. Only valid when isLocked && canUseLongSession.
    func useLongSession() {
        guard canUseLongSession, isLocked else { return }
        longSessionUsedDate = Date()
        usingLongSession = true
        isLocked = false
        consumedSeconds = 0
        safeAreaStartedAt = nil
        stopRestoreDisplayTimer()
        restoreSecondsRemaining = restoreDuration
        persist()
        // The user will navigate to a consuming tab next, which starts the consume timer.
    }

    // MARK: - Consuming timer

    private func startConsumeTimer() {
        guard consumeTimer == nil else { return }
        consumeTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.tickConsume()
        }
    }

    private func stopConsumeTimer() {
        consumeTimer?.invalidate()
        consumeTimer = nil
    }

    private func tickConsume() {
        consumedSeconds += 1
        if consumedSeconds % 10 == 0 { persist() }
        if consumedSeconds >= effectiveLimitSeconds {
            triggerLock()
        }
    }

    private func triggerLock() {
        stopConsumeTimer()
        isLocked = true
        if safeAreaStartedAt == nil {
            safeAreaStartedAt = Date()
        }
        persist()
        startRestoreDisplayTimer()
    }

    // MARK: - Restore display timer

    private func startRestoreDisplayTimer() {
        guard restoreDisplayTimer == nil else { return }
        restoreDisplayTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.tickRestore()
        }
        tickRestore()
    }

    private func stopRestoreDisplayTimer() {
        restoreDisplayTimer?.invalidate()
        restoreDisplayTimer = nil
    }

    private func tickRestore() {
        guard let start = safeAreaStartedAt else {
            restoreSecondsRemaining = restoreDuration
            return
        }
        let elapsed = Int(Date().timeIntervalSince(start))
        let remaining = max(0, restoreDuration - elapsed)
        restoreSecondsRemaining = remaining
        if remaining == 0 {
            performRestore()
        }
    }

    private func performRestore() {
        stopRestoreDisplayTimer()
        stopConsumeTimer()
        consumedSeconds = 0
        isLocked = false
        usingLongSession = false
        safeAreaStartedAt = nil
        restoreSecondsRemaining = restoreDuration
        persist()
    }

    // MARK: - Persistence

    private func persist() {
        let ud = UserDefaults.standard
        ud.set(consumedSeconds,     forKey: Keys.consumed)
        ud.set(isLocked,            forKey: Keys.locked)
        ud.set(safeAreaStartedAt,   forKey: Keys.safeStartedAt)
        ud.set(longSessionUsedDate, forKey: Keys.longUsedDate)
        ud.set(usingLongSession,    forKey: Keys.usingLong)
    }

    private func loadAndReconstruct() {
        let ud = UserDefaults.standard
        consumedSeconds     = ud.integer(forKey: Keys.consumed)
        isLocked            = ud.bool(forKey: Keys.locked)
        safeAreaStartedAt   = ud.object(forKey: Keys.safeStartedAt) as? Date
        longSessionUsedDate = ud.object(forKey: Keys.longUsedDate) as? Date
        usingLongSession    = ud.bool(forKey: Keys.usingLong)

        // Reconstruct restore state from persisted safe-area start time
        if let start = safeAreaStartedAt {
            let elapsed = Int(Date().timeIntervalSince(start))
            if elapsed >= restoreDuration {
                // Restore already completed while app was killed
                performRestore()
            } else {
                restoreSecondsRemaining = restoreDuration - elapsed
                // Timers will be started when the first notifyTabChange arrives
            }
        }
    }

    // MARK: - Helpers

    static func isConsumingTab(_ tab: String) -> Bool {
        tab == "home" || tab == "search" || tab == "reels"
    }
}
