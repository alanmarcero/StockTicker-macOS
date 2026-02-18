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

    func fetchEMAEntry(symbol: String) async -> EMACacheEntry {
        async let day = fetchDailyEMA(symbol: symbol)
        async let weeklyCloses = fetchChartCloses(symbol: symbol, range: "6mo", interval: "1wk")
        async let month = fetchMonthlyEMA(symbol: symbol)

        let closes = await weeklyCloses
        let weekEMA = closes.flatMap { EMAAnalysis.calculate(closes: $0) }
        let crossover = closes.flatMap { EMAAnalysis.detectWeeklyCrossover(closes: $0) }

        return await EMACacheEntry(day: day, week: weekEMA, month: month, weekCrossoverWeeksBelow: crossover)
    }

    func batchFetchEMAValues(symbols: [String]) async -> [String: EMACacheEntry] {
        await ThrottledTaskGroup.map(items: symbols) { symbol in
            await self.fetchEMAEntry(symbol: symbol)
        }
    }
}
