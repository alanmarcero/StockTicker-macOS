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
}
