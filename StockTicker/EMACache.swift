import Foundation

// MARK: - EMA Cache Entry

struct EMACacheEntry: Codable, Equatable {
    let day: Double?
    let week: Double?
    let month: Double?
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
        let formatter = ISO8601DateFormatter()
        guard let lastDate = formatter.date(from: cache.lastUpdated) else { return true }
        let calendar = Calendar.current
        return !calendar.isDate(lastDate, inSameDayAs: dateProvider.now())
    }

    func clearForDailyRefresh() {
        cache = EMACacheData(lastUpdated: "", entries: [:])
    }

    // MARK: - Private

    private func ensureCacheExists() {
        guard cache == nil else { return }
        let dateString = ISO8601DateFormatter().string(from: dateProvider.now())
        cache = EMACacheData(lastUpdated: dateString, entries: [:])
    }

    private func updateLastUpdated() {
        guard let currentCache = cache else { return }
        let dateString = ISO8601DateFormatter().string(from: dateProvider.now())
        cache = EMACacheData(lastUpdated: dateString, entries: currentCache.entries)
    }
}
