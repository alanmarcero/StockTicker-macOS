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
    // MARK: - fetchForwardPERatios tests

    func testFetchForwardPERatios_validResponse_parsesQuarterValues() async {
        let mockClient = MockHTTPClient()
        let json = """
        {
            "timeseries": {
                "result": [{
                    "meta": {
                        "symbol": ["AAPL"],
                        "type": ["quarterlyForwardPeRatio"]
                    },
                    "quarterlyForwardPeRatio": [
                        {"asOfDate": "2025-06-30", "reportedValue": {"raw": 28.5, "fmt": "28.50"}},
                        {"asOfDate": "2025-09-30", "reportedValue": {"raw": 30.2, "fmt": "30.20"}},
                        {"asOfDate": "2025-12-31", "reportedValue": {"raw": 27.8, "fmt": "27.80"}}
                    ]
                }]
            }
        }
        """
        let url = URL(string: "https://query2.finance.yahoo.com/ws/fundamentals-timeseries/v1/finance/timeseries/AAPL?type=quarterlyForwardPeRatio&period1=100&period2=200")!
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
        mockClient.responses[url] = .success((json.data(using: .utf8)!, response))

        let service = StockService(httpClient: mockClient)
        let result = await service.fetchForwardPERatios(symbol: "AAPL", period1: 100, period2: 200)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?["Q2-2025"], 28.5)
        XCTAssertEqual(result?["Q3-2025"], 30.2)
        XCTAssertEqual(result?["Q4-2025"], 27.8)
    }

    func testFetchForwardPERatios_emptyResult_returnsEmptyDict() async {
        let mockClient = MockHTTPClient()
        let json = """
        {
            "timeseries": {
                "result": [{
                    "meta": {
                        "symbol": ["BTC-USD"],
                        "type": ["quarterlyForwardPeRatio"]
                    }
                }]
            }
        }
        """
        let url = URL(string: "https://query2.finance.yahoo.com/ws/fundamentals-timeseries/v1/finance/timeseries/BTC-USD?type=quarterlyForwardPeRatio&period1=100&period2=200")!
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
        mockClient.responses[url] = .success((json.data(using: .utf8)!, response))

        let service = StockService(httpClient: mockClient)
        let result = await service.fetchForwardPERatios(symbol: "BTC-USD", period1: 100, period2: 200)

        XCTAssertNotNil(result)
        XCTAssertTrue(result?.isEmpty ?? false)
    }

    func testFetchForwardPERatios_networkError_returnsNil() async {
        let mockClient = MockHTTPClient()
        let url = URL(string: "https://query2.finance.yahoo.com/ws/fundamentals-timeseries/v1/finance/timeseries/AAPL?type=quarterlyForwardPeRatio&period1=100&period2=200")!
        mockClient.responses[url] = .failure(URLError(.timedOut))

        let service = StockService(httpClient: mockClient)
        let result = await service.fetchForwardPERatios(symbol: "AAPL", period1: 100, period2: 200)

        XCTAssertNil(result)
    }

    func testFetchForwardPERatios_parsesAsOfDateToQuarter() async {
        let mockClient = MockHTTPClient()
        let json = """
        {
            "timeseries": {
                "result": [{
                    "meta": {
                        "symbol": ["AAPL"],
                        "type": ["quarterlyForwardPeRatio"]
                    },
                    "quarterlyForwardPeRatio": [
                        {"asOfDate": "2024-03-31", "reportedValue": {"raw": 25.0, "fmt": "25.00"}},
                        {"asOfDate": "2024-12-31", "reportedValue": {"raw": 29.0, "fmt": "29.00"}}
                    ]
                }]
            }
        }
        """
        let url = URL(string: "https://query2.finance.yahoo.com/ws/fundamentals-timeseries/v1/finance/timeseries/AAPL?type=quarterlyForwardPeRatio&period1=100&period2=200")!
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
        mockClient.responses[url] = .success((json.data(using: .utf8)!, response))

        let service = StockService(httpClient: mockClient)
        let result = await service.fetchForwardPERatios(symbol: "AAPL", period1: 100, period2: 200)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?["Q1-2024"], 25.0)  // March → Q1
        XCTAssertEqual(result?["Q4-2024"], 29.0)  // December → Q4
    }

    // MARK: - fetchSwingLevels tests

    func testFetchSwingLevels_validResponse_returnsCacheEntry() async {
        let mockClient = MockHTTPClient()
        // Peak at 150 (index 2) → drops to 80 (46.7% decline) — significant high at 150
        // Significant lows at 100 (index 0), 120 (index 1), 80 (index 5) — highest is 120
        let json = """
        {
            "chart": {
                "result": [{
                    "meta": {
                        "symbol": "AAPL",
                        "regularMarketPrice": 150.50,
                        "chartPreviousClose": 148.00
                    },
                    "timestamp": [1704067200, 1704153600, 1704240000, 1704326400, 1704412800, 1704499200, 1704585600, 1704672000],
                    "indicators": {
                        "quote": [{
                            "close": [100.0, 120.0, 150.0, 130.0, 125.0, 80.0, 90.0, 95.0]
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
        let result = await service.fetchSwingLevels(symbol: "AAPL", period1: 100, period2: 200)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.breakoutPrice, 150.0)
        XCTAssertNotNil(result?.breakoutDate)
        XCTAssertEqual(result?.breakdownPrice, 120.0)
        XCTAssertNotNil(result?.breakdownDate)
    }

    func testFetchSwingLevels_emptyCloses_returnsNil() async {
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
                    "timestamp": [1704067200, 1704153600],
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
        let result = await service.fetchSwingLevels(symbol: "AAPL", period1: 100, period2: 200)

        XCTAssertNil(result)
    }

    func testFetchSwingLevels_networkError_returnsNil() async {
        let mockClient = MockHTTPClient()
        let url = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/AAPL?period1=100&period2=200&interval=1d")!
        mockClient.responses[url] = .failure(URLError(.timedOut))

        let service = StockService(httpClient: mockClient)
        let result = await service.fetchSwingLevels(symbol: "AAPL", period1: 100, period2: 200)

        XCTAssertNil(result)
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

    // MARK: - fetchRSI tests

    func testFetchRSI_validResponse_returnsValue() async {
        let mockClient = MockHTTPClient()
        // 20 closes: steady rise with some dips
        var closes: [Double] = []
        for i in 0..<20 {
            closes.append(100.0 + Double(i) * 2.0)
        }
        let closesJSON = closes.map { String($0) }.joined(separator: ", ")
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
                            "close": [\(closesJSON)]
                        }]
                    }
                }]
            }
        }
        """
        let url = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/AAPL?range=1y&interval=1d")!
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
        mockClient.responses[url] = .success((json.data(using: .utf8)!, response))

        let service = StockService(httpClient: mockClient)
        let rsi = await service.fetchRSI(symbol: "AAPL")

        XCTAssertNotNil(rsi)
        XCTAssertEqual(rsi!, 100.0)
    }

    func testFetchRSI_error_returnsNil() async {
        let mockClient = MockHTTPClient()
        let url = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/AAPL?range=1y&interval=1d")!
        mockClient.responses[url] = .failure(URLError(.timedOut))

        let service = StockService(httpClient: mockClient)
        let rsi = await service.fetchRSI(symbol: "AAPL")

        XCTAssertNil(rsi)
    }

    func testFetchRSI_insufficientCloses_returnsNil() async {
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
                            "close": [100.0, 101.0, 102.0]
                        }]
                    }
                }]
            }
        }
        """
        let url = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/AAPL?range=1y&interval=1d")!
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
        mockClient.responses[url] = .success((json.data(using: .utf8)!, response))

        let service = StockService(httpClient: mockClient)
        let rsi = await service.fetchRSI(symbol: "AAPL")

        XCTAssertNil(rsi)
    }

    // MARK: - EMA Fetch Tests

    func testFetchDailyEMA_validResponse_returnsValue() async {
        let mockClient = MockHTTPClient()
        let closes = [100.0, 102.0, 104.0, 106.0, 108.0, 110.0]
        let closesJSON = closes.map { String($0) }.joined(separator: ", ")
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
                            "close": [\(closesJSON)]
                        }]
                    }
                }]
            }
        }
        """
        let url = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/AAPL?range=1mo&interval=1d")!
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
        mockClient.responses[url] = .success((json.data(using: .utf8)!, response))

        let service = StockService(httpClient: mockClient)
        let ema = await service.fetchDailyEMA(symbol: "AAPL")

        XCTAssertNotNil(ema)
    }

    func testFetchWeeklyEMA_error_returnsNil() async {
        let mockClient = MockHTTPClient()
        let url = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/AAPL?range=6mo&interval=1wk")!
        mockClient.responses[url] = .failure(URLError(.timedOut))

        let service = StockService(httpClient: mockClient)
        let ema = await service.fetchWeeklyEMA(symbol: "AAPL")

        XCTAssertNil(ema)
    }

    // MARK: - fetchDailyAnalysis tests

    func testFetchDailyAnalysis_validResponse_returnsAllDataPoints() async {
        let mockClient = MockHTTPClient()
        // Generate 20 closes with timestamps for a valid response
        var closes: [Double] = []
        var timestamps: [Int] = []
        let baseTimestamp = 1700000000
        for i in 0..<20 {
            closes.append(100.0 + Double(i) * 2.0)
            timestamps.append(baseTimestamp + i * 86400)
        }
        let closesJSON = closes.map { String($0) }.joined(separator: ", ")
        let timestampsJSON = timestamps.map { String($0) }.joined(separator: ", ")
        let json = """
        {
            "chart": {
                "result": [{
                    "meta": {
                        "symbol": "AAPL",
                        "regularMarketPrice": 150.50,
                        "chartPreviousClose": 148.00
                    },
                    "timestamp": [\(timestampsJSON)],
                    "indicators": {
                        "quote": [{
                            "close": [\(closesJSON)]
                        }]
                    }
                }]
            }
        }
        """
        let url = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/AAPL?period1=1000&period2=2000&interval=1d")!
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
        mockClient.responses[url] = .success((json.data(using: .utf8)!, response))

        let service = StockService(httpClient: mockClient)
        let result = await service.fetchDailyAnalysis(symbol: "AAPL", period1: 1000, period2: 2000)

        XCTAssertNotNil(result)
        // Highest close should be the max of all closes (138.0)
        XCTAssertEqual(result?.highestClose, 138.0)
        // RSI should be non-nil (steady rise = 100.0)
        XCTAssertNotNil(result?.rsi)
        XCTAssertEqual(result?.rsi, 100.0)
        // Daily EMA should be non-nil
        XCTAssertNotNil(result?.dailyEMA)
        // Swing entry should be present (but may have nil levels for steady rise)
        XCTAssertNotNil(result?.swingLevelEntry)
    }

    func testFetchDailyAnalysis_networkError_returnsNil() async {
        let mockClient = MockHTTPClient()
        let url = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/AAPL?period1=1000&period2=2000&interval=1d")!
        mockClient.responses[url] = .failure(URLError(.timedOut))

        let service = StockService(httpClient: mockClient)
        let result = await service.fetchDailyAnalysis(symbol: "AAPL", period1: 1000, period2: 2000)

        XCTAssertNil(result)
    }

    func testFetchDailyAnalysis_emptyCloses_returnsNilHighest() async {
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
                    "timestamp": [],
                    "indicators": {
                        "quote": [{
                            "close": [null, null]
                        }]
                    }
                }]
            }
        }
        """
        let url = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/AAPL?period1=1000&period2=2000&interval=1d")!
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
        mockClient.responses[url] = .success((json.data(using: .utf8)!, response))

        let service = StockService(httpClient: mockClient)
        let result = await service.fetchDailyAnalysis(symbol: "AAPL", period1: 1000, period2: 2000)

        XCTAssertNotNil(result)
        XCTAssertNil(result?.highestClose)
        XCTAssertNil(result?.rsi)
        XCTAssertNil(result?.dailyEMA)
    }

    // MARK: - batchFetchEMAValues with dailyEMAs tests

    func testBatchFetchEMAValues_withDailyEMAs_skipsDailyFetch() async {
        let mockClient = MockHTTPClient()
        // Only set up weekly and monthly responses (no daily)
        let weeklyClosesJSON = (0..<10).map { String(Double(100 + $0 * 5)) }.joined(separator: ", ")
        let monthlyClosesJSON = (0..<10).map { String(Double(100 + $0 * 3)) }.joined(separator: ", ")

        let weeklyJSON = """
        {"chart":{"result":[{"meta":{"symbol":"AAPL","regularMarketPrice":150.50,"chartPreviousClose":148.00},"indicators":{"quote":[{"close":[\(weeklyClosesJSON)]}]}}]}}
        """
        let monthlyJSON = """
        {"chart":{"result":[{"meta":{"symbol":"AAPL","regularMarketPrice":150.50,"chartPreviousClose":148.00},"indicators":{"quote":[{"close":[\(monthlyClosesJSON)]}]}}]}}
        """

        let weeklyURL = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/AAPL?range=6mo&interval=1wk")!
        let monthlyURL = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/AAPL?range=2y&interval=1mo")!
        let weeklyResp = HTTPURLResponse(url: weeklyURL, statusCode: 200, httpVersion: nil, headerFields: nil)!
        let monthlyResp = HTTPURLResponse(url: monthlyURL, statusCode: 200, httpVersion: nil, headerFields: nil)!
        mockClient.responses[weeklyURL] = .success((weeklyJSON.data(using: .utf8)!, weeklyResp))
        mockClient.responses[monthlyURL] = .success((monthlyJSON.data(using: .utf8)!, monthlyResp))

        let service = StockService(httpClient: mockClient)
        let result = await service.batchFetchEMAValues(symbols: ["AAPL"], dailyEMAs: ["AAPL": 155.0])

        XCTAssertNotNil(result["AAPL"])
        // The pre-computed daily EMA should be used
        XCTAssertEqual(result["AAPL"]?.day, 155.0)
        // Weekly and monthly should be computed from chart data
        XCTAssertNotNil(result["AAPL"]?.week)
        XCTAssertNotNil(result["AAPL"]?.month)
    }

    func testFetchEMAEntry_allAPIsFail_returnsNil() async {
        let mockClient = MockHTTPClient()
        // No responses set — all API calls will fail
        let service = StockService(httpClient: mockClient)
        let result = await service.fetchEMAEntry(symbol: "AAPL")

        XCTAssertNil(result)
    }

    func testFetchEMAEntry_partialSuccess_returnsEntry() async {
        let mockClient = MockHTTPClient()
        // Only weekly succeeds
        let weeklyJSON = """
        {"chart":{"result":[{"meta":{"symbol":"AAPL","regularMarketPrice":150.50,"chartPreviousClose":148.00},"indicators":{"quote":[{"close":[100, 105, 110, 115, 120, 125, 130, 135, 140, 145]}]}}]}}
        """
        let weeklyURL = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/AAPL?range=6mo&interval=1wk")!
        let weeklyResp = HTTPURLResponse(url: weeklyURL, statusCode: 200, httpVersion: nil, headerFields: nil)!
        mockClient.responses[weeklyURL] = .success((weeklyJSON.data(using: .utf8)!, weeklyResp))

        let service = StockService(httpClient: mockClient)
        let result = await service.fetchEMAEntry(symbol: "AAPL")

        XCTAssertNotNil(result)
        XCTAssertNil(result?.day)
        XCTAssertNotNil(result?.week)
        XCTAssertNil(result?.month)
    }

    func testBatchFetchForwardPE_apiFailure_excludesFromResult() async {
        let mockClient = MockHTTPClient()
        // AAPL succeeds, MSFT fails (no response set)
        let json = """
        {"timeseries":{"result":[{"meta":{"symbol":["AAPL"],"type":["quarterlyForwardPeRatio"]},"quarterlyForwardPeRatio":[{"asOfDate":"2025-12-31","reportedValue":{"raw":28.5,"fmt":"28.50"}}]}]}}
        """
        let aaplURL = URL(string: "https://query2.finance.yahoo.com/ws/fundamentals-timeseries/v1/finance/timeseries/AAPL?type=quarterlyForwardPeRatio&period1=100&period2=200")!
        let resp = HTTPURLResponse(url: aaplURL, statusCode: 200, httpVersion: nil, headerFields: nil)!
        mockClient.responses[aaplURL] = .success((json.data(using: .utf8)!, resp))

        let service = StockService(httpClient: mockClient)
        let result = await service.batchFetchForwardPERatios(symbols: ["AAPL", "MSFT"], period1: 100, period2: 200)

        XCTAssertNotNil(result["AAPL"])
        XCTAssertEqual(result["AAPL"]?["Q4-2025"], 28.5)
        XCTAssertNil(result["MSFT"])  // API failure — not stored
    }

    func testBatchFetchForwardPE_noData_includesEmptyDict() async {
        let mockClient = MockHTTPClient()
        // BTC-USD succeeds but has no PE data
        let json = """
        {"timeseries":{"result":[{"meta":{"symbol":["BTC-USD"],"type":["quarterlyForwardPeRatio"]}}]}}
        """
        let btcURL = URL(string: "https://query2.finance.yahoo.com/ws/fundamentals-timeseries/v1/finance/timeseries/BTC-USD?type=quarterlyForwardPeRatio&period1=100&period2=200")!
        let resp = HTTPURLResponse(url: btcURL, statusCode: 200, httpVersion: nil, headerFields: nil)!
        mockClient.responses[btcURL] = .success((json.data(using: .utf8)!, resp))

        let service = StockService(httpClient: mockClient)
        let result = await service.batchFetchForwardPERatios(symbols: ["BTC-USD"], period1: 100, period2: 200)

        XCTAssertNotNil(result["BTC-USD"])
        XCTAssertTrue(result["BTC-USD"]?.isEmpty ?? false)  // Stored as empty — won't retry
    }

    func testFetchMonthlyEMA_insufficientCloses_returnsNil() async {
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
                            "close": [100.0, 101.0]
                        }]
                    }
                }]
            }
        }
        """
        let url = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/AAPL?range=2y&interval=1mo")!
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
        mockClient.responses[url] = .success((json.data(using: .utf8)!, response))

        let service = StockService(httpClient: mockClient)
        let ema = await service.fetchMonthlyEMA(symbol: "AAPL")

        XCTAssertNil(ema)
    }

    // MARK: - Weekly Crossover Timing Tests

    /// Weekly closes that produce a crossover on the last bar: 6 bars below EMA then 1 above.
    /// With period=5: SMA(first 5)=50, bar 6 below at 45, bar 7 crosses above at 60.
    private func crossoverWeeklyCloses() -> [Double] {
        [40, 45, 50, 55, 60, 45, 80]
    }

    private func makeWeeklyJSON(closes: [Double]) -> String {
        let closesStr = closes.map { String($0) }.joined(separator: ",")
        return """
        {"chart":{"result":[{"meta":{"symbol":"AAPL","regularMarketPrice":150.50,"chartPreviousClose":148.00},"indicators":{"quote":[{"close":[\(closesStr)]}]}}]}}
        """
    }

    private func setupCrossoverMock(closes: [Double]) -> (MockHTTPClient, StockService) {
        let mockClient = MockHTTPClient()
        let weeklyJSON = makeWeeklyJSON(closes: closes)
        let weeklyURL = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/AAPL?range=6mo&interval=1wk")!
        let weeklyResp = HTTPURLResponse(url: weeklyURL, statusCode: 200, httpVersion: nil, headerFields: nil)!
        mockClient.responses[weeklyURL] = .success((weeklyJSON.data(using: .utf8)!, weeklyResp))
        return (mockClient, StockService(httpClient: mockClient))
    }

    private func makeETDate(year: Int, month: Int, day: Int, hour: Int, minute: Int = 0) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        return calendar.date(from: components)!
    }

    func testCrossoverTiming_thursday_excludesCurrentWeek() async {
        let closes = crossoverWeeklyCloses()
        let (_, service) = setupCrossoverMock(closes: closes)
        // 2026-02-19 is a Thursday
        let thursday = makeETDate(year: 2026, month: 2, day: 19, hour: 12)

        let result = await service.fetchEMAEntry(symbol: "AAPL", precomputedDailyEMA: 150.0, now: thursday)

        XCTAssertNotNil(result)
        // Crossover is on the last bar; dropping it means no crossover detected
        XCTAssertNil(result?.weekCrossoverWeeksBelow, "Mid-week should drop current bar and see no crossover")
    }

    func testCrossoverTiming_friday159PM_excludesCurrentWeek() async {
        let closes = crossoverWeeklyCloses()
        let (_, service) = setupCrossoverMock(closes: closes)
        // 2026-02-20 is a Friday
        let friday159 = makeETDate(year: 2026, month: 2, day: 20, hour: 13, minute: 59)

        let result = await service.fetchEMAEntry(symbol: "AAPL", precomputedDailyEMA: 150.0, now: friday159)

        XCTAssertNotNil(result)
        XCTAssertNil(result?.weekCrossoverWeeksBelow, "Before Friday 2PM should drop current bar")
    }

    func testCrossoverTiming_friday2PM_includesCurrentWeek() async {
        let closes = crossoverWeeklyCloses()
        let (_, service) = setupCrossoverMock(closes: closes)
        // 2026-02-20 is a Friday
        let friday2pm = makeETDate(year: 2026, month: 2, day: 20, hour: 14)

        let result = await service.fetchEMAEntry(symbol: "AAPL", precomputedDailyEMA: 150.0, now: friday2pm)

        XCTAssertNotNil(result)
        XCTAssertNotNil(result?.weekCrossoverWeeksBelow, "Friday 2PM+ should include current bar and detect crossover")
    }

    func testCrossoverTiming_saturday_includesCurrentWeek() async {
        let closes = crossoverWeeklyCloses()
        let (_, service) = setupCrossoverMock(closes: closes)
        // 2026-02-21 is a Saturday
        let saturday = makeETDate(year: 2026, month: 2, day: 21, hour: 10)

        let result = await service.fetchEMAEntry(symbol: "AAPL", precomputedDailyEMA: 150.0, now: saturday)

        XCTAssertNotNil(result)
        XCTAssertNotNil(result?.weekCrossoverWeeksBelow, "Saturday should include current bar and detect crossover")
    }

    // MARK: - Finnhub integration tests

    func testFinnhubDailyAnalysis_validResponse_returnsAllDataPoints() async {
        let mockClient = MockHTTPClient()
        let closes = (0..<30).map { 100.0 + Double($0) }
        let timestamps = (0..<30).map { 1700000000 + $0 * 86400 }

        let closesJSON = closes.map { String($0) }.joined(separator: ",")
        let timestampsJSON = timestamps.map { String($0) }.joined(separator: ",")
        let json = """
        {"c":[\(closesJSON)],"t":[\(timestampsJSON)],"s":"ok"}
        """

        mockClient.patternResponses.append((
            pattern: "finnhub.io/api/v1/stock/candle",
            result: .success((json.data(using: .utf8)!, HTTPURLResponse(url: URL(string: "https://finnhub.io")!, statusCode: 200, httpVersion: nil, headerFields: nil)!))
        ))

        let service = StockService(httpClient: mockClient, finnhubApiKey: "test_key")
        let result = await service.fetchDailyAnalysis(symbol: "AAPL", period1: 1000, period2: 2000)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.highestClose, 129.0)
        XCTAssertNotNil(result?.rsi)
        XCTAssertNotNil(result?.dailyEMA)
    }

    func testFinnhubDailyAnalysis_failure_fallsBackToYahoo() async {
        let mockClient = MockHTTPClient()

        // Finnhub returns error
        mockClient.patternResponses.append((
            pattern: "finnhub.io",
            result: .success((Data(), HTTPURLResponse(url: URL(string: "https://finnhub.io")!, statusCode: 403, httpVersion: nil, headerFields: nil)!))
        ))

        // Yahoo returns valid response
        let closes = (0..<20).map { 100.0 + Double($0) }
        let closesJSON = closes.map { String($0) }.joined(separator: ",")
        let yahooJSON = """
        {"chart":{"result":[{"meta":{"symbol":"AAPL","regularMarketPrice":150.50,"chartPreviousClose":148.00},"timestamp":[],"indicators":{"quote":[{"close":[\(closesJSON)]}]}}]}}
        """

        mockClient.patternResponses.append((
            pattern: "query1.finance.yahoo.com/v8/finance/chart/AAPL",
            result: .success((yahooJSON.data(using: .utf8)!, HTTPURLResponse(url: URL(string: "https://query1.finance.yahoo.com")!, statusCode: 200, httpVersion: nil, headerFields: nil)!))
        ))

        let service = StockService(httpClient: mockClient, finnhubApiKey: "test_key")
        let result = await service.fetchDailyAnalysis(symbol: "AAPL", period1: 1000, period2: 2000)

        XCTAssertNotNil(result, "Should fall back to Yahoo when Finnhub fails")
        XCTAssertEqual(result?.highestClose, 119.0)
    }

    func testFinnhubRouting_indexSymbol_usesYahooDirectly() async {
        let mockClient = MockHTTPClient()

        let yahooJSON = """
        {"chart":{"result":[{"meta":{"symbol":"^GSPC","regularMarketPrice":5000.0,"chartPreviousClose":4990.0},"timestamp":[],"indicators":{"quote":[{"close":[4900.0,4950.0,5000.0]}]}}]}}
        """
        mockClient.patternResponses.append((
            pattern: "query1.finance.yahoo.com/v8/finance/chart/%5EGSPC",
            result: .success((yahooJSON.data(using: .utf8)!, HTTPURLResponse(url: URL(string: "https://query1.finance.yahoo.com")!, statusCode: 200, httpVersion: nil, headerFields: nil)!))
        ))

        let service = StockService(httpClient: mockClient, finnhubApiKey: "test_key")
        let result = await service.fetchHighestClose(symbol: "^GSPC", period1: 1000, period2: 2000)

        XCTAssertEqual(result, 5000.0)
        // Verify no Finnhub URLs were requested
        let finnhubRequests = mockClient.requestedURLs.filter { $0.absoluteString.contains("finnhub") }
        XCTAssertTrue(finnhubRequests.isEmpty, "Index symbols should not use Finnhub")
    }

    func testFinnhubRouting_nilApiKey_usesYahooForEquity() async {
        let mockClient = MockHTTPClient()

        let yahooJSON = """
        {"chart":{"result":[{"meta":{"symbol":"AAPL","regularMarketPrice":150.0,"chartPreviousClose":148.0},"timestamp":[],"indicators":{"quote":[{"close":[145.0,148.0,150.0]}]}}]}}
        """
        mockClient.patternResponses.append((
            pattern: "query1.finance.yahoo.com/v8/finance/chart/AAPL",
            result: .success((yahooJSON.data(using: .utf8)!, HTTPURLResponse(url: URL(string: "https://query1.finance.yahoo.com")!, statusCode: 200, httpVersion: nil, headerFields: nil)!))
        ))

        let service = StockService(httpClient: mockClient) // No finnhubApiKey
        let result = await service.fetchHighestClose(symbol: "AAPL", period1: 1000, period2: 2000)

        XCTAssertEqual(result, 150.0)
        let finnhubRequests = mockClient.requestedURLs.filter { $0.absoluteString.contains("finnhub") }
        XCTAssertTrue(finnhubRequests.isEmpty, "Without API key, should use Yahoo even for equities")
    }

    func testUpdateFinnhubApiKey_changesRouting() async {
        let service = StockService(httpClient: MockHTTPClient())

        // Initially nil - should route to Yahoo
        let source1 = await service.finnhubApiKey
        XCTAssertNil(source1)

        // Update key
        await service.updateFinnhubApiKey("new_key")
        let source2 = await service.finnhubApiKey
        XCTAssertEqual(source2, "new_key")

        // Clear key
        await service.updateFinnhubApiKey(nil)
        let source3 = await service.finnhubApiKey
        XCTAssertNil(source3)
    }

    // MARK: - Finnhub Quote Tests

    func testFetchFinnhubQuote_validResponse_returnsQuote() async {
        let mockClient = MockHTTPClient()
        let json = """
        {"c":263.84,"d":-0.51,"dp":-0.1929,"h":264.48,"l":262.29,"o":263.21,"pc":264.35,"t":1771519213}
        """
        let url = URL(string: "https://finnhub.io/api/v1/quote?symbol=AAPL")!
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
        mockClient.responses[url] = .success((json.data(using: .utf8)!, response))

        let service = StockService(httpClient: mockClient, finnhubApiKey: "test_key")
        let quote = await service.fetchFinnhubQuote(symbol: "AAPL")

        XCTAssertNotNil(quote)
        XCTAssertEqual(quote?.symbol, "AAPL")
        XCTAssertEqual(quote?.price, 263.84)
        XCTAssertEqual(quote?.previousClose, 264.35)
        XCTAssertEqual(quote?.session, .regular)
    }

    func testFetchFinnhubQuote_zeroPrices_returnsNil() async {
        let mockClient = MockHTTPClient()
        let json = """
        {"c":0,"d":null,"dp":null,"h":0,"l":0,"o":0,"pc":0,"t":0}
        """
        let url = URL(string: "https://finnhub.io/api/v1/quote?symbol=UNKNOWN")!
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
        mockClient.responses[url] = .success((json.data(using: .utf8)!, response))

        let service = StockService(httpClient: mockClient, finnhubApiKey: "test_key")
        let quote = await service.fetchFinnhubQuote(symbol: "UNKNOWN")

        XCTAssertNil(quote)
    }

    func testFetchFinnhubQuote_noApiKey_returnsNil() async {
        let mockClient = MockHTTPClient()
        let service = StockService(httpClient: mockClient) // No finnhubApiKey
        let quote = await service.fetchFinnhubQuote(symbol: "AAPL")

        XCTAssertNil(quote)
        let finnhubRequests = mockClient.requestedURLs.filter { $0.absoluteString.contains("finnhub") }
        XCTAssertTrue(finnhubRequests.isEmpty)
    }

    func testFetchFinnhubQuote_httpError_returnsNil() async {
        let mockClient = MockHTTPClient()
        let url = URL(string: "https://finnhub.io/api/v1/quote?symbol=AAPL")!
        let response = HTTPURLResponse(url: url, statusCode: 429, httpVersion: nil, headerFields: nil)!
        mockClient.responses[url] = .success((Data(), response))

        let service = StockService(httpClient: mockClient, finnhubApiKey: "test_key")
        let quote = await service.fetchFinnhubQuote(symbol: "AAPL")

        XCTAssertNil(quote)
    }

    func testFetchFinnhubQuotes_batch_returnsValidOnly() async {
        let mockClient = MockHTTPClient()

        // Valid quote for AAPL
        let aaplJson = """
        {"c":150.0,"d":1.0,"dp":0.67,"h":151.0,"l":149.0,"o":149.5,"pc":149.0,"t":1700000000}
        """
        let aaplUrl = URL(string: "https://finnhub.io/api/v1/quote?symbol=AAPL")!
        let aaplResponse = HTTPURLResponse(url: aaplUrl, statusCode: 200, httpVersion: nil, headerFields: nil)!
        mockClient.responses[aaplUrl] = .success((aaplJson.data(using: .utf8)!, aaplResponse))

        // Invalid (zeros) for UNKNOWN
        let unknownJson = """
        {"c":0,"d":null,"dp":null,"h":0,"l":0,"o":0,"pc":0,"t":0}
        """
        let unknownUrl = URL(string: "https://finnhub.io/api/v1/quote?symbol=UNKNOWN")!
        let unknownResponse = HTTPURLResponse(url: unknownUrl, statusCode: 200, httpVersion: nil, headerFields: nil)!
        mockClient.responses[unknownUrl] = .success((unknownJson.data(using: .utf8)!, unknownResponse))

        let service = StockService(httpClient: mockClient, finnhubApiKey: "test_key")
        let quotes = await service.fetchFinnhubQuotes(symbols: ["AAPL", "UNKNOWN"])

        XCTAssertEqual(quotes.count, 1)
        XCTAssertNotNil(quotes["AAPL"])
        XCTAssertNil(quotes["UNKNOWN"])
    }
}
