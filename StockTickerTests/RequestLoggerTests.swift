import XCTest
@testable import StockTicker

final class RequestLoggerTests: XCTestCase {

    func testGetErrorCount_noErrors_returnsZero() async {
        let logger = RequestLogger()
        let url = URL(string: "https://example.com")!

        await logger.log(RequestLogEntry(url: url, statusCode: 200, responseSize: 100, duration: 0.1))

        let count = await logger.getErrorCount()
        XCTAssertEqual(count, 0)
    }

    func testGetErrorCount_withErrors_returnsCount() async {
        let logger = RequestLogger()
        let url = URL(string: "https://example.com")!

        await logger.log(RequestLogEntry(url: url, statusCode: 200, responseSize: 100, duration: 0.1))
        await logger.log(RequestLogEntry(url: url, statusCode: 500, responseSize: 0, duration: 0.2))
        await logger.log(RequestLogEntry(url: url, duration: 0.3, error: "Network error"))
        await logger.log(RequestLogEntry(url: url, statusCode: 404, responseSize: 0, duration: 0.1))

        let count = await logger.getErrorCount()
        XCTAssertEqual(count, 3)
    }

    func testGetLastError_returnsMostRecentError() async {
        let logger = RequestLogger()
        let url = URL(string: "https://example.com")!

        await logger.log(RequestLogEntry(url: url, statusCode: 500, responseSize: 0, duration: 0.1, error: "First error"))
        // Small delay so timestamps differ
        try? await Task.sleep(nanoseconds: 10_000_000)
        await logger.log(RequestLogEntry(url: url, statusCode: 200, responseSize: 100, duration: 0.1))
        try? await Task.sleep(nanoseconds: 10_000_000)
        await logger.log(RequestLogEntry(url: url, statusCode: 503, responseSize: 0, duration: 0.2, error: "Latest error"))

        let lastError = await logger.getLastError()
        XCTAssertNotNil(lastError)
        XCTAssertEqual(lastError?.error, "Latest error")
        XCTAssertEqual(lastError?.statusCode, 503)
    }

    func testGetLastError_noErrors_returnsNil() async {
        let logger = RequestLogger()
        let url = URL(string: "https://example.com")!

        await logger.log(RequestLogEntry(url: url, statusCode: 200, responseSize: 100, duration: 0.1))

        let lastError = await logger.getLastError()
        XCTAssertNil(lastError)
    }

    func testClear_resetsErrorState() async {
        let logger = RequestLogger()
        let url = URL(string: "https://example.com")!

        await logger.log(RequestLogEntry(url: url, statusCode: 500, responseSize: 0, duration: 0.1, error: "Error"))
        let beforeCount = await logger.getErrorCount()
        XCTAssertEqual(beforeCount, 1)

        await logger.clear()
        let afterCount = await logger.getErrorCount()
        let afterError = await logger.getLastError()
        XCTAssertEqual(afterCount, 0)
        XCTAssertNil(afterError)
    }

    func test429Response_notRetried() async throws {
        let url = URL(string: "https://example.com/api")!
        let mock = CountingHTTPClient(url: url, statusCode: 429)
        let logger = RequestLogger()
        let client = LoggingHTTPClient(wrapping: mock, logger: logger)

        let (_, response) = try await client.data(from: url)
        let httpResponse = response as! HTTPURLResponse
        XCTAssertEqual(httpResponse.statusCode, 429)
        XCTAssertEqual(mock.callCount, 1, "429 should not be retried")
    }

    func test500Response_retried() async throws {
        let url = URL(string: "https://example.com/api")!
        let mock = CountingHTTPClient(url: url, statusCode: 500)
        let logger = RequestLogger()
        let client = LoggingHTTPClient(wrapping: mock, logger: logger, retryShouldAttempt: { true })

        let (_, response) = try await client.data(from: url)
        let httpResponse = response as! HTTPURLResponse
        XCTAssertEqual(httpResponse.statusCode, 500)
        XCTAssertEqual(mock.callCount, 2, "500 should be retried once")
    }

    func test500Response_notRetriedWhenShouldRetryFalse() async throws {
        let url = URL(string: "https://example.com/api")!
        let mock = CountingHTTPClient(url: url, statusCode: 500)
        let logger = RequestLogger()
        let client = LoggingHTTPClient(wrapping: mock, logger: logger, retryShouldAttempt: { false })

        let (_, response) = try await client.data(from: url)
        let httpResponse = response as! HTTPURLResponse
        XCTAssertEqual(httpResponse.statusCode, 500)
        XCTAssertEqual(mock.callCount, 1, "500 should not retry when shouldRetry is false")
    }

    func testSuccessesNotStoredAsEntries() async {
        let logger = RequestLogger()
        let url = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/AAPL")!

        await logger.log(RequestLogEntry(url: url, statusCode: 200, responseSize: 100, duration: 0.1))
        await logger.log(RequestLogEntry(url: url, statusCode: 200, responseSize: 200, duration: 0.1))

        let entries = await logger.getEntries()
        XCTAssertTrue(entries.isEmpty, "Successes should not be stored as entries")
    }

    func testSuccessesStillCountInCounters() async {
        let logger = RequestLogger()
        let url = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/AAPL")!

        for _ in 0..<15 {
            await logger.log(RequestLogEntry(url: url, statusCode: 200, responseSize: 100, duration: 0.1))
        }

        let counts = await logger.getEndpointCounts()
        let chartCount = counts.first { $0.label == "Yahoo Chart" }
        XCTAssertEqual(chartCount?.count, 15, "Counters should track all 15 requests")

        let entries = await logger.getEntries()
        XCTAssertTrue(entries.isEmpty, "No error entries from successes")
    }

    func testErrorEntriesCappedAt100() async {
        let logger = RequestLogger()
        let url = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/AAPL")!

        for i in 0..<120 {
            await logger.log(RequestLogEntry(url: url, statusCode: 500, responseSize: i, duration: 0.1, error: "fail"))
        }

        let entries = await logger.getEntries()
        XCTAssertEqual(entries.count, 100, "Should cap at 100 error entries")
        // Most recent entries kept (largest responseSize values)
        let sizes = entries.compactMap { $0.responseSize }
        XCTAssertTrue(sizes.allSatisfy { $0 >= 20 }, "Oldest entries should be pruned")
    }

    func testErrorCountFromCounters() async {
        let logger = RequestLogger()
        let url = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/AAPL")!

        for _ in 0..<12 {
            await logger.log(RequestLogEntry(url: url, statusCode: 500, responseSize: 0, duration: 0.1, error: "fail"))
        }

        let errorCount = await logger.getErrorCount()
        XCTAssertEqual(errorCount, 12, "Error count should reflect all 12 errors from counters")
    }

    func testClearResetsCountersAndEntries() async {
        let logger = RequestLogger()
        let url = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/AAPL")!

        for _ in 0..<5 {
            await logger.log(RequestLogEntry(url: url, statusCode: 500, responseSize: 0, duration: 0.1, error: "fail"))
        }

        await logger.clear()
        let entries = await logger.getEntries()
        let counts = await logger.getEndpointCounts()
        XCTAssertTrue(entries.isEmpty)
        XCTAssertTrue(counts.isEmpty)
    }

    func testClassifyEndpoint_allTypes() {
        XCTAssertEqual(RequestLogger.classifyEndpoint(URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/AAPL")!), "Yahoo Chart")
        XCTAssertEqual(RequestLogger.classifyEndpoint(URL(string: "https://query2.finance.yahoo.com/v7/finance/quote?symbols=AAPL")!), "Yahoo Quote")
        XCTAssertEqual(RequestLogger.classifyEndpoint(URL(string: "https://query2.finance.yahoo.com/ws/fundamentals-timeseries/v1/finance/timeseries/AAPL")!), "Yahoo Timeseries")
        XCTAssertEqual(RequestLogger.classifyEndpoint(URL(string: "https://fc.yahoo.com/v1/test")!), "Yahoo Auth")
        XCTAssertEqual(RequestLogger.classifyEndpoint(URL(string: "https://finnhub.io/api/v1/stock/candle?symbol=AAPL")!), "Finnhub Candle")
        XCTAssertEqual(RequestLogger.classifyEndpoint(URL(string: "https://finnhub.io/api/v1/quote?symbol=AAPL")!), "Finnhub Quote")
        XCTAssertEqual(RequestLogger.classifyEndpoint(URL(string: "https://www.cnbc.com/id/100003114/device/rss/rss.html")!), "CNBC RSS")
        XCTAssertEqual(RequestLogger.classifyEndpoint(URL(string: "https://example.com/other")!), "Other")
    }

    func testMixedSuccessAndErrors_onlyErrorsStored() async {
        let logger = RequestLogger()
        let chartURL = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/AAPL")!
        let quoteURL = URL(string: "https://query2.finance.yahoo.com/v7/finance/quote?symbols=AAPL")!

        for _ in 0..<12 {
            await logger.log(RequestLogEntry(url: chartURL, statusCode: 200, responseSize: 100, duration: 0.1))
        }
        for _ in 0..<3 {
            await logger.log(RequestLogEntry(url: quoteURL, statusCode: 500, responseSize: 0, duration: 0.1, error: "fail"))
        }

        let entries = await logger.getEntries()
        XCTAssertEqual(entries.count, 3, "Only error entries stored")
        XCTAssertTrue(entries.allSatisfy { !$0.isSuccess })
    }
}

private final class CountingHTTPClient: HTTPClient, @unchecked Sendable {
    private let lock = NSLock()
    private var _callCount = 0
    private let url: URL
    private let statusCode: Int

    var callCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return _callCount
    }

    init(url: URL, statusCode: Int) {
        self.url = url
        self.statusCode = statusCode
    }

    func data(from url: URL) async throws -> (Data, URLResponse) {
        lock.lock()
        _callCount += 1
        lock.unlock()
        let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
        return (Data(), response)
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        guard let url = request.url else { throw URLError(.badURL) }
        return try await data(from: url)
    }
}
