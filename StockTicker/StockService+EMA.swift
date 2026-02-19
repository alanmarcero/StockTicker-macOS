import Foundation

// MARK: - EMA Fetch Methods

extension StockService {

    private func fetchChartCloses(symbol: String, range: String, interval: String) async -> [Double]? {
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
        await ThrottledTaskGroup.map(
            items: symbols,
            maxConcurrency: ThrottledTaskGroup.Backfill.maxConcurrency,
            delay: ThrottledTaskGroup.Backfill.delayNanoseconds
        ) { symbol in
            await self.fetchEMAEntry(symbol: symbol)
        }
    }

    func batchFetchEMAValues(symbols: [String], dailyEMAs: [String: Double]) async -> [String: EMACacheEntry] {
        await ThrottledTaskGroup.map(
            items: symbols,
            maxConcurrency: ThrottledTaskGroup.Backfill.maxConcurrency,
            delay: ThrottledTaskGroup.Backfill.delayNanoseconds
        ) { symbol in
            await self.fetchEMAEntry(symbol: symbol, precomputedDailyEMA: dailyEMAs[symbol])
        }
    }
}
