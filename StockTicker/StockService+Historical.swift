import Foundation

// MARK: - Daily Analysis Result

struct DailyAnalysisResult: Sendable {
    let highestClose: Double?
    let lowestClose: Double?
    let swingLevelEntry: SwingLevelCacheEntry?
    let rsi: Double?
    let dailyEMA: Double?
    let dailyAboveCount: Int?
}

// MARK: - Shared Analysis Helpers

private let swingDateFormatter: DateFormatter = {
    let fmt = DateFormatter()
    fmt.dateFormat = "M/d/yy"
    return fmt
}()

private func buildSwingEntry(closes: [Double], timestamps: [Int]) -> SwingLevelCacheEntry? {
    guard !closes.isEmpty else { return nil }
    let swingResult = SwingAnalysis.analyze(closes: closes)
    let breakoutDate = swingResult.breakoutIndex.map { idx in
        swingDateFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(timestamps[idx])))
    }
    let breakdownDate = swingResult.breakdownIndex.map { idx in
        swingDateFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(timestamps[idx])))
    }
    return SwingLevelCacheEntry(
        breakoutPrice: swingResult.breakoutPrice,
        breakoutDate: breakoutDate,
        breakdownPrice: swingResult.breakdownPrice,
        breakdownDate: breakdownDate
    )
}

private func buildDailyAnalysisResult(closes: [Double], timestamps: [Int]) -> DailyAnalysisResult {
    let last252 = closes.count > 252 ? Array(closes.suffix(252)) : closes
    return DailyAnalysisResult(
        highestClose: closes.max(),
        lowestClose: last252.min(),
        swingLevelEntry: buildSwingEntry(closes: closes, timestamps: timestamps),
        rsi: RSIAnalysis.calculate(closes: closes),
        dailyEMA: EMAAnalysis.calculate(closes: closes),
        dailyAboveCount: EMAAnalysis.countPeriodsAbove(closes: closes)
    )
}

// MARK: - Historical Price Data

extension StockService {

    // MARK: - Daily Analysis (Consolidated)

    func fetchDailyAnalysis(symbol: String, period1: Int, period2: Int) async -> DailyAnalysisResult? {
        guard let url = APIEndpoints.chartURL(symbol: symbol, period1: period1, period2: period2) else { return nil }
        guard let result = await fetchYahooClosesAndTimestamps(symbol: symbol, url: url) else { return nil }
        return buildDailyAnalysisResult(closes: result.closes, timestamps: result.timestamps)
    }

    func batchFetchDailyAnalysis(symbols: [String], period1: Int, period2: Int) async -> [String: DailyAnalysisResult] {
        await partitionedBatchFetch(symbols: symbols) { symbol in
            await self.fetchDailyAnalysis(symbol: symbol, period1: period1, period2: period2)
        }
    }

    // MARK: - YTD & Quarter End Prices

    func fetchYTDStartPrice(symbol: String) async -> Double? {
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())

        guard let dec31 = calendar.date(from: DateComponents(year: currentYear - 1, month: 12, day: 31)),
              let jan2 = calendar.date(from: DateComponents(year: currentYear, month: 1, day: 2)) else {
            return nil
        }

        let period1 = Int(dec31.timeIntervalSince1970)
        let period2 = Int(jan2.timeIntervalSince1970)

        if let price = await fetchHistoricalClosePrice(symbol: symbol, period1: period1, period2: period2) {
            return price
        }

        // Fallback for symbols that IPO'd after Dec 31: use first available close of the year
        return await fetchFirstCloseOfYear(symbol: symbol, year: currentYear)
    }

    private func fetchFirstCloseOfYear(symbol: String, year: Int) async -> Double? {
        let calendar = Calendar.current
        guard let jan1 = calendar.date(from: DateComponents(year: year, month: 1, day: 1)) else { return nil }
        let period1 = Int(jan1.timeIntervalSince1970)
        let period2 = Int(Date().timeIntervalSince1970)

        guard let url = APIEndpoints.chartURL(symbol: symbol, period1: period1, period2: period2) else { return nil }
        return await fetchYahooCloses(symbol: symbol, url: url)?.first
    }

    func batchFetchYTDPrices(symbols: [String]) async -> [String: Double] {
        await batchFetchHistoricalClosePrices(symbols: symbols) { symbol in
            await self.fetchYTDStartPrice(symbol: symbol)
        }
    }

    func fetchQuarterEndPrice(symbol: String, period1: Int, period2: Int) async -> Double? {
        await fetchHistoricalClosePrice(symbol: symbol, period1: period1, period2: period2)
    }

    func batchFetchQuarterEndPrices(symbols: [String], period1: Int, period2: Int) async -> [String: Double] {
        await batchFetchHistoricalClosePrices(symbols: symbols) { symbol in
            await self.fetchHistoricalClosePrice(symbol: symbol, period1: period1, period2: period2)
        }
    }

    // MARK: - Historical Close Price

    func fetchHistoricalClosePrice(symbol: String, period1: Int, period2: Int) async -> Double? {
        guard let url = APIEndpoints.chartURL(symbol: symbol, period1: period1, period2: period2) else { return nil }
        return await fetchYahooCloses(symbol: symbol, url: url)?.last
    }

    // MARK: - Highest Close

    func fetchHighestClose(symbol: String, period1: Int, period2: Int) async -> Double? {
        guard let url = APIEndpoints.chartURL(symbol: symbol, period1: period1, period2: period2) else { return nil }
        return await fetchYahooCloses(symbol: symbol, url: url)?.max()
    }

    func batchFetchHighestCloses(symbols: [String], period1: Int, period2: Int) async -> [String: Double] {
        await batchFetchHistoricalClosePrices(symbols: symbols) { symbol in
            await self.fetchHighestClose(symbol: symbol, period1: period1, period2: period2)
        }
    }

    // MARK: - Swing Levels

    func fetchSwingLevels(symbol: String, period1: Int, period2: Int) async -> SwingLevelCacheEntry? {
        guard let url = APIEndpoints.chartURL(symbol: symbol, period1: period1, period2: period2) else { return nil }
        guard let result = await fetchYahooClosesAndTimestamps(symbol: symbol, url: url) else { return nil }
        return buildSwingEntry(closes: result.closes, timestamps: result.timestamps)
    }

    func batchFetchSwingLevels(symbols: [String], period1: Int, period2: Int) async -> [String: SwingLevelCacheEntry] {
        await partitionedBatchFetch(symbols: symbols) { symbol in
            await self.fetchSwingLevels(symbol: symbol, period1: period1, period2: period2)
        }
    }

    // MARK: - RSI

    func fetchRSI(symbol: String) async -> Double? {
        guard let url = APIEndpoints.chartURL(symbol: symbol, range: "1y", interval: "1d") else { return nil }
        guard let closes = await fetchYahooCloses(symbol: symbol, url: url) else { return nil }
        return RSIAnalysis.calculate(closes: closes)
    }

    func batchFetchRSIValues(symbols: [String]) async -> [String: Double] {
        await batchFetchHistoricalClosePrices(symbols: symbols) { symbol in
            await self.fetchRSI(symbol: symbol)
        }
    }

    // MARK: - VIX Spikes

    func fetchVIXSpikes(period1: Int, period2: Int) async -> [VIXSpike]? {
        guard let url = APIEndpoints.chartURL(symbol: "^VIX", period1: period1, period2: period2) else { return nil }
        guard let result = await fetchYahooClosesAndTimestamps(symbol: "^VIX", url: url) else { return nil }
        let spikes = VIXSpikeAnalysis.detectSpikes(closes: result.closes, timestamps: result.timestamps)
        guard !spikes.isEmpty else { return nil }
        return spikes
    }

    func fetchClosePricesOnDates(symbol: String, period1: Int, period2: Int, targetTimestamps: [Int]) async -> [String: Double]? {
        guard !targetTimestamps.isEmpty else { return nil }
        guard let url = APIEndpoints.chartURL(symbol: symbol, period1: period1, period2: period2) else { return nil }
        guard let result = await fetchYahooClosesAndTimestamps(symbol: symbol, url: url) else { return nil }
        guard !result.timestamps.isEmpty else { return nil }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "M/d/yy"

        var prices: [String: Double] = [:]
        for target in targetTimestamps {
            let closestIndex = result.timestamps.enumerated().min(by: {
                abs($0.element - target) < abs($1.element - target)
            })!.offset
            let dateString = dateFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(target)))
            prices[dateString] = result.closes[closestIndex]
        }
        return prices
    }

    // MARK: - Batch Helper

    func batchFetchHistoricalClosePrices(
        symbols: [String],
        fetcher: @escaping @Sendable (String) async -> Double?
    ) async -> [String: Double] {
        await partitionedBatchFetch(symbols: symbols, fetch: fetcher)
    }
}
