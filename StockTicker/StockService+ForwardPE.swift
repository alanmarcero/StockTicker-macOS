import Foundation

// MARK: - Forward P/E Timeseries Data

extension StockService {

    func fetchForwardPERatios(symbol: String, period1: Int, period2: Int) async -> [String: Double]? {
        guard let url = URL(string: "\(APIEndpoints.timeseriesBase)\(symbol)?type=quarterlyForwardPeRatio&period1=\(period1)&period2=\(period2)") else {
            return nil
        }

        do {
            let (data, response) = try await httpClient.data(from: url)
            guard response.isSuccessfulHTTP else { return nil }

            let decoded = try JSONDecoder().decode(YahooTimeseriesResponse.self, from: data)
            guard let entries = decoded.timeseries.result?.first?.quarterlyForwardPeRatio else {
                return [:]  // API success but no P/E data for this symbol
            }

            var result: [String: Double] = [:]
            for entry in entries {
                guard let quarterId = parseAsOfDateToQuarter(entry.asOfDate) else { continue }
                result[quarterId] = entry.reportedValue.raw
            }
            return result
        } catch {
            print("Forward P/E fetch failed for \(symbol): \(error.localizedDescription)")
            return nil
        }
    }

    func batchFetchForwardPERatios(symbols: [String], period1: Int, period2: Int) async -> [String: [String: Double]] {
        await ThrottledTaskGroup.map(items: symbols) { symbol in
            await self.fetchForwardPERatios(symbol: symbol, period1: period1, period2: period2)
        }
    }

    private func parseAsOfDateToQuarter(_ dateString: String) -> String? {
        let parts = dateString.split(separator: "-")
        guard parts.count == 3,
              let year = Int(parts[0]),
              let month = Int(parts[1]) else { return nil }
        let quarter = (month - 1) / 3 + 1
        return "Q\(quarter)-\(year)"
    }
}
