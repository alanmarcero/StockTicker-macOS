import Foundation

// MARK: - Forward P/E Cache Data Model

struct ForwardPECacheData: Codable {
    let quarterRange: String
    let lastUpdated: String
    var symbols: [String: [String: Double]]  // symbol -> {quarterId -> peValue}

    init(quarterRange: String, lastUpdated: String = "", symbols: [String: [String: Double]] = [:]) {
        self.quarterRange = quarterRange
        self.lastUpdated = lastUpdated
        self.symbols = symbols
    }
}

// MARK: - Forward P/E Cache Manager

actor ForwardPECacheManager {
    private let storage: CacheStorage<ForwardPECacheData>
    private let dateProvider: DateProvider
    private var cache: ForwardPECacheData?

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
            cacheURL: directory.appendingPathComponent("forward-pe-cache.json"),
            label: "forward P/E"
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

    func getAllData() -> [String: [String: Double]] {
        cache?.symbols ?? [:]
    }

    func getMissingSymbols(from symbols: [String]) -> [String] {
        guard let cache = cache else { return symbols }
        return symbols.filter { cache.symbols[$0] == nil }
    }

    func setForwardPE(symbol: String, quarterPEs: [String: Double]) {
        ensureCacheExists(quarterRange: cache?.quarterRange ?? "")
        cache?.symbols[symbol] = quarterPEs
        updateLastUpdated()
    }

    func needsInvalidation(currentRange: String) -> Bool {
        guard let cache = cache else { return true }
        return cache.quarterRange != currentRange
    }

    func clearForNewRange(_ range: String) {
        cache = ForwardPECacheData(quarterRange: range, lastUpdated: CacheTimestamp.current(dateProvider: dateProvider), symbols: [:])
    }

    // MARK: - Private

    private func ensureCacheExists(quarterRange: String) {
        guard cache == nil else { return }
        cache = ForwardPECacheData(quarterRange: quarterRange, lastUpdated: CacheTimestamp.current(dateProvider: dateProvider), symbols: [:])
    }

    private func updateLastUpdated() {
        guard let currentCache = cache else { return }
        cache = ForwardPECacheData(
            quarterRange: currentCache.quarterRange,
            lastUpdated: CacheTimestamp.current(dateProvider: dateProvider),
            symbols: currentCache.symbols
        )
    }
}
