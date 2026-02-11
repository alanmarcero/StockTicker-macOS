import Foundation

// MARK: - Protocol for Dependency Injection

protocol StockServiceProtocol: Sendable {
    func fetchQuote(symbol: String) async -> StockQuote?
    func fetchQuotes(symbols: [String]) async -> [String: StockQuote]
    func fetchMarketState(symbol: String) async -> String?
    func fetchYTDStartPrice(symbol: String) async -> Double?
    func batchFetchYTDPrices(symbols: [String]) async -> [String: Double]
    func fetchQuarterEndPrice(symbol: String, period1: Int, period2: Int) async -> Double?
    func batchFetchQuarterEndPrices(symbols: [String], period1: Int, period2: Int) async -> [String: Double]
}

// MARK: - HTTP Client Protocol

protocol HTTPClient: Sendable {
    func data(from url: URL) async throws -> (Data, URLResponse)
}

extension URLSession: HTTPClient {}

extension URLResponse {
    var isSuccessfulHTTP: Bool {
        (self as? HTTPURLResponse)?.statusCode == 200
    }
}

// MARK: - Stock Service Implementation

actor StockService: StockServiceProtocol {
    private let httpClient: HTTPClient
    private let baseURL = "https://query1.finance.yahoo.com/v8/finance/chart/"

    init(httpClient: HTTPClient = LoggingHTTPClient()) {
        self.httpClient = httpClient
    }

    func fetchQuote(symbol: String) async -> StockQuote? {
        guard let response = await fetchChartData(symbol: symbol) else { return nil }

        guard let result = response.chart.result?.first,
              let regularMarketPrice = result.meta.regularMarketPrice,
              let previousClose = result.meta.chartPreviousClose else {
            return nil
        }

        let meta = result.meta
        let session = TradingSession(fromYahooState: meta.marketState)

        // Calculate extended hours data from chart indicators if available
        let extendedHoursData = calculateExtendedHoursData(
            result: result,
            regularMarketPrice: regularMarketPrice,
            previousClose: previousClose
        )

        return StockQuote(
            symbol: symbol,
            price: regularMarketPrice,
            previousClose: previousClose,
            session: session,
            preMarketPrice: extendedHoursData.preMarketPrice ?? meta.preMarketPrice,
            preMarketChange: extendedHoursData.preMarketChange ?? meta.preMarketChange,
            preMarketChangePercent: extendedHoursData.preMarketChangePercent ?? meta.preMarketChangePercent,
            postMarketPrice: extendedHoursData.postMarketPrice ?? meta.postMarketPrice,
            postMarketChange: extendedHoursData.postMarketChange ?? meta.postMarketChange,
            postMarketChangePercent: extendedHoursData.postMarketChangePercent ?? meta.postMarketChangePercent
        )
    }

    func fetchQuotes(symbols: [String]) async -> [String: StockQuote] {
        await withTaskGroup(of: (String, StockQuote?).self) { group in
            for symbol in symbols {
                group.addTask {
                    (symbol, await self.fetchQuote(symbol: symbol))
                }
            }

            var results: [String: StockQuote] = [:]
            for await (symbol, quote) in group {
                if let quote = quote {
                    results[symbol] = quote
                }
            }
            return results
        }
    }

    func fetchMarketState(symbol: String = "SPY") async -> String? {
        guard let response = await fetchChartData(symbol: symbol) else { return nil }
        return response.chart.result?.first?.meta.marketState
    }

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

    // MARK: - Private

    private func fetchHistoricalClosePrice(symbol: String, period1: Int, period2: Int) async -> Double? {
        guard let url = URL(string: "\(baseURL)\(symbol)?period1=\(period1)&period2=\(period2)&interval=1d") else {
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
            return nil
        }
    }

    private func batchFetchHistoricalClosePrices(
        symbols: [String],
        fetcher: @escaping @Sendable (String) async -> Double?
    ) async -> [String: Double] {
        await withTaskGroup(of: (String, Double?).self) { group in
            for symbol in symbols {
                group.addTask {
                    (symbol, await fetcher(symbol))
                }
            }

            var results: [String: Double] = [:]
            for await (symbol, price) in group {
                if let price = price {
                    results[symbol] = price
                }
            }
            return results
        }
    }

    private func fetchChartData(symbol: String) async -> YahooChartResponse? {
        // Use 1-minute intervals with includePrePost to get extended hours data
        guard let url = URL(string: "\(baseURL)\(symbol)?interval=1m&range=1d&includePrePost=true") else {
            return nil
        }

        do {
            let (data, response) = try await httpClient.data(from: url)
            guard response.isSuccessfulHTTP else { return nil }

            return try JSONDecoder().decode(YahooChartResponse.self, from: data)
        } catch {
            return nil
        }
    }

    // MARK: - Extended Hours Calculation

    private struct ExtendedHoursData {
        var preMarketPrice: Double?
        var preMarketChange: Double?
        var preMarketChangePercent: Double?
        var postMarketPrice: Double?
        var postMarketChange: Double?
        var postMarketChangePercent: Double?
    }

    /// Calculates extended hours price changes from the chart indicator data
    /// The chart data with includePrePost=true contains pre/post market prices
    private func calculateExtendedHoursData(
        result: ChartData,
        regularMarketPrice: Double,
        previousClose: Double
    ) -> ExtendedHoursData {
        var data = ExtendedHoursData()

        // Get the latest close price from the indicators
        guard let closes = result.indicators?.quote?.first?.close,
              !closes.isEmpty else {
            return data
        }

        // Find the last non-nil close price
        var latestPrice: Double?
        for close in closes.reversed() {
            if let price = close {
                latestPrice = price
                break
            }
        }

        guard let currentPrice = latestPrice else {
            return data
        }

        // Determine if we're in extended hours based on time
        let timeBasedSession = StockQuote.currentTimeBasedSession()

        // Only calculate if the current price differs from regular market price
        // and we're in an extended hours session
        let priceDifference = abs(currentPrice - regularMarketPrice)
        let significantDifference = priceDifference > TradingHours.extendedHoursPriceThreshold

        if significantDifference {
            switch timeBasedSession {
            case .preMarket:
                // Pre-market: change is from last regular close (regularMarketPrice) to current price
                // During pre-market, regularMarketPrice = yesterday's close
                data.preMarketPrice = currentPrice
                data.preMarketChange = currentPrice - regularMarketPrice
                if regularMarketPrice != 0 {
                    data.preMarketChangePercent = ((currentPrice - regularMarketPrice) / regularMarketPrice) * 100
                }
            case .afterHours:
                // After-hours: change is from regular close to current price
                data.postMarketPrice = currentPrice
                data.postMarketChange = currentPrice - regularMarketPrice
                if regularMarketPrice != 0 {
                    data.postMarketChangePercent = ((currentPrice - regularMarketPrice) / regularMarketPrice) * 100
                }
            case .regular, .closed:
                // During regular hours or when truly closed, no extended hours data
                break
            }
        }

        return data
    }
}
