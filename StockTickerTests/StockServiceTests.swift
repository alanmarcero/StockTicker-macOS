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

    // MARK: - fetchHighestClose tests

    func testFetchHighestClose_extractsMaxFromCloses() async {
        let mockClient = MockHTTPClient()
        let json = """
        {
            "chart": {
                "result": [{
                    "meta": {
                        "symbol": "AAPL",
                        "regularMarketPrice": 150.50,
                        "chartPreviousClose": 148.00
                    },
                    "indicators": {
                        "quote": [{
                            "close": [140.0, 155.0, 148.0, 160.0, 152.0, null, 145.0]
                        }]
                    }
                }]
            }
        }
        """
        let url = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/AAPL?period1=100&period2=200&interval=1d")!
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
        mockClient.responses[url] = .success((json.data(using: .utf8)!, response))

        let service = StockService(httpClient: mockClient)
        let highest = await service.fetchHighestClose(symbol: "AAPL", period1: 100, period2: 200)

        XCTAssertEqual(highest, 160.0)
    }

    func testFetchHighestClose_error_returnsNil() async {
        let mockClient = MockHTTPClient()
        let url = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/AAPL?period1=100&period2=200&interval=1d")!
        mockClient.responses[url] = .failure(URLError(.timedOut))

        let service = StockService(httpClient: mockClient)
        let highest = await service.fetchHighestClose(symbol: "AAPL", period1: 100, period2: 200)

        XCTAssertNil(highest)
    }

    func testFetchHighestClose_emptyCloses_returnsNil() async {
        let mockClient = MockHTTPClient()
        let json = """
        {
            "chart": {
                "result": [{
                    "meta": {
                        "symbol": "AAPL",
                        "regularMarketPrice": 150.50,
                        "chartPreviousClose": 148.00
                    },
                    "indicators": {
                        "quote": [{
                            "close": [null, null]
                        }]
                    }
                }]
            }
        }
        """
        let url = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/AAPL?period1=100&period2=200&interval=1d")!
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
        mockClient.responses[url] = .success((json.data(using: .utf8)!, response))

        let service = StockService(httpClient: mockClient)
        let highest = await service.fetchHighestClose(symbol: "AAPL", period1: 100, period2: 200)

        XCTAssertNil(highest)
    }
}

// MARK: - YahooQuoteResponse Decoding Tests

final class YahooQuoteResponseTests: XCTestCase {

    func testDecoding_validResponse_parsesMarketCap() throws {
        let json = """
        {
            "quoteResponse": {
                "result": [
                    {"symbol": "AAPL", "marketCap": 3759435415552},
                    {"symbol": "MSFT", "marketCap": 2982761988096},
                    {"symbol": "BTC-USD", "marketCap": 1366578429952}
                ]
            }
        }
        """
        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(YahooQuoteResponse.self, from: data)

        XCTAssertEqual(decoded.quoteResponse.result.count, 3)
        XCTAssertEqual(decoded.quoteResponse.result[0].symbol, "AAPL")
        XCTAssertEqual(decoded.quoteResponse.result[0].marketCap, 3759435415552)
        XCTAssertEqual(decoded.quoteResponse.result[1].symbol, "MSFT")
        XCTAssertEqual(decoded.quoteResponse.result[2].symbol, "BTC-USD")
    }

    func testDecoding_missingMarketCap_parsesAsNil() throws {
        let json = """
        {
            "quoteResponse": {
                "result": [
                    {"symbol": "UNKNOWN"}
                ]
            }
        }
        """
        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(YahooQuoteResponse.self, from: data)

        XCTAssertEqual(decoded.quoteResponse.result.count, 1)
        XCTAssertEqual(decoded.quoteResponse.result[0].symbol, "UNKNOWN")
        XCTAssertNil(decoded.quoteResponse.result[0].marketCap)
    }

    func testDecoding_parsesQuoteType() throws {
        let json = """
        {
            "quoteResponse": {
                "result": [
                    {"symbol": "AAPL", "marketCap": 3759435415552, "quoteType": "EQUITY"},
                    {"symbol": "SPY", "marketCap": 625697882112, "quoteType": "ETF"},
                    {"symbol": "BTC-USD", "marketCap": 1366578429952, "quoteType": "CRYPTOCURRENCY"}
                ]
            }
        }
        """
        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(YahooQuoteResponse.self, from: data)

        XCTAssertEqual(decoded.quoteResponse.result[0].quoteType, "EQUITY")
        XCTAssertEqual(decoded.quoteResponse.result[1].quoteType, "ETF")
        XCTAssertEqual(decoded.quoteResponse.result[2].quoteType, "CRYPTOCURRENCY")
    }

    func testDecoding_missingQuoteType_parsesAsNil() throws {
        let json = """
        {
            "quoteResponse": {
                "result": [
                    {"symbol": "AAPL", "marketCap": 100}
                ]
            }
        }
        """
        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(YahooQuoteResponse.self, from: data)

        XCTAssertNil(decoded.quoteResponse.result[0].quoteType)
    }

    func testDecoding_emptyResult_parsesSuccessfully() throws {
        let json = """
        {
            "quoteResponse": {
                "result": []
            }
        }
        """
        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(YahooQuoteResponse.self, from: data)

        XCTAssertTrue(decoded.quoteResponse.result.isEmpty)
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
