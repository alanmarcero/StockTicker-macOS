import Foundation

// MARK: - Finnhub Real-Time Quote (free tier only supports /quote)

extension StockService {

    // MARK: - Finnhub Real-Time Quote

    func fetchFinnhubQuote(symbol: String) async -> StockQuote? {
        guard !finnhubApiKey.isEmpty,
              let url = URL(string: "\(APIEndpoints.finnhubQuoteBase)?symbol=\(symbol)") else { return nil }
        var request = URLRequest(url: url)
        request.setValue(finnhubApiKey, forHTTPHeaderField: "X-Finnhub-Token")

        do {
            let (data, response) = try await httpClient.data(for: request)
            guard response.isSuccessfulHTTP else { return nil }
            let decoded = try JSONDecoder().decode(FinnhubQuoteResponse.self, from: data)
            guard decoded.isValid else { return nil }
            return StockQuote(symbol: symbol, price: decoded.c, previousClose: decoded.pc, session: .regular)
        } catch {
            print("Finnhub quote fetch failed for \(symbol): \(error.localizedDescription)")
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
