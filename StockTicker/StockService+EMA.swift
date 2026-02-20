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

    private func fetchWeeklyClosesWithTimestamps(symbol: String) async -> (closes: [Double], timestamps: [Int])? {
        guard let url = URL(string: "\(APIEndpoints.chartBase)\(symbol)?range=6mo&interval=1wk") else { return nil }

        do {
            let (data, response) = try await httpClient.data(from: url)
            guard response.isSuccessfulHTTP else { return nil }

            let decoded = try JSONDecoder().decode(YahooChartResponse.self, from: data)
            guard let result = decoded.chart.result?.first,
                  let rawCloses = result.indicators?.quote?.first?.close,
                  let rawTimestamps = result.timestamp else { return nil }

            var closes: [Double] = []
            var timestamps: [Int] = []
            for (ts, c) in zip(rawTimestamps, rawCloses) {
                guard let close = c else { continue }
                closes.append(close)
                timestamps.append(ts)
            }
            guard !closes.isEmpty else { return nil }
            return (closes, timestamps)
        } catch {
            print("Weekly closes fetch failed for \(symbol): \(error.localizedDescription)")
            return nil
        }
    }

    private func completedWeeklyBarCount(timestamps: [Int], now: Date) -> Int {
        let calendar = MarketSchedule.easternCalendar
        let weekday = calendar.component(.weekday, from: now)
        let daysFromMonday = (weekday + 5) % 7
        let monday = calendar.date(byAdding: .day, value: -daysFromMonday, to: calendar.startOfDay(for: now))!
        let cutoff = Int(monday.timeIntervalSince1970)
        return timestamps.filter { $0 < cutoff }.count
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

    func fetchEMAEntry(symbol: String, precomputedDailyEMA: Double? = nil, now: Date = Date()) async -> EMACacheEntry? {
        async let weeklyData = fetchWeeklyClosesWithTimestamps(symbol: symbol)

        let day: Double?
        if let precomputed = precomputedDailyEMA {
            day = precomputed
        } else {
            day = await fetchDailyEMA(symbol: symbol)
        }

        let weekly = await weeklyData
        let weekEMA = weekly.flatMap { EMAAnalysis.calculate(closes: $0.closes) }

        // Crossover uses only completed weekly bars — filter by timestamp, not dropLast
        let crossoverCloses: [Double]?
        if let w = weekly {
            if isCurrentWeekSneakPeek(now: now) {
                crossoverCloses = w.closes
            } else {
                let count = completedWeeklyBarCount(timestamps: w.timestamps, now: now)
                crossoverCloses = count > 0 ? Array(w.closes[0..<count]) : nil
            }
        } else {
            crossoverCloses = nil
        }
        let crossover = crossoverCloses.flatMap { EMAAnalysis.detectWeeklyCrossover(closes: $0) }
        let belowCount = weekly.flatMap { EMAAnalysis.countWeeksBelow(closes: $0.closes) }

        guard day != nil || weekEMA != nil else { return nil }
        return EMACacheEntry(day: day, week: weekEMA, weekCrossoverWeeksBelow: crossover, weekBelowCount: belowCount)
    }

    /// Include the current week's bar from Friday 2PM ET onward through the weekend.
    /// Before Friday 2PM, only completed prior-week bars are used. On Monday, the new week
    /// starts and the prior week naturally enters the completed set via timestamp filtering.
    private func isCurrentWeekSneakPeek(now: Date) -> Bool {
        let calendar = MarketSchedule.easternCalendar
        let weekday = calendar.component(.weekday, from: now)
        // Saturday (7) or Sunday (1): week's bar is complete
        if weekday == 1 || weekday == 7 { return true }
        // Friday (6): from 2PM ET onward
        guard weekday == 6 else { return false }
        let hour = calendar.component(.hour, from: now)
        return hour >= 14
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
