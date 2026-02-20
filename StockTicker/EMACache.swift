import Foundation

// MARK: - EMA Cache Entry

struct EMACacheEntry: Codable, Equatable {
    let day: Double?
    let week: Double?
    let weekCrossoverWeeksBelow: Int?
    let weekBelowCount: Int?
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

    func needsSneakPeekRefresh() -> Bool {
        guard let cache = cache, !cache.entries.isEmpty else { return false }

        let now = dateProvider.now()
        let calendar = MarketSchedule.easternCalendar
        let components = calendar.dateComponents([.weekday, .hour], from: now)

        // Must be Friday (weekday 6) between 2-4 PM ET
        guard components.weekday == 6,
              let hour = components.hour,
              hour >= 14, hour < 16 else { return false }

        // Cache must have been updated today but before 2 PM ET
        let formatter = ISO8601DateFormatter()
        guard let lastDate = formatter.date(from: cache.lastUpdated) else { return false }
        guard calendar.isDate(lastDate, inSameDayAs: now) else { return false }

        return calendar.component(.hour, from: lastDate) < 14
    }

    // MARK: - Private

    private func ensureCacheExists() {
        guard cache == nil else { return }
        cache = EMACacheData(lastUpdated: CacheTimestamp.current(dateProvider: dateProvider), entries: [:])
    }

    private func updateLastUpdated() {
        guard let currentCache = cache else { return }
        cache = EMACacheData(lastUpdated: CacheTimestamp.current(dateProvider: dateProvider), entries: currentCache.entries)
    }
}
