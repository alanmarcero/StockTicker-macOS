import Foundation

// MARK: - Market Cap (v7 Quote API)

extension StockService {

    private enum QuoteFieldsLimits {
        static let batchSize = 50
    }

    func fetchQuoteFields(symbols: [String]) async -> (marketCaps: [String: Double], forwardPEs: [String: Double]) {
        guard !symbols.isEmpty else { return ([:], [:]) }

        if crumb == nil { await refreshCrumb() }

        var allCaps: [String: Double] = [:]
        var allPEs: [String: Double] = [:]

        // Use sequential loop for async operations to preserve crumb refresh logic and result aggregation
        for batch in stride(from: 0, to: symbols.count, by: QuoteFieldsLimits.batchSize) {
            let end = min(batch + QuoteFieldsLimits.batchSize, symbols.count)
            let chunk = Array(symbols[batch..<end])

            if let result = await performQuoteFieldsFetch(symbols: chunk) {
                mergeResults(result, into: &allCaps, and: &allPEs)
                continue
            }

            // Crumb may have expired, refresh and retry once
            await refreshCrumb()
            if let result = await performQuoteFieldsFetch(symbols: chunk) {
                mergeResults(result, into: &allCaps, and: &allPEs)
            }
        }

        return (allCaps, allPEs)
    }

    private func mergeResults(
        _ result: (marketCaps: [String: Double], forwardPEs: [String: Double]),
        into caps: inout [String: Double],
        and pes: inout [String: Double]
    ) {
        caps.mergeKeepingNew(result.marketCaps)
        pes.mergeKeepingNew(result.forwardPEs)
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

    func performQuoteFieldsFetch(symbols: [String]) async -> (marketCaps: [String: Double], forwardPEs: [String: Double])? {
        guard let crumb = crumb,
              let encodedCrumb = crumb.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return nil
        }

        let symbolList = symbols.joined(separator: ",")
        guard let url = URL(string: "\(APIEndpoints.quoteBase)?symbols=\(symbolList)&crumb=\(encodedCrumb)&fields=marketCap,quoteType,forwardPE") else {
            return nil
        }

        do {
            var request = URLRequest(url: url)
            request.setValue(APIEndpoints.userAgent, forHTTPHeaderField: "User-Agent")
            let (data, response) = try await httpClient.data(for: request)
            guard response.isSuccessfulHTTP else { return nil }

            let decoded = try JSONDecoder().decode(YahooQuoteResponse.self, from: data)
            let result = decoded.quoteResponse.result.reduce(into: (caps: [String: Double](), pes: [String: Double]())) { res, quote in
                if quote.quoteType != "ETF", let cap = quote.marketCap {
                    res.caps[quote.symbol] = cap
                }
                if let pe = quote.forwardPE {
                    res.pes[quote.symbol] = pe
                }
            }
            return (result.caps, result.pes)
        } catch {
            print("Quote fields fetch failed: \(error.localizedDescription)")
            return nil
        }
    }
}
