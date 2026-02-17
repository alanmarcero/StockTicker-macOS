import Foundation

// MARK: - RSI Cache Data Model

struct RSICacheData: Codable {
    let lastUpdated: String
    var values: [String: Double]

    init(lastUpdated: String = "", values: [String: Double] = [:]) {
        self.lastUpdated = lastUpdated
        self.values = values
    }
}

// MARK: - RSI Cache Manager

actor RSICacheManager {
    private let storage: CacheStorage<RSICacheData>
    private let dateProvider: DateProvider
    private var cache: RSICacheData?

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
            cacheURL: directory.appendingPathComponent("rsi-cache.json"),
            label: "RSI"
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

    func getRSI(for symbol: String) -> Double? {
        cache?.values[symbol]
    }

    func setRSI(for symbol: String, value: Double) {
        ensureCacheExists()
        cache?.values[symbol] = value
        updateLastUpdated()
    }

    func getAllValues() -> [String: Double] {
        cache?.values ?? [:]
    }

    func getMissingSymbols(from symbols: [String]) -> [String] {
        guard let cache = cache else { return symbols }
        return symbols.filter { cache.values[$0] == nil }
    }

    func needsDailyRefresh() -> Bool {
        guard let cache = cache else { return true }
        return CacheTimestamp.needsDailyRefresh(lastUpdated: cache.lastUpdated, dateProvider: dateProvider)
    }

    func clearForDailyRefresh() {
        cache = RSICacheData(lastUpdated: "", values: [:])
    }

    // MARK: - Private

    private func ensureCacheExists() {
        guard cache == nil else { return }
        cache = RSICacheData(lastUpdated: CacheTimestamp.current(dateProvider: dateProvider), values: [:])
    }

    private func updateLastUpdated() {
        guard let currentCache = cache else { return }
        cache = RSICacheData(lastUpdated: CacheTimestamp.current(dateProvider: dateProvider), values: currentCache.values)
    }
}
