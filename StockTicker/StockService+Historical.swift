import Foundation

// MARK: - Daily Analysis Result

struct DailyAnalysisResult: Sendable {
    let highestClose: Double?
    let swingLevelEntry: SwingLevelCacheEntry?
    let rsi: Double?
    let dailyEMA: Double?
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
        dailyEMA: EMAAnalysis.calculate(closes: closes)
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
        guard let url = URL(string: "\(APIEndpoints.chartBase)\(symbol)?period1=\(period1)&period2=\(period2)&interval=1d") else {
            return nil
        }

        do {
            let (data, response) = try await httpClient.data(from: url)
            guard response.isSuccessfulHTTP else { return nil }

            let decoded = try JSONDecoder().decode(YahooChartResponse.self, from: data)
            guard let result = decoded.chart.result?.first,
                  let closes = result.indicators?.quote?.first?.close else {
                return nil
            }

            let validCloses = closes.compactMap { $0 }

            // Swing analysis requires paired timestamps + closes
            let timestamps = result.timestamp ?? []
            let paired = zip(timestamps, closes).compactMap { ts, close -> (Int, Double)? in
                guard let close else { return nil }
                return (ts, close)
            }
            let swingEntry = paired.isEmpty
                ? nil
                : buildSwingEntry(closes: paired.map { $0.1 }, timestamps: paired.map { $0.0 })

            return DailyAnalysisResult(
                highestClose: validCloses.max(),
                swingLevelEntry: swingEntry,
                rsi: RSIAnalysis.calculate(closes: validCloses),
                dailyEMA: EMAAnalysis.calculate(closes: validCloses)
            )
        } catch {
            print("Daily analysis fetch failed for \(symbol): \(error.localizedDescription)")
            return nil
        }
    }

    func batchFetchDailyAnalysis(symbols: [String], period1: Int, period2: Int) async -> [String: DailyAnalysisResult] {
        let (finnhubSymbols, yahooSymbols) = SymbolRouting.partition(symbols, finnhubApiKey: finnhubApiKey)

        async let finnhubResults: [String: DailyAnalysisResult] = ThrottledTaskGroup.map(
            items: finnhubSymbols,
            maxConcurrency: ThrottledTaskGroup.FinnhubBackfill.maxConcurrency,
            delay: ThrottledTaskGroup.FinnhubBackfill.delayNanoseconds
        ) { symbol in
            await self.fetchDailyAnalysis(symbol: symbol, period1: period1, period2: period2)
        }

        async let yahooResults: [String: DailyAnalysisResult] = ThrottledTaskGroup.map(
            items: yahooSymbols,
            maxConcurrency: ThrottledTaskGroup.Backfill.maxConcurrency,
            delay: ThrottledTaskGroup.Backfill.delayNanoseconds
        ) { symbol in
            await self.fetchDailyAnalysis(symbol: symbol, period1: period1, period2: period2)
        }

        let fResults = await finnhubResults
        let yResults = await yahooResults
        return fResults.merging(yResults) { f, _ in f }
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

        return await fetchHistoricalClosePrice(symbol: symbol, period1: period1, period2: period2)
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
        guard let url = URL(string: "\(APIEndpoints.chartBase)\(symbol)?period1=\(period1)&period2=\(period2)&interval=1d") else {
            return nil
        }

        do {
            let (data, response) = try await httpClient.data(from: url)
            guard response.isSuccessfulHTTP else { return nil }

            let decoded = try JSONDecoder().decode(YahooChartResponse.self, from: data)
            guard let result = decoded.chart.result?.first,
                  let closes = result.indicators?.quote?.first?.close,
                  let closePrice = closes.compactMap({ $0 }).last else {
                return nil
            }

            return closePrice
        } catch {
            print("Historical close price fetch failed for \(symbol): \(error.localizedDescription)")
            return nil
        }
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
        guard let url = URL(string: "\(APIEndpoints.chartBase)\(symbol)?period1=\(period1)&period2=\(period2)&interval=1d") else {
            return nil
        }

        do {
            let (data, response) = try await httpClient.data(from: url)
            guard response.isSuccessfulHTTP else { return nil }

            let decoded = try JSONDecoder().decode(YahooChartResponse.self, from: data)
            guard let result = decoded.chart.result?.first,
                  let closes = result.indicators?.quote?.first?.close else {
                return nil
            }

            return closes.compactMap({ $0 }).max()
        } catch {
            print("Highest close fetch failed for \(symbol): \(error.localizedDescription)")
            return nil
        }
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
        guard let url = URL(string: "\(APIEndpoints.chartBase)\(symbol)?period1=\(period1)&period2=\(period2)&interval=1d") else {
            return nil
        }

        do {
            let (data, response) = try await httpClient.data(from: url)
            guard response.isSuccessfulHTTP else { return nil }

            let decoded = try JSONDecoder().decode(YahooChartResponse.self, from: data)
            guard let result = decoded.chart.result?.first,
                  let closes = result.indicators?.quote?.first?.close else {
                return nil
            }

            let timestamps = result.timestamp ?? []
            let paired = zip(timestamps, closes).compactMap { ts, close -> (Int, Double)? in
                guard let close else { return nil }
                return (ts, close)
            }
            guard !paired.isEmpty else { return nil }

            return buildSwingEntry(closes: paired.map { $0.1 }, timestamps: paired.map { $0.0 })
        } catch {
            print("Swing levels fetch failed for \(symbol): \(error.localizedDescription)")
            return nil
        }
    }

    func batchFetchSwingLevels(symbols: [String], period1: Int, period2: Int) async -> [String: SwingLevelCacheEntry] {
        let (finnhubSymbols, yahooSymbols) = SymbolRouting.partition(symbols, finnhubApiKey: finnhubApiKey)

        async let finnhubResults: [String: SwingLevelCacheEntry] = ThrottledTaskGroup.map(
            items: finnhubSymbols,
            maxConcurrency: ThrottledTaskGroup.FinnhubBackfill.maxConcurrency,
            delay: ThrottledTaskGroup.FinnhubBackfill.delayNanoseconds
        ) { symbol in
            await self.fetchSwingLevels(symbol: symbol, period1: period1, period2: period2)
        }

        async let yahooResults: [String: SwingLevelCacheEntry] = ThrottledTaskGroup.map(
            items: yahooSymbols,
            maxConcurrency: ThrottledTaskGroup.Backfill.maxConcurrency,
            delay: ThrottledTaskGroup.Backfill.delayNanoseconds
        ) { symbol in
            await self.fetchSwingLevels(symbol: symbol, period1: period1, period2: period2)
        }

        let fResults = await finnhubResults
        let yResults = await yahooResults
        return fResults.merging(yResults) { f, _ in f }
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
        guard let url = URL(string: "\(APIEndpoints.chartBase)\(symbol)?range=1y&interval=1d") else {
            return nil
        }

        do {
            let (data, response) = try await httpClient.data(from: url)
            guard response.isSuccessfulHTTP else { return nil }

            let decoded = try JSONDecoder().decode(YahooChartResponse.self, from: data)
            guard let result = decoded.chart.result?.first,
                  let closes = result.indicators?.quote?.first?.close else {
                return nil
            }

            return RSIAnalysis.calculate(closes: closes.compactMap { $0 })
        } catch {
            print("RSI fetch failed for \(symbol): \(error.localizedDescription)")
            return nil
        }
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
        let (finnhubSymbols, yahooSymbols) = SymbolRouting.partition(symbols, finnhubApiKey: finnhubApiKey)

        async let finnhubResults: [String: Double] = ThrottledTaskGroup.map(
            items: finnhubSymbols,
            maxConcurrency: ThrottledTaskGroup.FinnhubBackfill.maxConcurrency,
            delay: ThrottledTaskGroup.FinnhubBackfill.delayNanoseconds
        ) { symbol in
            await fetcher(symbol)
        }

        async let yahooResults: [String: Double] = ThrottledTaskGroup.map(
            items: yahooSymbols,
            maxConcurrency: ThrottledTaskGroup.Backfill.maxConcurrency,
            delay: ThrottledTaskGroup.Backfill.delayNanoseconds
        ) { symbol in
            await fetcher(symbol)
        }

        let fResults = await finnhubResults
        let yResults = await yahooResults
        return fResults.merging(yResults) { f, _ in f }
    }
}
