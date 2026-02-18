import Foundation

// MARK: - Protocol for Dependency Injection

protocol StockServiceProtocol: Sendable {
    func fetchQuote(symbol: String) async -> StockQuote?
    func fetchQuotes(symbols: [String]) async -> [String: StockQuote]
    func fetchMarketState(symbol: String) async -> String?
    func fetchQuoteFields(symbols: [String]) async -> (marketCaps: [String: Double], forwardPEs: [String: Double])
    func fetchYTDStartPrice(symbol: String) async -> Double?
    func batchFetchYTDPrices(symbols: [String]) async -> [String: Double]
    func fetchQuarterEndPrice(symbol: String, period1: Int, period2: Int) async -> Double?
    func batchFetchQuarterEndPrices(symbols: [String], period1: Int, period2: Int) async -> [String: Double]
    func fetchHighestClose(symbol: String, period1: Int, period2: Int) async -> Double?
    func batchFetchHighestCloses(symbols: [String], period1: Int, period2: Int) async -> [String: Double]
    func fetchForwardPERatios(symbol: String, period1: Int, period2: Int) async -> [String: Double]?
    func batchFetchForwardPERatios(symbols: [String], period1: Int, period2: Int) async -> [String: [String: Double]]
    func fetchSwingLevels(symbol: String, period1: Int, period2: Int) async -> SwingLevelCacheEntry?
    func batchFetchSwingLevels(symbols: [String], period1: Int, period2: Int) async -> [String: SwingLevelCacheEntry]
    func fetchRSI(symbol: String) async -> Double?
    func batchFetchRSIValues(symbols: [String]) async -> [String: Double]
    func fetchDailyEMA(symbol: String) async -> Double?
    func fetchWeeklyEMA(symbol: String) async -> Double?
    func fetchMonthlyEMA(symbol: String) async -> Double?
    func batchFetchEMAValues(symbols: [String]) async -> [String: EMACacheEntry]
}

// MARK: - HTTP Client Protocol

protocol HTTPClient: Sendable {
    func data(from url: URL) async throws -> (Data, URLResponse)
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension HTTPClient {
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        guard let url = request.url else { throw URLError(.badURL) }
        return try await data(from: url)
    }
}

extension URLSession: HTTPClient {
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await data(for: request, delegate: nil)
    }
}

extension URLResponse {
    var isSuccessfulHTTP: Bool {
        (self as? HTTPURLResponse)?.statusCode == 200
    }
}

// MARK: - Stock Service Implementation

actor StockService: StockServiceProtocol {
    let httpClient: HTTPClient
    var crumb: String?

    enum APIEndpoints {
        static let chartBase = "https://query1.finance.yahoo.com/v8/finance/chart/"
        static let cookieSetup = "https://fc.yahoo.com/v1/test"
        static let crumbFetch = "https://query2.finance.yahoo.com/v1/test/getcrumb"
        static let quoteBase = "https://query2.finance.yahoo.com/v7/finance/quote"
        static let timeseriesBase = "https://query2.finance.yahoo.com/ws/fundamentals-timeseries/v1/finance/timeseries/"
        static let userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)"
    }

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
        await ThrottledTaskGroup.map(items: symbols) { symbol in
            await self.fetchQuote(symbol: symbol)
        }
    }

    func fetchMarketState(symbol: String = "SPY") async -> String? {
        guard let response = await fetchChartData(symbol: symbol) else { return nil }
        return response.chart.result?.first?.meta.marketState
    }

    func fetchChartData(symbol: String) async -> YahooChartResponse? {
        // Use 1-minute intervals with includePrePost to get extended hours data
        guard let url = URL(string: "\(APIEndpoints.chartBase)\(symbol)?interval=1m&range=1d&includePrePost=true") else {
            return nil
        }

        do {
            let (data, response) = try await httpClient.data(from: url)
            guard response.isSuccessfulHTTP else { return nil }

            return try JSONDecoder().decode(YahooChartResponse.self, from: data)
        } catch {
            print("Chart data fetch failed for \(symbol): \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Extended Hours Calculation

    struct ExtendedHoursData {
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

        guard let closes = result.indicators?.quote?.first?.close,
              !closes.isEmpty else {
            return data
        }

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
                break
            }
        }

        return data
    }
}
