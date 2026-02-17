import Foundation

// MARK: - Cache Management

extension MenuBarController {

    // MARK: - YTD Cache

    func loadYTDCache() async {
        await ytdCacheManager.load()

        if await ytdCacheManager.needsYearRollover() {
            await ytdCacheManager.clearForNewYear()
        }

        await fetchMissingYTDPrices()
    }

    func fetchMissingYTDPrices() async {
        let allSymbols = config.watchlist + config.indexSymbols.map { $0.symbol }
        let missingSymbols = await ytdCacheManager.getMissingSymbols(from: allSymbols)

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
        quarterInfos = QuarterCalculation.lastNCompletedQuarters(from: Date(), count: 12)
        await fetchMissingQuarterlyPrices()
    }

    func fetchMissingQuarterlyPrices() async {
        quarterInfos = QuarterCalculation.lastNCompletedQuarters(from: Date(), count: 12)
        let fetchQuarters = QuarterCalculation.lastNCompletedQuarters(from: Date(), count: 13)

        for qi in fetchQuarters {
            let missingSymbols = await quarterlyCacheManager.getMissingSymbols(
                for: qi.identifier, from: config.watchlist
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
    }

    // MARK: - Highest Close Cache

    func loadHighestCloseCache() async {
        await highestCloseCacheManager.load()

        let currentRange = highestCloseQuarterRange()
        if await highestCloseCacheManager.needsInvalidation(currentRange: currentRange) {
            await highestCloseCacheManager.clearForNewRange(currentRange)
        }

        if await highestCloseCacheManager.needsDailyRefresh() {
            await highestCloseCacheManager.clearPricesForDailyRefresh()
        }

        await fetchMissingHighestCloses()
    }

    func fetchMissingHighestCloses() async {
        let allSymbols = config.watchlist + config.indexSymbols.map { $0.symbol }
        let missingSymbols = await highestCloseCacheManager.getMissingSymbols(from: allSymbols)

        guard !missingSymbols.isEmpty else {
            highestClosePrices = await highestCloseCacheManager.getAllPrices()
            return
        }

        let quarters = QuarterCalculation.lastNCompletedQuarters(from: Date(), count: 12)
        guard let oldest = quarters.last else {
            highestClosePrices = await highestCloseCacheManager.getAllPrices()
            return
        }

        let period1 = QuarterCalculation.quarterStartTimestamp(year: oldest.year, quarter: oldest.quarter)
        let period2 = Int(Date().timeIntervalSince1970)

        let fetched = await stockService.batchFetchHighestCloses(
            symbols: missingSymbols, period1: period1, period2: period2
        )
        for (symbol, price) in fetched {
            await highestCloseCacheManager.setHighestClose(for: symbol, price: price)
        }
        await highestCloseCacheManager.save()

        highestClosePrices = await highestCloseCacheManager.getAllPrices()
    }

    func attachHighestClosesToQuotes() {
        for (symbol, quote) in quotes {
            if let highest = highestClosePrices[symbol] {
                quotes[symbol] = quote.withHighestClose(highest)
            }
        }
    }

    func refreshHighestClosesIfNeeded() async {
        guard await highestCloseCacheManager.needsDailyRefresh() else { return }
        await highestCloseCacheManager.clearPricesForDailyRefresh()
        await fetchMissingHighestCloses()
    }

    func highestCloseQuarterRange() -> String {
        let quarters = QuarterCalculation.lastNCompletedQuarters(from: Date(), count: 12)
        guard let oldest = quarters.last, let newest = quarters.first else { return "" }
        return "\(oldest.identifier):\(newest.identifier)"
    }

    // MARK: - Forward P/E Cache

    func loadForwardPECache() async {
        await forwardPECacheManager.load()

        let currentRange = forwardPEQuarterRange()
        if await forwardPECacheManager.needsInvalidation(currentRange: currentRange) {
            await forwardPECacheManager.clearForNewRange(currentRange)
        }

        await fetchMissingForwardPERatios()
    }

    func fetchMissingForwardPERatios() async {
        let missingSymbols = await forwardPECacheManager.getMissingSymbols(from: config.watchlist)

        guard !missingSymbols.isEmpty else {
            forwardPEData = await forwardPECacheManager.getAllData()
            return
        }

        let quarters = QuarterCalculation.lastNCompletedQuarters(from: Date(), count: 12)
        guard let oldest = quarters.last else {
            forwardPEData = await forwardPECacheManager.getAllData()
            return
        }

        let period1 = QuarterCalculation.quarterStartTimestamp(year: oldest.year, quarter: oldest.quarter)
        let period2 = Int(Date().timeIntervalSince1970)

        let fetched = await stockService.batchFetchForwardPERatios(
            symbols: missingSymbols, period1: period1, period2: period2
        )
        for (symbol, quarterPEs) in fetched {
            await forwardPECacheManager.setForwardPE(symbol: symbol, quarterPEs: quarterPEs)
        }
        await forwardPECacheManager.save()

        forwardPEData = await forwardPECacheManager.getAllData()
    }

    func forwardPEQuarterRange() -> String {
        let quarters = QuarterCalculation.lastNCompletedQuarters(from: Date(), count: 12)
        guard let oldest = quarters.last, let newest = quarters.first else { return "" }
        return "\(oldest.identifier):\(newest.identifier)"
    }

    // MARK: - Swing Level Cache

    func loadSwingLevelCache() async {
        await swingLevelCacheManager.load()

        let currentRange = swingLevelQuarterRange()
        if await swingLevelCacheManager.needsInvalidation(currentRange: currentRange) {
            await swingLevelCacheManager.clearForNewRange(currentRange)
        }

        if await swingLevelCacheManager.needsDailyRefresh() {
            await swingLevelCacheManager.clearEntriesForDailyRefresh()
        }

        await fetchMissingSwingLevels()
    }

    func fetchMissingSwingLevels() async {
        let allSymbols = config.watchlist + config.indexSymbols.map { $0.symbol }
        let missingSymbols = await swingLevelCacheManager.getMissingSymbols(from: allSymbols)

        guard !missingSymbols.isEmpty else {
            swingLevelEntries = await swingLevelCacheManager.getAllEntries()
            return
        }

        let quarters = QuarterCalculation.lastNCompletedQuarters(from: Date(), count: 12)
        guard let oldest = quarters.last else {
            swingLevelEntries = await swingLevelCacheManager.getAllEntries()
            return
        }

        let period1 = QuarterCalculation.quarterStartTimestamp(year: oldest.year, quarter: oldest.quarter)
        let period2 = Int(Date().timeIntervalSince1970)

        let fetched = await stockService.batchFetchSwingLevels(
            symbols: missingSymbols, period1: period1, period2: period2
        )
        for (symbol, entry) in fetched {
            await swingLevelCacheManager.setEntry(for: symbol, entry: entry)
        }
        await swingLevelCacheManager.save()

        swingLevelEntries = await swingLevelCacheManager.getAllEntries()
    }

    func refreshSwingLevelsIfNeeded() async {
        guard await swingLevelCacheManager.needsDailyRefresh() else { return }
        await swingLevelCacheManager.clearEntriesForDailyRefresh()
        await fetchMissingSwingLevels()
    }

    func swingLevelQuarterRange() -> String {
        let quarters = QuarterCalculation.lastNCompletedQuarters(from: Date(), count: 12)
        guard let oldest = quarters.last, let newest = quarters.first else { return "" }
        return "\(oldest.identifier):\(newest.identifier)"
    }

    // MARK: - RSI Cache

    func loadRSICache() async {
        await rsiCacheManager.load()

        if await rsiCacheManager.needsDailyRefresh() {
            await rsiCacheManager.clearForDailyRefresh()
        }

        await fetchMissingRSIValues()
    }

    func fetchMissingRSIValues() async {
        let allSymbols = config.watchlist + config.indexSymbols.map { $0.symbol }
        let missingSymbols = await rsiCacheManager.getMissingSymbols(from: allSymbols)

        guard !missingSymbols.isEmpty else {
            rsiValues = await rsiCacheManager.getAllValues()
            return
        }

        let fetched = await stockService.batchFetchRSIValues(symbols: missingSymbols)
        for (symbol, value) in fetched {
            await rsiCacheManager.setRSI(for: symbol, value: value)
        }
        await rsiCacheManager.save()

        rsiValues = await rsiCacheManager.getAllValues()
    }

    func refreshRSIIfNeeded() async {
        guard await rsiCacheManager.needsDailyRefresh() else { return }
        await rsiCacheManager.clearForDailyRefresh()
        await fetchMissingRSIValues()
    }

    // MARK: - Market Cap Attachment

    func attachMarketCapsToQuotes() {
        for (symbol, quote) in quotes {
            if let cap = marketCaps[symbol] {
                quotes[symbol] = quote.withMarketCap(cap)
            }
        }
    }
}
