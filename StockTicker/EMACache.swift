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
