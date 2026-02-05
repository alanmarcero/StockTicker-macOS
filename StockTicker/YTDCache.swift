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
    private let fileSystem: FileSystemProtocol
    private let dateProvider: DateProvider
    private let cacheURL: URL
    private var cache: YTDCacheData?

    init(
        fileSystem: FileSystemProtocol = FileManager.default,
        dateProvider: DateProvider = SystemDateProvider(),
        cacheDirectory: URL? = nil
    ) {
        self.fileSystem = fileSystem
        self.dateProvider = dateProvider
        let directory = cacheDirectory ?? fileSystem.homeDirectoryForCurrentUser
            .appendingPathComponent(".stockticker")
        self.cacheURL = directory.appendingPathComponent("ytd-cache.json")
    }

    // MARK: - Public Interface

    func load() {
        guard fileSystem.fileExists(atPath: cacheURL.path),
              let data = fileSystem.contentsOfFile(atPath: cacheURL.path) else {
            cache = nil
            return
        }

        cache = try? JSONDecoder().decode(YTDCacheData.self, from: data)
    }

    func save() {
        guard let cache = cache else { return }

        // Ensure directory exists
        let directory = cacheURL.deletingLastPathComponent()
        if !fileSystem.fileExists(atPath: directory.path) {
            try? fileSystem.createDirectoryAt(directory, withIntermediateDirectories: true)
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        guard let data = try? encoder.encode(cache) else { return }
        try? fileSystem.writeData(data, to: cacheURL)
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
