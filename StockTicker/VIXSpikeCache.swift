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
        guard let currentCache = cache, let lastSpike = currentCache.spikes.last else {
            cache = VIXSpikeCacheData(lastUpdated: "", spikes: cache?.spikes ?? [], symbolPrices: [:])
            return
        }
        // Only clear the most recent spike date's prices — older spikes are historical and stable
        let updatedPrices = currentCache.symbolPrices.reduce(into: [String: [String: Double]]()) { dict, pair in
            var prices = pair.value
            prices.removeValue(forKey: lastSpike.dateString)
            dict[pair.key] = prices
        }
        cache = VIXSpikeCacheData(lastUpdated: "", spikes: currentCache.spikes, symbolPrices: updatedPrices)
    }

    /// Replaces spikes with new values. Clears symbol prices only for removed dates.
    /// Returns true if spike dates changed (callers should re-fetch missing dates).
    func replaceSpikesAndClearIfChanged(_ newSpikes: [VIXSpike]) -> Bool {
        let oldDateStrings = Set((cache?.spikes ?? []).map { $0.dateString })
        let newDateStrings = Set(newSpikes.map { $0.dateString })
        let datesChanged = oldDateStrings != newDateStrings

        ensureCacheExists()
        cache?.spikes = newSpikes
        if datesChanged {
            let removedDates = oldDateStrings.subtracting(newDateStrings)
            if !removedDates.isEmpty, let currentPrices = cache?.symbolPrices {
                cache?.symbolPrices = currentPrices.reduce(into: [String: [String: Double]]()) { dict, pair in
                    dict[pair.key] = pair.value.filter { !removedDates.contains($0.key) }
                }
            }
        }
        updateLastUpdated()
        return datesChanged
    }

    func getSymbolsNeedingRefresh(from symbols: [String]) -> [String] {
        guard let cache else { return symbols }
        let spikeKeys = Set(cache.spikes.map { $0.dateString })
        guard !spikeKeys.isEmpty else { return [] }
        return symbols.filter { symbol in
            guard let prices = cache.symbolPrices[symbol] else { return true }
            return !spikeKeys.isSubset(of: Set(prices.keys))
        }
    }

    func mergePrices(for symbol: String, newPrices: [String: Double]) {
        ensureCacheExists()
        var existing = cache?.symbolPrices[symbol] ?? [:]
        existing.merge(newPrices) { _, new in new }
        cache?.symbolPrices[symbol] = existing
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
