import Foundation

// MARK: - Historical Price Data

extension StockService {

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

    func fetchHighestClose(symbol: String, period1: Int, period2: Int) async -> Double? {
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

    func fetchSwingLevels(symbol: String, period1: Int, period2: Int) async -> SwingLevelCacheEntry? {
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

            let validTimestamps = paired.map { $0.0 }
            let validCloses = paired.map { $0.1 }

            let swingResult = SwingAnalysis.analyze(closes: validCloses)

            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "M/d/yy"

            let breakoutDate: String? = swingResult.breakoutIndex.map { idx in
                dateFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(validTimestamps[idx])))
            }
            let breakdownDate: String? = swingResult.breakdownIndex.map { idx in
                dateFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(validTimestamps[idx])))
            }

            return SwingLevelCacheEntry(
                breakoutPrice: swingResult.breakoutPrice,
                breakoutDate: breakoutDate,
                breakdownPrice: swingResult.breakdownPrice,
                breakdownDate: breakdownDate
            )
        } catch {
            print("Swing levels fetch failed for \(symbol): \(error.localizedDescription)")
            return nil
        }
    }

    func batchFetchSwingLevels(symbols: [String], period1: Int, period2: Int) async -> [String: SwingLevelCacheEntry] {
        await ThrottledTaskGroup.map(items: symbols) { symbol in
            await self.fetchSwingLevels(symbol: symbol, period1: period1, period2: period2)
        }
    }

    func fetchRSI(symbol: String) async -> Double? {
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

            let validCloses = closes.compactMap { $0 }
            return RSIAnalysis.calculate(closes: validCloses)
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

    func fetchHistoricalClosePrice(symbol: String, period1: Int, period2: Int) async -> Double? {
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

    func batchFetchHistoricalClosePrices(
        symbols: [String],
        fetcher: @escaping @Sendable (String) async -> Double?
    ) async -> [String: Double] {
        await ThrottledTaskGroup.map(items: symbols) { symbol in
            await fetcher(symbol)
        }
    }
}
