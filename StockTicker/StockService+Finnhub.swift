import Foundation

// MARK: - Finnhub Candle Fetch Methods

extension StockService {

    func fetchFinnhubDailyCandles(symbol: String, from period1: Int, to period2: Int) async -> (closes: [Double], timestamps: [Int])? {
        guard let key = finnhubApiKey,
              let url = URL(string: "\(APIEndpoints.finnhubCandleBase)?symbol=\(symbol)&resolution=D&from=\(period1)&to=\(period2)&token=\(key)") else {
            return nil
        }

        do {
            let (data, response) = try await httpClient.data(from: url)
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
        guard let key = finnhubApiKey,
              let url = URL(string: "\(APIEndpoints.finnhubCandleBase)?symbol=\(symbol)&resolution=\(resolution)&from=\(period1)&to=\(period2)&token=\(key)") else {
            return nil
        }

        do {
            let (data, response) = try await httpClient.data(from: url)
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
}
