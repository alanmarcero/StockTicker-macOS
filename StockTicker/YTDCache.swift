import Foundation

// MARK: - YTD Cache Data Model

struct YTDCacheData: Codable {
    let year: Int
    let lastUpdated: String
    var prices: [String: Double]

    init(year: Int, lastUpdated: String = "", prices: [String: Double] = [:]) {
        self.year = year
        self.lastUpdated = lastUpdated
        self.prices = prices
    }
}

// MARK: - YTD Cache Manager

actor YTDCacheManager {
    private let storage: CacheStorage<YTDCacheData>
    private let dateProvider: DateProvider
    private var cache: YTDCacheData?

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
            cacheURL: directory.appendingPathComponent("ytd-cache.json"),
            label: "YTD"
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

    func getStartPrice(for symbol: String) -> Double? {
        cache?.prices[symbol]
    }

    func setStartPrice(for symbol: String, price: Double) {
        ensureCacheExists()
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

    func needsYearRollover() -> Bool {
        guard let cache = cache else { return true }
        let currentYear = Calendar.current.component(.year, from: dateProvider.now())
        return cache.year != currentYear
    }

    func clearForNewYear() {
        let now = dateProvider.now()
        let currentYear = Calendar.current.component(.year, from: now)
        let dateString = ISO8601DateFormatter().string(from: now)
        cache = YTDCacheData(year: currentYear, lastUpdated: dateString, prices: [:])
    }

    // MARK: - Private

    private func ensureCacheExists() {
        guard cache == nil else { return }

        let now = dateProvider.now()
        let currentYear = Calendar.current.component(.year, from: now)
        let dateString = ISO8601DateFormatter().string(from: now)
        cache = YTDCacheData(year: currentYear, lastUpdated: dateString, prices: [:])
    }

    private func updateLastUpdated() {
        guard let currentCache = cache else { return }
        let dateString = ISO8601DateFormatter().string(from: dateProvider.now())
        cache = YTDCacheData(
            year: currentCache.year,
            lastUpdated: dateString,
            prices: currentCache.prices
        )
    }
}
