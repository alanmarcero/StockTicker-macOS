import Foundation

// MARK: - Swing Level Cache Data Model

struct SwingLevelCacheEntry: Codable {
    let breakoutPrice: Double?
    let breakdownPrice: Double?
}

struct SwingLevelCacheData: Codable {
    let quarterRange: String
    let lastUpdated: String
    var entries: [String: SwingLevelCacheEntry]

    init(quarterRange: String, lastUpdated: String = "", entries: [String: SwingLevelCacheEntry] = [:]) {
        self.quarterRange = quarterRange
        self.lastUpdated = lastUpdated
        self.entries = entries
    }
}

// MARK: - Swing Level Cache Manager

actor SwingLevelCacheManager {
    private let storage: CacheStorage<SwingLevelCacheData>
    private let dateProvider: DateProvider
    private var cache: SwingLevelCacheData?

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
            cacheURL: directory.appendingPathComponent("swing-level-cache.json"),
            label: "swing level"
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

    func getEntry(for symbol: String) -> SwingLevelCacheEntry? {
        cache?.entries[symbol]
    }

    func setEntry(for symbol: String, entry: SwingLevelCacheEntry) {
        ensureCacheExists(quarterRange: cache?.quarterRange ?? "")
        cache?.entries[symbol] = entry
        updateLastUpdated()
    }

    func getAllEntries() -> [String: SwingLevelCacheEntry] {
        cache?.entries ?? [:]
    }

    func getMissingSymbols(from symbols: [String]) -> [String] {
        guard let cache = cache else { return symbols }
        return symbols.filter { cache.entries[$0] == nil }
    }

    func needsInvalidation(currentRange: String) -> Bool {
        guard let cache = cache else { return true }
        return cache.quarterRange != currentRange
    }

    func clearForNewRange(_ range: String) {
        let dateString = ISO8601DateFormatter().string(from: dateProvider.now())
        cache = SwingLevelCacheData(quarterRange: range, lastUpdated: dateString, entries: [:])
    }

    func needsDailyRefresh() -> Bool {
        guard let cache = cache else { return true }
        let formatter = ISO8601DateFormatter()
        guard let lastDate = formatter.date(from: cache.lastUpdated) else { return true }
        let calendar = Calendar.current
        return !calendar.isDate(lastDate, inSameDayAs: dateProvider.now())
    }

    func clearEntriesForDailyRefresh() {
        guard let currentCache = cache else { return }
        cache = SwingLevelCacheData(quarterRange: currentCache.quarterRange, lastUpdated: "", entries: [:])
    }

    // MARK: - Private

    private func ensureCacheExists(quarterRange: String) {
        guard cache == nil else { return }
        let dateString = ISO8601DateFormatter().string(from: dateProvider.now())
        cache = SwingLevelCacheData(quarterRange: quarterRange, lastUpdated: dateString, entries: [:])
    }

    private func updateLastUpdated() {
        guard let currentCache = cache else { return }
        let dateString = ISO8601DateFormatter().string(from: dateProvider.now())
        cache = SwingLevelCacheData(
            quarterRange: currentCache.quarterRange,
            lastUpdated: dateString,
            entries: currentCache.entries
        )
    }
}
