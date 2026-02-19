import Foundation

// MARK: - EMA Fetch Methods

extension StockService {

    private func fetchChartCloses(symbol: String, range: String, interval: String) async -> [Double]? {
        switch SymbolRouting.historicalSource(for: symbol, finnhubApiKey: finnhubApiKey) {
        case .finnhub:
            if let closes = await fetchChartClosesFromFinnhub(symbol: symbol, range: range, interval: interval) { return closes }
            return await fetchChartClosesFromYahoo(symbol: symbol, range: range, interval: interval)
        case .yahoo:
            return await fetchChartClosesFromYahoo(symbol: symbol, range: range, interval: interval)
        }
    }

    private func fetchChartClosesFromFinnhub(symbol: String, range: String, interval: String) async -> [Double]? {
        guard let resolution = finnhubResolution(interval) else { return nil }
        let now = Int(Date().timeIntervalSince1970)
        guard let from = finnhubFromTimestamp(range: range, now: now) else { return nil }
        return await fetchFinnhubCloses(symbol: symbol, resolution: resolution, from: from, to: now)
    }

    private func fetchChartClosesFromYahoo(symbol: String, range: String, interval: String) async -> [Double]? {
        guard let url = URL(string: "\(APIEndpoints.chartBase)\(symbol)?range=\(range)&interval=\(interval)") else {
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

            return closes.compactMap { $0 }
        } catch {
            print("EMA fetch failed for \(symbol) (\(range)/\(interval)): \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Finnhub Conversion Helpers

    private func finnhubResolution(_ yahooInterval: String) -> String? {
        switch yahooInterval {
        case "1d": return "D"
        case "1wk": return "W"
        case "1mo": return "M"
        default: return nil
        }
    }

    private func finnhubFromTimestamp(range: String, now: Int) -> Int? {
        switch range {
        case "1mo": return now - 30 * 24 * 60 * 60
        case "6mo": return now - 180 * 24 * 60 * 60
        case "1y": return now - 365 * 24 * 60 * 60
        case "2y": return now - 730 * 24 * 60 * 60
        default: return nil
        }
    }

    // MARK: - EMA Calculations

    private func fetchEMA(symbol: String, range: String, interval: String) async -> Double? {
        guard let closes = await fetchChartCloses(symbol: symbol, range: range, interval: interval) else { return nil }
        return EMAAnalysis.calculate(closes: closes)
    }

    func fetchDailyEMA(symbol: String) async -> Double? {
        await fetchEMA(symbol: symbol, range: "1mo", interval: "1d")
    }

    func fetchWeeklyEMA(symbol: String) async -> Double? {
        await fetchEMA(symbol: symbol, range: "6mo", interval: "1wk")
    }

    func fetchMonthlyEMA(symbol: String) async -> Double? {
        await fetchEMA(symbol: symbol, range: "2y", interval: "1mo")
    }

    func fetchEMAEntry(symbol: String, precomputedDailyEMA: Double? = nil, now: Date = Date()) async -> EMACacheEntry? {
        async let weeklyCloses = fetchChartCloses(symbol: symbol, range: "6mo", interval: "1wk")
        async let month = fetchMonthlyEMA(symbol: symbol)

        let day: Double?
        if let precomputed = precomputedDailyEMA {
            day = precomputed
        } else {
            day = await fetchDailyEMA(symbol: symbol)
        }

        let closes = await weeklyCloses
        let weekEMA = closes.flatMap { EMAAnalysis.calculate(closes: $0) }

        // Crossover uses only completed weekly bars — drop current week before Friday 2PM ET
        let crossoverCloses: [Double]?
        if isWeeklyBarComplete(now: now) {
            crossoverCloses = closes
        } else if let c = closes, c.count > 1 {
            crossoverCloses = Array(c.dropLast())
        } else {
            crossoverCloses = nil
        }
        let crossover = crossoverCloses.flatMap { EMAAnalysis.detectWeeklyCrossover(closes: $0) }

        let monthEMA = await month
        guard day != nil || weekEMA != nil || monthEMA != nil else { return nil }
        return EMACacheEntry(day: day, week: weekEMA, month: monthEMA, weekCrossoverWeeksBelow: crossover)
    }

    private func isWeeklyBarComplete(now: Date) -> Bool {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        let weekday = calendar.component(.weekday, from: now)
        // Saturday (7) or Sunday (1)
        guard weekday != 7, weekday != 1 else { return true }
        // Friday (6) at 2PM+ ET
        guard weekday == 6 else { return false }
        return calendar.component(.hour, from: now) >= 14
    }

    func batchFetchEMAValues(symbols: [String]) async -> [String: EMACacheEntry] {
        let (finnhubSymbols, yahooSymbols) = SymbolRouting.partition(symbols, finnhubApiKey: finnhubApiKey)

        async let finnhubResults: [String: EMACacheEntry] = ThrottledTaskGroup.map(
            items: finnhubSymbols,
            maxConcurrency: ThrottledTaskGroup.FinnhubBackfill.maxConcurrency,
            delay: ThrottledTaskGroup.FinnhubBackfill.delayNanoseconds
        ) { symbol in
            await self.fetchEMAEntry(symbol: symbol)
        }

        async let yahooResults: [String: EMACacheEntry] = ThrottledTaskGroup.map(
            items: yahooSymbols,
            maxConcurrency: ThrottledTaskGroup.Backfill.maxConcurrency,
            delay: ThrottledTaskGroup.Backfill.delayNanoseconds
        ) { symbol in
            await self.fetchEMAEntry(symbol: symbol)
        }

        let fResults = await finnhubResults
        let yResults = await yahooResults
        return fResults.merging(yResults) { f, _ in f }
    }

    func batchFetchEMAValues(symbols: [String], dailyEMAs: [String: Double]) async -> [String: EMACacheEntry] {
        let (finnhubSymbols, yahooSymbols) = SymbolRouting.partition(symbols, finnhubApiKey: finnhubApiKey)

        async let finnhubResults: [String: EMACacheEntry] = ThrottledTaskGroup.map(
            items: finnhubSymbols,
            maxConcurrency: ThrottledTaskGroup.FinnhubBackfill.maxConcurrency,
            delay: ThrottledTaskGroup.FinnhubBackfill.delayNanoseconds
        ) { symbol in
            await self.fetchEMAEntry(symbol: symbol, precomputedDailyEMA: dailyEMAs[symbol])
        }

        async let yahooResults: [String: EMACacheEntry] = ThrottledTaskGroup.map(
            items: yahooSymbols,
            maxConcurrency: ThrottledTaskGroup.Backfill.maxConcurrency,
            delay: ThrottledTaskGroup.Backfill.delayNanoseconds
        ) { symbol in
            await self.fetchEMAEntry(symbol: symbol, precomputedDailyEMA: dailyEMAs[symbol])
        }

        let fResults = await finnhubResults
        let yResults = await yahooResults
        return fResults.merging(yResults) { f, _ in f }
    }
}
