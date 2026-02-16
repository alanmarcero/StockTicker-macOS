import Foundation

// MARK: - Market Cap (v7 Quote API)

extension StockService {

    func fetchMarketCaps(symbols: [String]) async -> [String: Double] {
        guard !symbols.isEmpty else { return [:] }

        if crumb == nil { await refreshCrumb() }

        if let result = await performMarketCapFetch(symbols: symbols) {
            return result
        }

        // Crumb may have expired, refresh and retry once
        await refreshCrumb()
        return await performMarketCapFetch(symbols: symbols) ?? [:]
    }

    func refreshCrumb() async {
        guard let testURL = URL(string: APIEndpoints.cookieSetup) else { return }
        var testRequest = URLRequest(url: testURL)
        testRequest.setValue(APIEndpoints.userAgent, forHTTPHeaderField: "User-Agent")
        _ = try? await URLSession.shared.data(for: testRequest)

        guard let crumbURL = URL(string: APIEndpoints.crumbFetch) else { return }
        var crumbRequest = URLRequest(url: crumbURL)
        crumbRequest.setValue(APIEndpoints.userAgent, forHTTPHeaderField: "User-Agent")
        guard let (data, response) = try? await URLSession.shared.data(for: crumbRequest),
              response.isSuccessfulHTTP else { return }
        crumb = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func performMarketCapFetch(symbols: [String]) async -> [String: Double]? {
        guard let crumb = crumb,
              let encodedCrumb = crumb.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return nil
        }

        let symbolList = symbols.joined(separator: ",")
        guard let url = URL(string: "\(APIEndpoints.quoteBase)?symbols=\(symbolList)&crumb=\(encodedCrumb)&fields=marketCap,quoteType") else {
            return nil
        }

        do {
            var request = URLRequest(url: url)
            request.setValue(APIEndpoints.userAgent, forHTTPHeaderField: "User-Agent")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard response.isSuccessfulHTTP else { return nil }

            let decoded = try JSONDecoder().decode(YahooQuoteResponse.self, from: data)
            var result: [String: Double] = [:]
            for quote in decoded.quoteResponse.result {
                guard quote.quoteType != "ETF", let cap = quote.marketCap else { continue }
                result[quote.symbol] = cap
            }
            return result
        } catch {
            print("Market cap fetch failed: \(error.localizedDescription)")
            return nil
        }
    }
}
