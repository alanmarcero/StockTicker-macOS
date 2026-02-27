import Foundation

// MARK: - EMA Cache Entry

struct EMACacheEntry: Codable, Equatable {
    let day: Double?
    let week: Double?
    let weekCrossoverWeeksBelow: Int?
    let weekCrossdownWeeksAbove: Int?
    let weekBelowCount: Int?
    let dayAboveCount: Int?
    let weekAboveCount: Int?

    init(day: Double?, week: Double?, weekCrossoverWeeksBelow: Int?, weekCrossdownWeeksAbove: Int? = nil, weekBelowCount: Int?, dayAboveCount: Int? = nil, weekAboveCount: Int? = nil) {
        self.day = day
        self.week = week
        self.weekCrossoverWeeksBelow = weekCrossoverWeeksBelow
        self.weekCrossdownWeeksAbove = weekCrossdownWeeksAbove
        self.weekBelowCount = weekBelowCount
        self.dayAboveCount = dayAboveCount
        self.weekAboveCount = weekAboveCount
    }
}

// MARK: - EMA Cache Data Model

struct EMACacheData: Codable {
    let lastUpdated: String
    var entries: [String: EMACacheEntry]

    init(lastUpdated: String = "", entries: [String: EMACacheEntry] = [:]) {
        self.lastUpdated = lastUpdated
        self.entries = entries
    }
}

// MARK: - EMA Cache Manager

actor EMACacheManager {
    private let storage: CacheStorage<EMACacheData>
    private let dateProvider: DateProvider
    private var cache: EMACacheData?
    private var lastSneakPeekDate: Date?

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
            cacheURL: directory.appendingPathComponent("ema-cache.json"),
            label: "EMA"
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

    func getEntry(for symbol: String) -> EMACacheEntry? {
        cache?.entries[symbol]
    }

    func setEntry(for symbol: String, entry: EMACacheEntry) {
        ensureCacheExists()
        cache?.entries[symbol] = entry
        updateLastUpdated()
    }

    func getAllEntries() -> [String: EMACacheEntry] {
        cache?.entries ?? [:]
    }

    func getMissingSymbols(from symbols: [String]) -> [String] {
        guard let cache = cache else { return symbols }
        return symbols.filter { cache.entries[$0] == nil }
    }

    func needsDailyRefresh() -> Bool {
        guard let cache = cache else { return true }
        return CacheTimestamp.needsDailyRefresh(lastUpdated: cache.lastUpdated, dateProvider: dateProvider)
    }

    func clearForDailyRefresh() {
        cache = EMACacheData(lastUpdated: "", entries: [:])
    }

    func clearDailyFields() {
        guard let currentCache = cache else { return }
        var updated: [String: EMACacheEntry] = [:]
        for (symbol, entry) in currentCache.entries {
            updated[symbol] = EMACacheEntry(
                day: nil, week: entry.week,
                weekCrossoverWeeksBelow: entry.weekCrossoverWeeksBelow,
                weekCrossdownWeeksAbove: entry.weekCrossdownWeeksAbove,
                weekBelowCount: entry.weekBelowCount,
                dayAboveCount: nil, weekAboveCount: entry.weekAboveCount
            )
        }
        cache = EMACacheData(lastUpdated: "", entries: updated)
    }

    func needsMarketCloseRefresh() -> Bool {
        guard let cache = cache, !cache.entries.isEmpty else { return false }

        let now = dateProvider.now()
        let calendar = MarketSchedule.easternCalendar
        let components = calendar.dateComponents([.weekday, .hour], from: now)

        // Only on weekdays (Mon=2 through Fri=6), at or after 4 PM ET
        guard let weekday = components.weekday, weekday >= 2, weekday <= 6,
              let hour = components.hour, hour >= 16 else { return false }

        // True if cache was last updated before today's 4 PM ET
        let formatter = ISO8601DateFormatter()
        guard let lastDate = formatter.date(from: cache.lastUpdated) else { return false }

        let todayComponents = calendar.dateComponents([.year, .month, .day], from: now)
        guard let today4pm = calendar.date(from: DateComponents(
            year: todayComponents.year, month: todayComponents.month,
            day: todayComponents.day, hour: 16, minute: 0
        )) else { return false }

        return lastDate < today4pm
    }

    func needsSneakPeekRefresh() -> Bool {
        guard let cache = cache, !cache.entries.isEmpty else { return false }

        let now = dateProvider.now()
        let calendar = MarketSchedule.easternCalendar
        let components = calendar.dateComponents([.weekday, .hour], from: now)

        // Must be Friday (weekday 6) between 2-4 PM ET
        guard components.weekday == 6,
              let hour = components.hour,
              hour >= 14, hour < 16 else { return false }

        // First entry into sneak peek window: trigger immediately
        guard let lastSneak = lastSneakPeekDate,
              calendar.isDate(lastSneak, inSameDayAs: now) else { return true }

        // Periodic refresh: every 5 minutes within the window
        return now.timeIntervalSince(lastSneak) >= SneakPeek.refreshInterval
    }

    func markSneakPeekDone() {
        lastSneakPeekDate = dateProvider.now()
    }

    // MARK: - Private

    private enum SneakPeek {
        static let refreshInterval: TimeInterval = 300
    }

    private func ensureCacheExists() {
        guard cache == nil else { return }
        cache = EMACacheData(lastUpdated: CacheTimestamp.current(dateProvider: dateProvider), entries: [:])
    }

    private func updateLastUpdated() {
        guard let currentCache = cache else { return }
        cache = EMACacheData(lastUpdated: CacheTimestamp.current(dateProvider: dateProvider), entries: currentCache.entries)
    }
}
