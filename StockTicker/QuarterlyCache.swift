import Foundation

// MARK: - Quarter Info

struct QuarterInfo: Equatable {
    let identifier: String    // "Q4-2025"
    let displayLabel: String  // "Q4'25"
    let year: Int
    let quarter: Int          // 1-4
}

// MARK: - Quarter Calculation (Pure Functions)

enum QuarterCalculation {

    /// Returns the last N completed quarters from the given date, most recent first.
    /// A quarter is "completed" only after its last day ends.
    static func lastNCompletedQuarters(from date: Date, count: Int) -> [QuarterInfo] {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)
        let currentQuarter = (month - 1) / 3 + 1

        // Walk backward from the quarter before the current one
        var results: [QuarterInfo] = []
        var qYear = year
        var qQuarter = currentQuarter - 1

        if qQuarter < 1 {
            qQuarter = 4
            qYear -= 1
        }

        for _ in 0..<count {
            results.append(QuarterInfo(
                identifier: quarterIdentifier(year: qYear, quarter: qQuarter),
                displayLabel: displayLabel(year: qYear, quarter: qQuarter),
                year: qYear,
                quarter: qQuarter
            ))

            qQuarter -= 1
            if qQuarter < 1 {
                qQuarter = 4
                qYear -= 1
            }
        }

        return results
    }

    /// Returns Unix timestamps for a date range around the quarter end.
    /// Uses a 5-day lookback before quarter end and 2 days after (captures last trading day through weekends/holidays).
    static func quarterEndDateRange(year: Int, quarter: Int) -> (period1: Int, period2: Int) {
        let calendar = Calendar.current
        let endMonth = quarter * 3
        let lastDay = lastDayOfMonth(year: year, month: endMonth, calendar: calendar)

        guard let endDate = calendar.date(from: DateComponents(year: year, month: endMonth, day: lastDay)),
              let period1Date = calendar.date(byAdding: .day, value: -5, to: endDate),
              let period2Date = calendar.date(byAdding: .day, value: 2, to: endDate) else {
            return (0, 0)
        }

        return (Int(period1Date.timeIntervalSince1970), Int(period2Date.timeIntervalSince1970))
    }

    static func quarterIdentifier(year: Int, quarter: Int) -> String {
        "Q\(quarter)-\(year)"
    }

    static func displayLabel(year: Int, quarter: Int) -> String {
        let shortYear = year % 100
        return "Q\(quarter)'\(String(format: "%02d", shortYear))"
    }

    static func quarterStartTimestamp(year: Int, quarter: Int) -> Int {
        let startMonth = (quarter - 1) * 3 + 1
        let calendar = Calendar.current
        guard let date = calendar.date(from: DateComponents(year: year, month: startMonth, day: 1)) else { return 0 }
        return Int(date.timeIntervalSince1970)
    }

    // MARK: - Private

    private static func lastDayOfMonth(year: Int, month: Int, calendar: Calendar) -> Int {
        guard let date = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
              let range = calendar.range(of: .day, in: .month, for: date) else {
            return 30
        }
        return range.upperBound - 1
    }
}

// MARK: - Quarterly Cache Data Model

struct QuarterlyCacheData: Codable {
    let lastUpdated: String
    var quarters: [String: [String: Double]]  // "Q4-2025" -> ["AAPL": 254.23]

    init(lastUpdated: String = "", quarters: [String: [String: Double]] = [:]) {
        self.lastUpdated = lastUpdated
        self.quarters = quarters
    }
}

// MARK: - Quarterly Cache Manager

actor QuarterlyCacheManager {
    private let storage: CacheStorage<QuarterlyCacheData>
    private let dateProvider: DateProvider
    private var cache: QuarterlyCacheData?

    init(
        fileSystem: FileSystemProtocol = FileManager.default,
        dateProvider: DateProvider = SystemDateProvider(),
        cacheDirectory: URL? = nil
    ) {
        self.dateProvider = dateProvider
        let directory = cacheDirectory ?? fileSystem.homeDirectoryForCurrentUser
            .appendingPathComponent(".stockticker")
        self.storage = CacheStorage(
            fileSystem: fileSystem,
            cacheURL: directory.appendingPathComponent("quarterly-cache.json"),
            label: "quarterly"
        )
    }

    // MARK: - Public Interface

    func load() {
        cache = storage.load()
    }

    func save() {
        guard let cache else { return }
        storage.save(cache)
    }

    func getPrice(symbol: String, quarter: String) -> Double? {
        cache?.quarters[quarter]?[symbol]
    }

    func setPrices(quarter: String, prices: [String: Double]) {
        ensureCacheExists()
        if cache?.quarters[quarter] == nil {
            cache?.quarters[quarter] = [:]
        }
        for (symbol, price) in prices {
            cache?.quarters[quarter]?[symbol] = price
        }
        updateLastUpdated()
    }

    func getAllQuarterPrices() -> [String: [String: Double]] {
        cache?.quarters ?? [:]
    }

    func getMissingSymbols(for quarter: String, from symbols: [String]) -> [String] {
        guard let quarterData = cache?.quarters[quarter] else { return symbols }
        return symbols.filter { quarterData[$0] == nil }
    }

    func clearAllQuarters() {
        cache = QuarterlyCacheData(lastUpdated: "", quarters: [:])
    }

    func pruneOldQuarters(keeping activeQuarters: [String]) {
        guard var currentCache = cache else { return }
        let activeSet = Set(activeQuarters)
        currentCache.quarters = currentCache.quarters.filter { activeSet.contains($0.key) }
        cache = currentCache
        updateLastUpdated()
    }

    // MARK: - Private

    private func ensureCacheExists() {
        guard cache == nil else { return }
        cache = QuarterlyCacheData(lastUpdated: CacheTimestamp.current(dateProvider: dateProvider), quarters: [:])
    }

    private func updateLastUpdated() {
        guard let currentCache = cache else { return }
        cache = QuarterlyCacheData(lastUpdated: CacheTimestamp.current(dateProvider: dateProvider), quarters: currentCache.quarters)
    }
}
