import Foundation

// MARK: - Highest Close Cache Data Model

struct HighestCloseCacheData: Codable {
    let quarterRange: String
    let lastUpdated: String
    var prices: [String: Double]
    var lowestClosePrices: [String: Double]

    init(quarterRange: String, lastUpdated: String = "", prices: [String: Double] = [:], lowestClosePrices: [String: Double] = [:]) {
        self.quarterRange = quarterRange
        self.lastUpdated = lastUpdated
        self.prices = prices
        self.lowestClosePrices = lowestClosePrices
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        quarterRange = try container.decode(String.self, forKey: .quarterRange)
        lastUpdated = try container.decode(String.self, forKey: .lastUpdated)
        prices = try container.decode([String: Double].self, forKey: .prices)
        lowestClosePrices = try container.decodeIfPresent([String: Double].self, forKey: .lowestClosePrices) ?? [:]
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

    func getLowestClose(for symbol: String) -> Double? {
        cache?.lowestClosePrices[symbol]
    }

    func setLowestClose(for symbol: String, price: Double) {
        ensureCacheExists(quarterRange: cache?.quarterRange ?? "")
        cache?.lowestClosePrices[symbol] = price
        updateLastUpdated()
    }

    func getAllLowestClosePrices() -> [String: Double] {
        cache?.lowestClosePrices ?? [:]
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
        cache = HighestCloseCacheData(quarterRange: range, lastUpdated: CacheTimestamp.current(dateProvider: dateProvider), prices: [:], lowestClosePrices: [:])
    }

    func needsDailyRefresh() -> Bool {
        guard let cache = cache else { return true }
        return CacheTimestamp.needsDailyRefresh(lastUpdated: cache.lastUpdated, dateProvider: dateProvider)
    }

    func markForDailyRefresh() {
        guard let currentCache = cache else { return }
        cache = HighestCloseCacheData(quarterRange: currentCache.quarterRange, lastUpdated: "", prices: currentCache.prices, lowestClosePrices: currentCache.lowestClosePrices)
    }

    // MARK: - Private

    private func ensureCacheExists(quarterRange: String) {
        guard cache == nil else { return }
        cache = HighestCloseCacheData(quarterRange: quarterRange, lastUpdated: CacheTimestamp.current(dateProvider: dateProvider), prices: [:], lowestClosePrices: [:])
    }

    private func updateLastUpdated() {
        guard let currentCache = cache else { return }
        cache = HighestCloseCacheData(
            quarterRange: currentCache.quarterRange,
            lastUpdated: CacheTimestamp.current(dateProvider: dateProvider),
            prices: currentCache.prices,
            lowestClosePrices: currentCache.lowestClosePrices
        )
    }
}
