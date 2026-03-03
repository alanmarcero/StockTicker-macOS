import Foundation

// MARK: - VIX Spike Cache Data Model

struct VIXSpikeCacheData: Codable {
    let lastUpdated: String
    var spikes: [VIXSpike]
    var symbolPrices: [String: [String: Double]]

    init(lastUpdated: String = "", spikes: [VIXSpike] = [], symbolPrices: [String: [String: Double]] = [:]) {
        self.lastUpdated = lastUpdated
        self.spikes = spikes
        self.symbolPrices = symbolPrices
    }
}

// MARK: - VIX Spike Cache Manager

actor VIXSpikeCacheManager {
    private let storage: CacheStorage<VIXSpikeCacheData>
    private let dateProvider: DateProvider
    private var cache: VIXSpikeCacheData?

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
            cacheURL: directory.appendingPathComponent("vix-spike-cache.json"),
            label: "VIXSpike"
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

    func getSpikes() -> [VIXSpike] {
        cache?.spikes ?? []
    }

    func setSpikes(_ spikes: [VIXSpike]) {
        ensureCacheExists()
        cache?.spikes = spikes
        updateLastUpdated()
    }

    func getPrices(for symbol: String) -> [String: Double]? {
        cache?.symbolPrices[symbol]
    }

    func getAllSymbolPrices() -> [String: [String: Double]] {
        cache?.symbolPrices ?? [:]
    }

    func setPrices(for symbol: String, prices: [String: Double]) {
        ensureCacheExists()
        cache?.symbolPrices[symbol] = prices
        updateLastUpdated()
    }

    func getMissingSymbols(from symbols: [String]) -> [String] {
        guard let cache else { return symbols }
        return symbols.filter { cache.symbolPrices[$0] == nil }
    }

    func needsDailyRefresh() -> Bool {
        guard let cache else { return true }
        return CacheTimestamp.needsDailyRefresh(lastUpdated: cache.lastUpdated, dateProvider: dateProvider)
    }

    func clearForDailyRefresh() {
        cache = VIXSpikeCacheData(lastUpdated: "", spikes: cache?.spikes ?? [], symbolPrices: [:])
    }

    /// Replaces spikes with new values. Clears symbol prices if any dateStrings changed.
    /// Returns true if symbol prices were cleared (callers should re-fetch).
    func replaceSpikesAndClearIfChanged(_ newSpikes: [VIXSpike]) -> Bool {
        let oldDateStrings = Set((cache?.spikes ?? []).map { $0.dateString })
        let newDateStrings = Set(newSpikes.map { $0.dateString })
        let datesChanged = oldDateStrings != newDateStrings

        ensureCacheExists()
        cache?.spikes = newSpikes
        if datesChanged {
            cache?.symbolPrices = [:]
        }
        updateLastUpdated()
        return datesChanged
    }

    // MARK: - Private

    private func ensureCacheExists() {
        guard cache == nil else { return }
        cache = VIXSpikeCacheData(lastUpdated: CacheTimestamp.current(dateProvider: dateProvider))
    }

    private func updateLastUpdated() {
        guard let currentCache = cache else { return }
        cache = VIXSpikeCacheData(
            lastUpdated: CacheTimestamp.current(dateProvider: dateProvider),
            spikes: currentCache.spikes,
            symbolPrices: currentCache.symbolPrices
        )
    }
}
