import Foundation

// MARK: - Cache Management

extension MenuBarController {

    // MARK: - Shared Helpers

    private var allWatchlistSymbols: [String] {
        config.watchlist + config.indexSymbols.map { $0.symbol }
    }

    var allCacheSymbols: [String] {
        let combined = Set(config.watchlist + config.universe + config.indexSymbols.map { $0.symbol })
        return Array(combined)
    }

    var extraStatsSymbols: [String] {
        let combined = Set(config.watchlist + config.universe)
        return Array(combined)
    }

    func cacheQuarterRange() -> String {
        let quarters = QuarterCalculation.lastNCompletedQuarters(from: dateProvider.now(), count: 12)
        guard let oldest = quarters.last, let newest = quarters.first else { return "" }
        return "\(oldest.identifier):\(newest.identifier)"
    }

    // MARK: - YTD Cache

    func loadYTDCache() async {
        await ytdCacheManager.load()

        if await ytdCacheManager.needsYearRollover() {
            await ytdCacheManager.clearForNewYear()
        }

        await fetchMissingYTDPrices()
    }

    func fetchMissingYTDPrices() async {
        let missingSymbols = await ytdCacheManager.getMissingSymbols(from: allCacheSymbols)

        guard !missingSymbols.isEmpty else {
            ytdPrices = await ytdCacheManager.getAllPrices()
            return
        }

        let fetched = await stockService.batchFetchYTDPrices(symbols: missingSymbols)
        for (symbol, price) in fetched {
            await ytdCacheManager.setStartPrice(for: symbol, price: price)
        }
        await ytdCacheManager.save()

        ytdPrices = await ytdCacheManager.getAllPrices()
    }

    // MARK: - Quarterly Cache

    func loadQuarterlyCache() async {
        await quarterlyCacheManager.load()
        quarterInfos = QuarterCalculation.lastNCompletedQuarters(from: dateProvider.now(), count: 12)
        await fetchMissingQuarterlyPrices()
    }

    func fetchMissingQuarterlyPrices() async {
        let now = dateProvider.now()
        quarterInfos = QuarterCalculation.lastNCompletedQuarters(from: now, count: 12)
        let fetchQuarters = QuarterCalculation.lastNCompletedQuarters(from: now, count: 13)

        for qi in fetchQuarters {
            let missingSymbols = await quarterlyCacheManager.getMissingSymbols(
                for: qi.identifier, from: extraStatsSymbols
            )
            guard !missingSymbols.isEmpty else { continue }

            let (period1, period2) = QuarterCalculation.quarterEndDateRange(year: qi.year, quarter: qi.quarter)
            let fetched = await stockService.batchFetchQuarterEndPrices(
                symbols: missingSymbols, period1: period1, period2: period2
            )

            guard !fetched.isEmpty else { continue }
            await quarterlyCacheManager.setPrices(quarter: qi.identifier, prices: fetched)
            await quarterlyCacheManager.save()
        }

        let activeIds = fetchQuarters.map { $0.identifier }
        await quarterlyCacheManager.pruneOldQuarters(keeping: activeIds)
        await quarterlyCacheManager.save()

        quarterlyPrices = await quarterlyCacheManager.getAllQuarterPrices()
    }

    // MARK: - YTD Attachment

    func attachYTDPricesToQuotes() {
        for (symbol, quote) in quotes {
            if let ytdPrice = ytdPrices[symbol] {
                quotes[symbol] = quote.withYTDStartPrice(ytdPrice)
            }
        }

        for (symbol, quote) in indexQuotes {
            if let ytdPrice = ytdPrices[symbol] {
                indexQuotes[symbol] = quote.withYTDStartPrice(ytdPrice)
            }
        }

        for (symbol, quote) in universeQuotes {
            if let ytdPrice = ytdPrices[symbol] {
                universeQuotes[symbol] = quote.withYTDStartPrice(ytdPrice)
            }
        }
    }

    // MARK: - Highest Close Cache

    func loadHighestCloseCache() async {
        await highestCloseCacheManager.load()

        let currentRange = cacheQuarterRange()
        if await highestCloseCacheManager.needsInvalidation(currentRange: currentRange) {
            await highestCloseCacheManager.clearForNewRange(currentRange)
        }

        if await highestCloseCacheManager.needsDailyRefresh() {
            await highestCloseCacheManager.clearPricesForDailyRefresh()
        }
    }

    func attachHighestClosesToQuotes() {
        for (symbol, quote) in quotes {
            if let highest = highestClosePrices[symbol] {
                quotes[symbol] = quote.withHighestClose(highest)
            }
        }

        for (symbol, quote) in universeQuotes {
            if let highest = highestClosePrices[symbol] {
                universeQuotes[symbol] = quote.withHighestClose(highest)
            }
        }
    }

    // MARK: - Forward P/E Cache

    func loadForwardPECache() async {
        await forwardPECacheManager.load()

        let currentRange = cacheQuarterRange()
        if await forwardPECacheManager.needsInvalidation(currentRange: currentRange) {
            await forwardPECacheManager.clearForNewRange(currentRange)
        }

        await fetchMissingForwardPERatios()
    }

    func fetchMissingForwardPERatios() async {
        let missingSymbols = await forwardPECacheManager.getMissingSymbols(from: extraStatsSymbols)

        guard !missingSymbols.isEmpty else {
            forwardPEData = await forwardPECacheManager.getAllData()
            return
        }

        let now = dateProvider.now()
        let quarters = QuarterCalculation.lastNCompletedQuarters(from: now, count: 12)
        guard let oldest = quarters.last else {
            forwardPEData = await forwardPECacheManager.getAllData()
            return
        }

        let period1 = QuarterCalculation.quarterStartTimestamp(year: oldest.year, quarter: oldest.quarter)
        let period2 = Int(now.timeIntervalSince1970)

        let fetched = await stockService.batchFetchForwardPERatios(
            symbols: missingSymbols, period1: period1, period2: period2
        )
        for (symbol, quarterPEs) in fetched {
            await forwardPECacheManager.setForwardPE(symbol: symbol, quarterPEs: quarterPEs)
        }
        await forwardPECacheManager.save()

        forwardPEData = await forwardPECacheManager.getAllData()
    }

    // MARK: - Swing Level Cache

    func loadSwingLevelCache() async {
        await swingLevelCacheManager.load()

        let currentRange = cacheQuarterRange()
        if await swingLevelCacheManager.needsInvalidation(currentRange: currentRange) {
            await swingLevelCacheManager.clearForNewRange(currentRange)
        }

        if await swingLevelCacheManager.needsDailyRefresh() {
            await swingLevelCacheManager.clearEntriesForDailyRefresh()
        }
    }

    // MARK: - RSI Cache

    func loadRSICache() async {
        await rsiCacheManager.load()

        if await rsiCacheManager.needsDailyRefresh() {
            await rsiCacheManager.clearForDailyRefresh()
        }
    }

    // MARK: - EMA Cache

    func loadEMACache() async {
        await emaCacheManager.load()

        if await emaCacheManager.needsDailyRefresh() {
            await emaCacheManager.clearForDailyRefresh()
        }
    }

    // MARK: - Cache Retry

    private enum CacheRetry {
        static let batchSize = 5
    }

    func retryMissingCacheEntries() async {
        await retryMissingEMAEntries()
        await retryMissingForwardPERatios()
    }

    private func retryMissingEMAEntries() async {
        let missing = await emaCacheManager.getMissingSymbols(from: allCacheSymbols)
        guard !missing.isEmpty else { return }

        let batch = Array(missing.prefix(CacheRetry.batchSize))
        let fetched = await stockService.batchFetchEMAValues(symbols: batch)
        guard !fetched.isEmpty else { return }

        for (symbol, entry) in fetched {
            await emaCacheManager.setEntry(for: symbol, entry: entry)
        }
        await emaCacheManager.save()
        emaEntries = await emaCacheManager.getAllEntries()
    }

    private func retryMissingForwardPERatios() async {
        let missing = await forwardPECacheManager.getMissingSymbols(from: extraStatsSymbols)
        guard !missing.isEmpty else { return }

        let batch = Array(missing.prefix(CacheRetry.batchSize))

        let now = dateProvider.now()
        let quarters = QuarterCalculation.lastNCompletedQuarters(from: now, count: 12)
        guard let oldest = quarters.last else { return }

        let period1 = QuarterCalculation.quarterStartTimestamp(year: oldest.year, quarter: oldest.quarter)
        let period2 = Int(now.timeIntervalSince1970)

        let fetched = await stockService.batchFetchForwardPERatios(
            symbols: batch, period1: period1, period2: period2
        )
        guard !fetched.isEmpty else { return }

        for (symbol, quarterPEs) in fetched {
            await forwardPECacheManager.setForwardPE(symbol: symbol, quarterPEs: quarterPEs)
        }
        await forwardPECacheManager.save()
        forwardPEData = await forwardPECacheManager.getAllData()
    }

    // MARK: - Consolidated Daily Analysis

    func fetchMissingDailyAnalysis() async {
        let highestCloseMissing = Set(await highestCloseCacheManager.getMissingSymbols(from: allCacheSymbols))
        let swingMissing = Set(await swingLevelCacheManager.getMissingSymbols(from: allCacheSymbols))
        let rsiMissing = Set(await rsiCacheManager.getMissingSymbols(from: allCacheSymbols))
        let emaMissing = Set(await emaCacheManager.getMissingSymbols(from: allCacheSymbols))

        let allMissing = Array(highestCloseMissing.union(swingMissing).union(rsiMissing).union(emaMissing))

        guard !allMissing.isEmpty else {
            highestClosePrices = await highestCloseCacheManager.getAllPrices()
            swingLevelEntries = await swingLevelCacheManager.getAllEntries()
            rsiValues = await rsiCacheManager.getAllValues()
            emaEntries = await emaCacheManager.getAllEntries()
            return
        }

        let now = dateProvider.now()
        let quarters = QuarterCalculation.lastNCompletedQuarters(from: now, count: 12)
        guard let oldest = quarters.last else {
            highestClosePrices = await highestCloseCacheManager.getAllPrices()
            swingLevelEntries = await swingLevelCacheManager.getAllEntries()
            rsiValues = await rsiCacheManager.getAllValues()
            emaEntries = await emaCacheManager.getAllEntries()
            return
        }

        let period1 = QuarterCalculation.quarterStartTimestamp(year: oldest.year, quarter: oldest.quarter)
        let period2 = Int(now.timeIntervalSince1970)

        let results = await stockService.batchFetchDailyAnalysis(
            symbols: allMissing, period1: period1, period2: period2
        )

        // Distribute results to individual caches
        var dailyEMAs: [String: Double] = [:]
        for (symbol, result) in results {
            if highestCloseMissing.contains(symbol), let highest = result.highestClose {
                await highestCloseCacheManager.setHighestClose(for: symbol, price: highest)
            }
            if swingMissing.contains(symbol), let entry = result.swingLevelEntry {
                await swingLevelCacheManager.setEntry(for: symbol, entry: entry)
            }
            if rsiMissing.contains(symbol), let rsi = result.rsi {
                await rsiCacheManager.setRSI(for: symbol, value: rsi)
            }
            if emaMissing.contains(symbol), let ema = result.dailyEMA {
                dailyEMAs[symbol] = ema
            }
        }

        if !highestCloseMissing.isEmpty { await highestCloseCacheManager.save() }
        if !swingMissing.isEmpty { await swingLevelCacheManager.save() }
        if !rsiMissing.isEmpty { await rsiCacheManager.save() }

        // Fetch remaining EMA timeframes (weekly + monthly) with pre-computed daily values
        let emaMissingArray = Array(emaMissing)
        if !emaMissingArray.isEmpty {
            let fetched = await stockService.batchFetchEMAValues(symbols: emaMissingArray, dailyEMAs: dailyEMAs)
            for (symbol, entry) in fetched {
                await emaCacheManager.setEntry(for: symbol, entry: entry)
            }
            await emaCacheManager.save()
        }

        highestClosePrices = await highestCloseCacheManager.getAllPrices()
        swingLevelEntries = await swingLevelCacheManager.getAllEntries()
        rsiValues = await rsiCacheManager.getAllValues()
        emaEntries = await emaCacheManager.getAllEntries()
    }

    func refreshDailyAnalysisIfNeeded() async {
        var needsRefresh = false

        if await highestCloseCacheManager.needsDailyRefresh() {
            await highestCloseCacheManager.clearPricesForDailyRefresh()
            needsRefresh = true
        }
        if await swingLevelCacheManager.needsDailyRefresh() {
            await swingLevelCacheManager.clearEntriesForDailyRefresh()
            needsRefresh = true
        }
        if await rsiCacheManager.needsDailyRefresh() {
            await rsiCacheManager.clearForDailyRefresh()
            needsRefresh = true
        }
        if await emaCacheManager.needsDailyRefresh() {
            await emaCacheManager.clearForDailyRefresh()
            needsRefresh = true
        }

        guard needsRefresh else { return }
        await fetchMissingDailyAnalysis()
    }

    // MARK: - Market Cap Attachment

    func attachMarketCapsToQuotes() {
        for (symbol, quote) in quotes {
            if let cap = marketCaps[symbol] {
                quotes[symbol] = quote.withMarketCap(cap)
            }
        }

        for (symbol, quote) in universeQuotes {
            if let cap = universeMarketCaps[symbol] {
                universeQuotes[symbol] = quote.withMarketCap(cap)
            }
        }
    }
}
