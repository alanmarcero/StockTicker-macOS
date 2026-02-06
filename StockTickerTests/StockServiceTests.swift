import XCTest
@testable import StockTicker

// MARK: - StockService Tests

final class StockServiceTests: XCTestCase {

    // MARK: - fetchQuote tests

    func testFetchQuote_validResponse_returnsQuote() async {
        let mockClient = MockHTTPClient()
        let json = """
        {
            "chart": {
                "result": [{
                    "meta": {
                        "symbol": "AAPL",
                        "regularMarketPrice": 150.50,
                        "chartPreviousClose": 148.00,
                        "marketState": "REGULAR",
                        "preMarketPrice": 149.00,
                        "preMarketChange": 1.00,
                        "preMarketChangePercent": 0.67,
                        "postMarketPrice": 151.00,
                        "postMarketChange": 0.50,
                        "postMarketChangePercent": 0.33
                    }
                }]
            }
        }
        """
        let url = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/AAPL?interval=1m&range=1d&includePrePost=true")!
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
        mockClient.responses[url] = .success((json.data(using: .utf8)!, response))

        let service = StockService(httpClient: mockClient)
        let quote = await service.fetchQuote(symbol: "AAPL")

        XCTAssertNotNil(quote)
        XCTAssertEqual(quote?.symbol, "AAPL")
        XCTAssertEqual(quote?.price, 150.50)
        XCTAssertEqual(quote?.previousClose, 148.00)
        XCTAssertEqual(quote?.session, .regular)
    }

    func testFetchQuote_networkError_returnsNil() async {
        let mockClient = MockHTTPClient()
        let url = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/AAPL?interval=1m&range=1d&includePrePost=true")!
        mockClient.responses[url] = .failure(URLError(.notConnectedToInternet))

        let service = StockService(httpClient: mockClient)
        let quote = await service.fetchQuote(symbol: "AAPL")

        XCTAssertNil(quote)
    }

    func testFetchQuote_non200StatusCode_returnsNil() async {
        let mockClient = MockHTTPClient()
        let url = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/AAPL?interval=1m&range=1d&includePrePost=true")!
        let response = HTTPURLResponse(url: url, statusCode: 404, httpVersion: nil, headerFields: nil)!
        mockClient.responses[url] = .success((Data(), response))

        let service = StockService(httpClient: mockClient)
        let quote = await service.fetchQuote(symbol: "AAPL")

        XCTAssertNil(quote)
    }

    func testFetchQuote_invalidJSON_returnsNil() async {
        let mockClient = MockHTTPClient()
        let url = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/AAPL?interval=1m&range=1d&includePrePost=true")!
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
        mockClient.responses[url] = .success(("invalid json".data(using: .utf8)!, response))

        let service = StockService(httpClient: mockClient)
        let quote = await service.fetchQuote(symbol: "AAPL")

        XCTAssertNil(quote)
    }

    func testFetchQuote_missingPrice_returnsNil() async {
        let mockClient = MockHTTPClient()
        let json = """
        {
            "chart": {
                "result": [{
                    "meta": {
                        "symbol": "AAPL",
                        "regularMarketPrice": null,
                        "chartPreviousClose": 148.00
                    }
                }]
            }
        }
        """
        let url = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/AAPL?interval=1m&range=1d&includePrePost=true")!
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
        mockClient.responses[url] = .success((json.data(using: .utf8)!, response))

        let service = StockService(httpClient: mockClient)
        let quote = await service.fetchQuote(symbol: "AAPL")

        XCTAssertNil(quote)
    }

    func testFetchQuote_withExtendedHoursData_returnsExtendedHoursInfo() async {
        let mockClient = MockHTTPClient()
        let json = """
        {
            "chart": {
                "result": [{
                    "meta": {
                        "symbol": "AAPL",
                        "regularMarketPrice": 150.0,
                        "chartPreviousClose": 148.5,
                        "marketState": "POST",
                        "postMarketPrice": 151.5,
                        "postMarketChange": 1.5,
                        "postMarketChangePercent": 1.0
                    }
                }]
            }
        }
        """
        let url = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/AAPL?interval=1m&range=1d&includePrePost=true")!
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
        mockClient.responses[url] = .success((json.data(using: .utf8)!, response))

        let service = StockService(httpClient: mockClient)
        let quote = await service.fetchQuote(symbol: "AAPL")

        XCTAssertNotNil(quote)
        XCTAssertEqual(quote?.session, .afterHours)
        XCTAssertEqual(quote?.postMarketChangePercent, 1.0)
        XCTAssertTrue(quote?.hasExtendedHoursData ?? false)
    }

    // MARK: - fetchQuotes tests

    func testFetchQuotes_multipleSymbols_returnsAll() async {
        let mockClient = MockHTTPClient()

        for (symbol, price) in [("AAPL", 150.0), ("SPY", 450.0), ("QQQ", 380.0)] {
            let json = """
            {
                "chart": {
                    "result": [{
                        "meta": {
                            "symbol": "\(symbol)",
                            "regularMarketPrice": \(price),
                            "chartPreviousClose": \(price * 0.99),
                            "marketState": "REGULAR"
                        }
                    }]
                }
            }
            """
            let url = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/\(symbol)?interval=1m&range=1d&includePrePost=true")!
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            mockClient.responses[url] = .success((json.data(using: .utf8)!, response))
        }

        let service = StockService(httpClient: mockClient)
        let quotes = await service.fetchQuotes(symbols: ["AAPL", "SPY", "QQQ"])

        XCTAssertEqual(quotes.count, 3)
        XCTAssertNotNil(quotes["AAPL"])
        XCTAssertNotNil(quotes["SPY"])
        XCTAssertNotNil(quotes["QQQ"])
        XCTAssertEqual(quotes["AAPL"]?.price, 150.0)
        XCTAssertEqual(quotes["SPY"]?.price, 450.0)
        XCTAssertEqual(quotes["QQQ"]?.price, 380.0)
    }

    func testFetchQuotes_partialFailure_returnsSuccessful() async {
        let mockClient = MockHTTPClient()

        // AAPL succeeds
        let json = """
        {
            "chart": {
                "result": [{
                    "meta": {
                        "symbol": "AAPL",
                        "regularMarketPrice": 150.0,
                        "chartPreviousClose": 148.0,
                        "marketState": "REGULAR"
                    }
                }]
            }
        }
        """
        let aaplURL = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/AAPL?interval=1m&range=1d&includePrePost=true")!
        let response = HTTPURLResponse(url: aaplURL, statusCode: 200, httpVersion: nil, headerFields: nil)!
        mockClient.responses[aaplURL] = .success((json.data(using: .utf8)!, response))

        // INVALID fails
        let invalidURL = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/INVALID?interval=1m&range=1d&includePrePost=true")!
        let errorResponse = HTTPURLResponse(url: invalidURL, statusCode: 404, httpVersion: nil, headerFields: nil)!
        mockClient.responses[invalidURL] = .success((Data(), errorResponse))

        let service = StockService(httpClient: mockClient)
        let quotes = await service.fetchQuotes(symbols: ["AAPL", "INVALID"])

        XCTAssertEqual(quotes.count, 1)
        XCTAssertNotNil(quotes["AAPL"])
        XCTAssertNil(quotes["INVALID"])
    }

    func testFetchQuotes_emptySymbols_returnsEmpty() async {
        let mockClient = MockHTTPClient()
        let service = StockService(httpClient: mockClient)
        let quotes = await service.fetchQuotes(symbols: [])

        XCTAssertTrue(quotes.isEmpty)
    }

    // MARK: - fetchMarketState tests

    func testFetchMarketState_returnsState() async {
        let mockClient = MockHTTPClient()
        let json = """
        {
            "chart": {
                "result": [{
                    "meta": {
                        "symbol": "SPY",
                        "regularMarketPrice": 450.0,
                        "chartPreviousClose": 448.0,
                        "marketState": "PRE"
                    }
                }]
            }
        }
        """
        let url = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/SPY?interval=1m&range=1d&includePrePost=true")!
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
        mockClient.responses[url] = .success((json.data(using: .utf8)!, response))

        let service = StockService(httpClient: mockClient)
        let state = await service.fetchMarketState(symbol: "SPY")

        XCTAssertEqual(state, "PRE")
    }

    func testFetchMarketState_error_returnsNil() async {
        let mockClient = MockHTTPClient()
        let url = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/SPY?interval=1m&range=1d&includePrePost=true")!
        mockClient.responses[url] = .failure(URLError(.timedOut))

        let service = StockService(httpClient: mockClient)
        let state = await service.fetchMarketState(symbol: "SPY")

        XCTAssertNil(state)
    }
}

// MARK: - URLResponse.isSuccessfulHTTP Tests

final class URLResponseIsSuccessfulHTTPTests: XCTestCase {

    private let testURL = URL(string: "https://example.com")!

    func testIsSuccessfulHTTP_200_returnsTrue() {
        let response = HTTPURLResponse(url: testURL, statusCode: 200, httpVersion: nil, headerFields: nil)!
        XCTAssertTrue(response.isSuccessfulHTTP)
    }

    func testIsSuccessfulHTTP_404_returnsFalse() {
        let response = HTTPURLResponse(url: testURL, statusCode: 404, httpVersion: nil, headerFields: nil)!
        XCTAssertFalse(response.isSuccessfulHTTP)
    }

    func testIsSuccessfulHTTP_500_returnsFalse() {
        let response = HTTPURLResponse(url: testURL, statusCode: 500, httpVersion: nil, headerFields: nil)!
        XCTAssertFalse(response.isSuccessfulHTTP)
    }

    func testIsSuccessfulHTTP_201_returnsFalse() {
        let response = HTTPURLResponse(url: testURL, statusCode: 201, httpVersion: nil, headerFields: nil)!
        XCTAssertFalse(response.isSuccessfulHTTP)
    }

    func testIsSuccessfulHTTP_nonHTTPResponse_returnsFalse() {
        let response = URLResponse(url: testURL, mimeType: nil, expectedContentLength: 0, textEncodingName: nil)
        XCTAssertFalse(response.isSuccessfulHTTP)
    }
}
