import Foundation

// MARK: - Highest Close Cache Data Model

struct HighestCloseCacheData: Codable {
    let quarterRange: String
    let lastUpdated: String
    var prices: [String: Double]

    init(quarterRange: String, lastUpdated: String = "", prices: [String: Double] = [:]) {
        self.quarterRange = quarterRange
        self.lastUpdated = lastUpdated
        self.prices = prices
    }
}

// MARK: - Highest Close Cache Manager

actor HighestCloseCacheManager {
    private let storage: CacheStorage<HighestCloseCacheData>
    private let dateProvider: DateProvider
    private var cache: HighestCloseCacheData?

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
            cacheURL: directory.appendingPathComponent("highest-close-cache.json"),
            label: "highest close"
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

    func getHighestClose(for symbol: String) -> Double? {
        cache?.prices[symbol]
    }

    func setHighestClose(for symbol: String, price: Double) {
        ensureCacheExists(quarterRange: cache?.quarterRange ?? "")
        cache?.prices[symbol] = price
        updateLastUpdated()
    }

    func getAllPrices() -> [String: Double] {
        cache?.prices ?? [:]
    }

    func getMissingSymbols(from symbols: [String]) -> [String] {
        guard let cache = cache else { return symbols }
        return symbols.filter { cache.prices[$0] == nil }
    }

    func needsInvalidation(currentRange: String) -> Bool {
        guard let cache = cache else { return true }
        return cache.quarterRange != currentRange
    }

    func clearForNewRange(_ range: String) {
        cache = HighestCloseCacheData(quarterRange: range, lastUpdated: CacheTimestamp.current(dateProvider: dateProvider), prices: [:])
    }

    func needsDailyRefresh() -> Bool {
        guard let cache = cache else { return true }
        return CacheTimestamp.needsDailyRefresh(lastUpdated: cache.lastUpdated, dateProvider: dateProvider)
    }

    func clearPricesForDailyRefresh() {
        guard let currentCache = cache else { return }
        cache = HighestCloseCacheData(quarterRange: currentCache.quarterRange, lastUpdated: "", prices: [:])
    }

    // MARK: - Private

    private func ensureCacheExists(quarterRange: String) {
        guard cache == nil else { return }
        cache = HighestCloseCacheData(quarterRange: quarterRange, lastUpdated: CacheTimestamp.current(dateProvider: dateProvider), prices: [:])
    }

    private func updateLastUpdated() {
        guard let currentCache = cache else { return }
        cache = HighestCloseCacheData(
            quarterRange: currentCache.quarterRange,
            lastUpdated: CacheTimestamp.current(dateProvider: dateProvider),
            prices: currentCache.prices
        )
    }
}
