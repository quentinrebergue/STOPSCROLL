import Foundation

/// Tracks daily reading streak. Goal: 10 pages per day.
/// A "page" is a unique `card.page` value seen during a session.
/// Persists in UserDefaults and survives app kills.
final class ReadingStreakManager: ObservableObject {
    static let shared = ReadingStreakManager()

    // MARK: - Published

    @Published private(set) var currentStreak: Int = 0
    @Published private(set) var pagesReadToday: Int = 0

    let dailyGoal = 10
    var goalMet: Bool { pagesReadToday >= dailyGoal }

    // MARK: - Private

    private var lastRecordedPage: Int = -1

    private enum Keys {
        static let streak     = "ss_reading_streak"
        static let pagesToday = "ss_reading_pages_today"
        static let lastDate   = "ss_reading_last_date"
        static let lastPage   = "ss_reading_last_page"
    }

    // MARK: - Init

    private init() {
        load()
    }

    // MARK: - Public API

    /// Call whenever the reader moves to a new page number.
    func recordPage(_ pageNumber: Int) {
        guard pageNumber >= 0, pageNumber != lastRecordedPage else { return }
        lastRecordedPage = pageNumber

        let ud = UserDefaults.standard
        let today = Calendar.current.startOfDay(for: Date())

        if let savedDate = ud.object(forKey: Keys.lastDate) as? Date,
           !Calendar.current.isDate(savedDate, inSameDayAs: today) {
            // New day: evaluate streak continuity before resetting counter
            let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
            let savedPages = ud.integer(forKey: Keys.pagesToday)
            if !Calendar.current.isDate(savedDate, inSameDayAs: yesterday) || savedPages < dailyGoal {
                currentStreak = 0
            }
            pagesReadToday = 0
        }

        if pagesReadToday < dailyGoal {
            pagesReadToday += 1
            if pagesReadToday == dailyGoal {
                currentStreak += 1
            }
        }

        ud.set(today, forKey: Keys.lastDate)
        ud.set(pagesReadToday, forKey: Keys.pagesToday)
        ud.set(currentStreak, forKey: Keys.streak)
        ud.set(pageNumber, forKey: Keys.lastPage)
    }

    // MARK: - Private

    private func load() {
        let ud = UserDefaults.standard
        let today = Calendar.current.startOfDay(for: Date())
        guard let savedDate = ud.object(forKey: Keys.lastDate) as? Date else { return }

        let savedPages  = ud.integer(forKey: Keys.pagesToday)
        let savedStreak = ud.integer(forKey: Keys.streak)

        if Calendar.current.isDate(savedDate, inSameDayAs: today) {
            pagesReadToday   = savedPages
            currentStreak    = savedStreak
            lastRecordedPage = ud.integer(forKey: Keys.lastPage)
        } else {
            // Missed one or more days — decide if streak survives
            let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
            if Calendar.current.isDate(savedDate, inSameDayAs: yesterday) && savedPages >= dailyGoal {
                currentStreak = savedStreak   // yesterday met goal → streak continues
            } else {
                currentStreak = 0
            }
            pagesReadToday = 0
        }
    }
}
