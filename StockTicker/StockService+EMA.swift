import Foundation

// MARK: - EMA Fetch Methods

extension StockService {

    private func fetchEMA(symbol: String, range: String, interval: String) async -> Double? {
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

            let validCloses = closes.compactMap { $0 }
            return EMAAnalysis.calculate(closes: validCloses)
        } catch {
            print("EMA fetch failed for \(symbol) (\(range)/\(interval)): \(error.localizedDescription)")
            return nil
        }
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
        async let week = fetchWeeklyEMA(symbol: symbol)
        async let month = fetchMonthlyEMA(symbol: symbol)
        return await EMACacheEntry(day: day, week: week, month: month)
    }

    func batchFetchEMAValues(symbols: [String]) async -> [String: EMACacheEntry] {
        await withTaskGroup(of: (String, EMACacheEntry).self) { group in
            for symbol in symbols {
                group.addTask {
                    (symbol, await self.fetchEMAEntry(symbol: symbol))
                }
            }

            var results: [String: EMACacheEntry] = [:]
            for await (symbol, entry) in group {
                results[symbol] = entry
            }
            return results
        }
    }
}
