import XCTest
@testable import StockTicker

// MARK: - Mock HTTP Client

final class MockHTTPClient: HTTPClient, @unchecked Sendable {
    var responses: [URL: Result<(Data, URLResponse), Error>] = [:]
    var requestedURLs: [URL] = []

    // Pattern-based responses for flexible URL matching
    var patternResponses: [(pattern: String, result: Result<(Data, URLResponse), Error>)] = []

    func setResponse(for urlContaining: String, data: Data, statusCode: Int = 200) {
        // We'll match by URL pattern in the data method
    }

    // MARK: - Quote API (v7) helpers

    func setQuoteSuccessResponse(for symbols: [String], prices: [Double]? = nil) {
        let priceList = prices ?? symbols.map { _ in 100.0 }
        var results: [String] = []
        for (index, symbol) in symbols.enumerated() {
            let price = priceList[index]
            results.append("""
            {
                "symbol": "\(symbol)",
                "regularMarketPrice": \(price),
                "regularMarketPreviousClose": \(price * 0.99),
                "marketState": "REGULAR"
            }
            """)
        }
        let json = """
        {
            "quoteResponse": {
                "result": [\(results.joined(separator: ","))],
                "error": null
            }
        }
        """
        let symbolsParam = symbols.joined(separator: ",")
        let url = URL(string: "https://query1.finance.yahoo.com/v7/finance/quote?symbols=\(symbolsParam)")!
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
        responses[url] = .success((json.data(using: .utf8)!, response))
    }

    func setQuoteSuccessResponseWithExtendedHours(
        for symbol: String,
        price: Double = 100.0,
        marketState: String = "POST",
        preMarketChangePercent: Double? = nil,
        postMarketChangePercent: Double? = nil
    ) {
        var fields = [
            "\"symbol\": \"\(symbol)\"",
            "\"regularMarketPrice\": \(price)",
            "\"regularMarketPreviousClose\": \(price * 0.99)",
            "\"marketState\": \"\(marketState)\""
        ]
        if let pre = preMarketChangePercent {
            fields.append("\"preMarketPrice\": \(price * (1 + pre / 100))")
            fields.append("\"preMarketChange\": \(price * pre / 100)")
            fields.append("\"preMarketChangePercent\": \(pre)")
        }
        if let post = postMarketChangePercent {
            fields.append("\"postMarketPrice\": \(price * (1 + post / 100))")
            fields.append("\"postMarketChange\": \(price * post / 100)")
            fields.append("\"postMarketChangePercent\": \(post)")
        }
        let fieldsStr = fields.joined(separator: ", ")
        let json = """
        {
            "quoteResponse": {
                "result": [{\(fieldsStr)}],
                "error": null
            }
        }
        """
        let url = URL(string: "https://query1.finance.yahoo.com/v7/finance/quote?symbols=\(symbol)")!
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
        responses[url] = .success((json.data(using: .utf8)!, response))
    }

    func setQuoteFailureResponse(for symbols: [String], statusCode: Int = 404) {
        let symbolsParam = symbols.joined(separator: ",")
        let url = URL(string: "https://query1.finance.yahoo.com/v7/finance/quote?symbols=\(symbolsParam)")!
        let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
        responses[url] = .success((Data(), response))
    }

    func setQuoteNetworkError(for symbols: [String]) {
        let symbolsParam = symbols.joined(separator: ",")
        let url = URL(string: "https://query1.finance.yahoo.com/v7/finance/quote?symbols=\(symbolsParam)")!
        responses[url] = .failure(URLError(.notConnectedToInternet))
    }

    func setQuoteInvalidJSON(for symbols: [String]) {
        let symbolsParam = symbols.joined(separator: ",")
        let url = URL(string: "https://query1.finance.yahoo.com/v7/finance/quote?symbols=\(symbolsParam)")!
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
        responses[url] = .success(("invalid json".data(using: .utf8)!, response))
    }

    func setQuoteNullResult(for symbols: [String]) {
        let json = """
        {
            "quoteResponse": {
                "result": null,
                "error": {
                    "code": "Not Found",
                    "description": "No data found"
                }
            }
        }
        """
        let symbolsParam = symbols.joined(separator: ",")
        let url = URL(string: "https://query1.finance.yahoo.com/v7/finance/quote?symbols=\(symbolsParam)")!
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
        responses[url] = .success((json.data(using: .utf8)!, response))
    }

    func setQuoteNullPrice(for symbol: String) {
        let json = """
        {
            "quoteResponse": {
                "result": [{
                    "symbol": "\(symbol)",
                    "regularMarketPrice": null,
                    "regularMarketPreviousClose": 100.0
                }],
                "error": null
            }
        }
        """
        let url = URL(string: "https://query1.finance.yahoo.com/v7/finance/quote?symbols=\(symbol)")!
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
        responses[url] = .success((json.data(using: .utf8)!, response))
    }

    // MARK: - Chart API (v8) helpers for StockService (with extended hours)

    func setSuccessResponse(for symbol: String, price: Double = 100.0) {
        let json = """
        {
            "chart": {
                "result": [{
                    "meta": {
                        "symbol": "\(symbol)",
                        "regularMarketPrice": \(price),
                        "chartPreviousClose": \(price * 0.99)
                    }
                }]
            }
        }
        """
        let url = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/\(symbol)?interval=1m&range=1d&includePrePost=true")!
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
        responses[url] = .success((json.data(using: .utf8)!, response))
    }

    func setFailureResponse(for symbol: String, statusCode: Int = 404) {
        let url = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/\(symbol)?interval=1m&range=1d&includePrePost=true")!
        let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
        responses[url] = .success((Data(), response))
    }

    func setNetworkError(for symbol: String) {
        let url = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/\(symbol)?interval=1m&range=1d&includePrePost=true")!
        responses[url] = .failure(URLError(.notConnectedToInternet))
    }

    func setInvalidJSON(for symbol: String) {
        let url = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/\(symbol)?interval=1m&range=1d&includePrePost=true")!
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
        responses[url] = .success(("invalid json".data(using: .utf8)!, response))
    }

    func setNullResult(for symbol: String) {
        let json = """
        {
            "chart": {
                "result": null,
                "error": {
                    "code": "Not Found",
                    "description": "No data found"
                }
            }
        }
        """
        let url = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/\(symbol)?interval=1m&range=1d&includePrePost=true")!
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
        responses[url] = .success((json.data(using: .utf8)!, response))
    }

    func setNullPrice(for symbol: String) {
        let json = """
        {
            "chart": {
                "result": [{
                    "meta": {
                        "symbol": "\(symbol)",
                        "regularMarketPrice": null,
                        "chartPreviousClose": 100.0
                    }
                }]
            }
        }
        """
        let url = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/\(symbol)?interval=1m&range=1d&includePrePost=true")!
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
        responses[url] = .success((json.data(using: .utf8)!, response))
    }

    // MARK: - Chart API helpers for YahooSymbolValidator (simple URL without extended hours)

    func setValidatorSuccessResponse(for symbol: String, price: Double = 100.0) {
        let json = """
        {
            "chart": {
                "result": [{
                    "meta": {
                        "symbol": "\(symbol)",
                        "regularMarketPrice": \(price),
                        "chartPreviousClose": \(price * 0.99)
                    }
                }]
            }
        }
        """
        let url = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/\(symbol)?interval=1d&range=1d")!
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
        responses[url] = .success((json.data(using: .utf8)!, response))
    }

    func setValidatorFailureResponse(for symbol: String, statusCode: Int = 404) {
        let url = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/\(symbol)?interval=1d&range=1d")!
        let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
        responses[url] = .success((Data(), response))
    }

    func setValidatorNetworkError(for symbol: String) {
        let url = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/\(symbol)?interval=1d&range=1d")!
        responses[url] = .failure(URLError(.notConnectedToInternet))
    }

    func setValidatorInvalidJSON(for symbol: String) {
        let url = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/\(symbol)?interval=1d&range=1d")!
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
        responses[url] = .success(("invalid json".data(using: .utf8)!, response))
    }

    func setValidatorNullResult(for symbol: String) {
        let json = """
        {
            "chart": {
                "result": null,
                "error": {
                    "code": "Not Found",
                    "description": "No data found"
                }
            }
        }
        """
        let url = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/\(symbol)?interval=1d&range=1d")!
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
        responses[url] = .success((json.data(using: .utf8)!, response))
    }

    func setValidatorNullPrice(for symbol: String) {
        let json = """
        {
            "chart": {
                "result": [{
                    "meta": {
                        "symbol": "\(symbol)",
                        "regularMarketPrice": null,
                        "chartPreviousClose": 100.0
                    }
                }]
            }
        }
        """
        let url = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/\(symbol)?interval=1d&range=1d")!
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
        responses[url] = .success((json.data(using: .utf8)!, response))
    }

    func data(from url: URL) async throws -> (Data, URLResponse) {
        requestedURLs.append(url)

        // Exact URL match
        if let result = responses[url] {
            switch result {
            case .success(let response):
                return response
            case .failure(let error):
                throw error
            }
        }

        // Pattern-based fallback (matches URL containing pattern string)
        let urlString = url.absoluteString
        for (pattern, result) in patternResponses {
            guard urlString.contains(pattern) else { continue }
            switch result {
            case .success(let response):
                return response
            case .failure(let error):
                throw error
            }
        }

        // Default: return 404
        let response = HTTPURLResponse(url: url, statusCode: 404, httpVersion: nil, headerFields: nil)!
        return (Data(), response)
    }
}

// MARK: - YahooSymbolValidator Tests

final class YahooSymbolValidatorTests: XCTestCase {

    func testValidate_validSymbol_returnsTrue() async {
        let mockClient = MockHTTPClient()
        mockClient.setValidatorSuccessResponse(for: "AAPL", price: 150.0)

        let validator = YahooSymbolValidator(httpClient: mockClient)
        let result = await validator.validate("AAPL")

        XCTAssertTrue(result)
    }

    func testValidate_invalidSymbol_returnsFalse() async {
        let mockClient = MockHTTPClient()
        mockClient.setValidatorFailureResponse(for: "INVALID", statusCode: 404)

        let validator = YahooSymbolValidator(httpClient: mockClient)
        let result = await validator.validate("INVALID")

        XCTAssertFalse(result)
    }

    func testValidate_networkError_returnsFalse() async {
        let mockClient = MockHTTPClient()
        mockClient.setValidatorNetworkError(for: "AAPL")

        let validator = YahooSymbolValidator(httpClient: mockClient)
        let result = await validator.validate("AAPL")

        XCTAssertFalse(result)
    }

    func testValidate_invalidJSON_returnsFalse() async {
        let mockClient = MockHTTPClient()
        mockClient.setValidatorInvalidJSON(for: "AAPL")

        let validator = YahooSymbolValidator(httpClient: mockClient)
        let result = await validator.validate("AAPL")

        XCTAssertFalse(result)
    }

    func testValidate_nullResult_returnsFalse() async {
        let mockClient = MockHTTPClient()
        mockClient.setValidatorNullResult(for: "AAPL")

        let validator = YahooSymbolValidator(httpClient: mockClient)
        let result = await validator.validate("AAPL")

        XCTAssertFalse(result)
    }

    func testValidate_nullPrice_returnsFalse() async {
        let mockClient = MockHTTPClient()
        mockClient.setValidatorNullPrice(for: "AAPL")

        let validator = YahooSymbolValidator(httpClient: mockClient)
        let result = await validator.validate("AAPL")

        XCTAssertFalse(result)
    }

    func testValidate_non200StatusCode_returnsFalse() async {
        let mockClient = MockHTTPClient()
        mockClient.setValidatorFailureResponse(for: "AAPL", statusCode: 500)

        let validator = YahooSymbolValidator(httpClient: mockClient)
        let result = await validator.validate("AAPL")

        XCTAssertFalse(result)
    }

    func testValidate_constructsCorrectURL() async {
        let mockClient = MockHTTPClient()
        mockClient.setValidatorSuccessResponse(for: "SPY", price: 450.0)

        let validator = YahooSymbolValidator(httpClient: mockClient)
        _ = await validator.validate("SPY")

        XCTAssertEqual(mockClient.requestedURLs.count, 1)
        XCTAssertEqual(
            mockClient.requestedURLs.first?.absoluteString,
            "https://query1.finance.yahoo.com/v8/finance/chart/SPY?interval=1d&range=1d"
        )
    }
}
