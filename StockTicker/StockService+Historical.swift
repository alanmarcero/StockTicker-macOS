import Foundation

// MARK: - Daily Analysis Result

struct DailyAnalysisResult: Sendable {
    let highestClose: Double?
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
    DailyAnalysisResult(
        highestClose: closes.max(),
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
        switch SymbolRouting.historicalSource(for: symbol, finnhubApiKey: finnhubApiKey) {
        case .finnhub:
            if let result = await fetchDailyAnalysisFromFinnhub(symbol: symbol, period1: period1, period2: period2) { return result }
            return await fetchDailyAnalysisFromYahoo(symbol: symbol, period1: period1, period2: period2)
        case .yahoo:
            return await fetchDailyAnalysisFromYahoo(symbol: symbol, period1: period1, period2: period2)
        }
    }

    private func fetchDailyAnalysisFromFinnhub(symbol: String, period1: Int, period2: Int) async -> DailyAnalysisResult? {
        guard let result = await fetchFinnhubDailyCandles(symbol: symbol, from: period1, to: period2) else { return nil }
        guard !result.closes.isEmpty else { return nil }
        return buildDailyAnalysisResult(closes: result.closes, timestamps: result.timestamps)
    }

    private func fetchDailyAnalysisFromYahoo(symbol: String, period1: Int, period2: Int) async -> DailyAnalysisResult? {
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

        switch SymbolRouting.historicalSource(for: symbol, finnhubApiKey: finnhubApiKey) {
        case .finnhub:
            if let result = await fetchFinnhubDailyCandles(symbol: symbol, from: period1, to: period2),
               let first = result.closes.first { return first }
            return await fetchFirstCloseFromYahoo(symbol: symbol, period1: period1, period2: period2)
        case .yahoo:
            return await fetchFirstCloseFromYahoo(symbol: symbol, period1: period1, period2: period2)
        }
    }

    private func fetchFirstCloseFromYahoo(symbol: String, period1: Int, period2: Int) async -> Double? {
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
        switch SymbolRouting.historicalSource(for: symbol, finnhubApiKey: finnhubApiKey) {
        case .finnhub:
            if let price = await fetchFinnhubHistoricalClosePrice(symbol: symbol, period1: period1, period2: period2) { return price }
            return await fetchHistoricalClosePriceFromYahoo(symbol: symbol, period1: period1, period2: period2)
        case .yahoo:
            return await fetchHistoricalClosePriceFromYahoo(symbol: symbol, period1: period1, period2: period2)
        }
    }

    private func fetchHistoricalClosePriceFromYahoo(symbol: String, period1: Int, period2: Int) async -> Double? {
        guard let url = APIEndpoints.chartURL(symbol: symbol, period1: period1, period2: period2) else { return nil }
        return await fetchYahooCloses(symbol: symbol, url: url)?.last
    }

    // MARK: - Highest Close

    func fetchHighestClose(symbol: String, period1: Int, period2: Int) async -> Double? {
        switch SymbolRouting.historicalSource(for: symbol, finnhubApiKey: finnhubApiKey) {
        case .finnhub:
            if let result = await fetchFinnhubDailyCandles(symbol: symbol, from: period1, to: period2),
               let highest = result.closes.max() { return highest }
            return await fetchHighestCloseFromYahoo(symbol: symbol, period1: period1, period2: period2)
        case .yahoo:
            return await fetchHighestCloseFromYahoo(symbol: symbol, period1: period1, period2: period2)
        }
    }

    private func fetchHighestCloseFromYahoo(symbol: String, period1: Int, period2: Int) async -> Double? {
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
        switch SymbolRouting.historicalSource(for: symbol, finnhubApiKey: finnhubApiKey) {
        case .finnhub:
            if let entry = await fetchSwingLevelsFromFinnhub(symbol: symbol, period1: period1, period2: period2) { return entry }
            return await fetchSwingLevelsFromYahoo(symbol: symbol, period1: period1, period2: period2)
        case .yahoo:
            return await fetchSwingLevelsFromYahoo(symbol: symbol, period1: period1, period2: period2)
        }
    }

    private func fetchSwingLevelsFromFinnhub(symbol: String, period1: Int, period2: Int) async -> SwingLevelCacheEntry? {
        guard let result = await fetchFinnhubDailyCandles(symbol: symbol, from: period1, to: period2) else { return nil }
        return buildSwingEntry(closes: result.closes, timestamps: result.timestamps)
    }

    private func fetchSwingLevelsFromYahoo(symbol: String, period1: Int, period2: Int) async -> SwingLevelCacheEntry? {
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
        switch SymbolRouting.historicalSource(for: symbol, finnhubApiKey: finnhubApiKey) {
        case .finnhub:
            if let rsi = await fetchRSIFromFinnhub(symbol: symbol) { return rsi }
            return await fetchRSIFromYahoo(symbol: symbol)
        case .yahoo:
            return await fetchRSIFromYahoo(symbol: symbol)
        }
    }

    private func fetchRSIFromFinnhub(symbol: String) async -> Double? {
        let now = Int(Date().timeIntervalSince1970)
        let oneYearAgo = now - 365 * 24 * 60 * 60
        guard let closes = await fetchFinnhubCloses(symbol: symbol, resolution: "D", from: oneYearAgo, to: now) else { return nil }
        return RSIAnalysis.calculate(closes: closes)
    }

    private func fetchRSIFromYahoo(symbol: String) async -> Double? {
        guard let url = APIEndpoints.chartURL(symbol: symbol, range: "1y", interval: "1d") else { return nil }
        guard let closes = await fetchYahooCloses(symbol: symbol, url: url) else { return nil }
        return RSIAnalysis.calculate(closes: closes)
    }

    func batchFetchRSIValues(symbols: [String]) async -> [String: Double] {
        await batchFetchHistoricalClosePrices(symbols: symbols) { symbol in
            await self.fetchRSI(symbol: symbol)
        }
    }

    // MARK: - Batch Helper

    func batchFetchHistoricalClosePrices(
        symbols: [String],
        fetcher: @escaping @Sendable (String) async -> Double?
    ) async -> [String: Double] {
        await partitionedBatchFetch(symbols: symbols, fetch: fetcher)
    }
}
