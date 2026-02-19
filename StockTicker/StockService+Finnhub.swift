import Foundation

// MARK: - Finnhub Candle Fetch Methods

extension StockService {

    private func finnhubRequest(symbol: String, resolution: String, from period1: Int, to period2: Int) -> URLRequest? {
        guard let key = finnhubApiKey,
              let url = URL(string: "\(APIEndpoints.finnhubCandleBase)?symbol=\(symbol)&resolution=\(resolution)&from=\(period1)&to=\(period2)") else {
            return nil
        }
        var request = URLRequest(url: url)
        request.setValue(key, forHTTPHeaderField: "X-Finnhub-Token")
        return request
    }

    func fetchFinnhubDailyCandles(symbol: String, from period1: Int, to period2: Int) async -> (closes: [Double], timestamps: [Int])? {
        guard let request = finnhubRequest(symbol: symbol, resolution: "D", from: period1, to: period2) else { return nil }

        do {
            let (data, response) = try await httpClient.data(for: request)
            guard response.isSuccessfulHTTP else { return nil }

            let decoded = try JSONDecoder().decode(FinnhubCandleResponse.self, from: data)
            guard decoded.isValid, let closes = decoded.c, let timestamps = decoded.t else { return nil }
            return (closes, timestamps)
        } catch {
            print("Finnhub daily candles fetch failed for \(symbol): \(error.localizedDescription)")
            return nil
        }
    }

    func fetchFinnhubCloses(symbol: String, resolution: String, from period1: Int, to period2: Int) async -> [Double]? {
        guard let request = finnhubRequest(symbol: symbol, resolution: resolution, from: period1, to: period2) else { return nil }

        do {
            let (data, response) = try await httpClient.data(for: request)
            guard response.isSuccessfulHTTP else { return nil }

            let decoded = try JSONDecoder().decode(FinnhubCandleResponse.self, from: data)
            guard decoded.isValid, let closes = decoded.c else { return nil }
            return closes
        } catch {
            print("Finnhub closes fetch failed for \(symbol) (\(resolution)): \(error.localizedDescription)")
            return nil
        }
    }

    func fetchFinnhubHistoricalClosePrice(symbol: String, period1: Int, period2: Int) async -> Double? {
        guard let result = await fetchFinnhubDailyCandles(symbol: symbol, from: period1, to: period2) else { return nil }
        return result.closes.last
    }

    // MARK: - Finnhub Real-Time Quote

    func fetchFinnhubQuote(symbol: String) async -> StockQuote? {
        guard let key = finnhubApiKey,
              let url = URL(string: "\(APIEndpoints.finnhubQuoteBase)?symbol=\(symbol)") else { return nil }
        var request = URLRequest(url: url)
        request.setValue(key, forHTTPHeaderField: "X-Finnhub-Token")

        do {
            let (data, response) = try await httpClient.data(for: request)
            guard response.isSuccessfulHTTP else { return nil }
            let decoded = try JSONDecoder().decode(FinnhubQuoteResponse.self, from: data)
            guard decoded.isValid else { return nil }
            return StockQuote(symbol: symbol, price: decoded.c, previousClose: decoded.pc, session: .regular)
        } catch {
            return nil
        }
    }

    func fetchFinnhubQuotes(symbols: [String]) async -> [String: StockQuote] {
        await ThrottledTaskGroup.map(
            items: symbols,
            maxConcurrency: ThrottledTaskGroup.FinnhubQuote.maxConcurrency,
            delay: ThrottledTaskGroup.FinnhubQuote.delayNanoseconds
        ) { symbol in
            await self.fetchFinnhubQuote(symbol: symbol)
        }
    }
}
