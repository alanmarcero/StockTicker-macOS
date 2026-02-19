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
        let client = LoggingHTTPClient(wrapping: mock, logger: logger)

        let (_, response) = try await client.data(from: url)
        let httpResponse = response as! HTTPURLResponse
        XCTAssertEqual(httpResponse.statusCode, 500)
        XCTAssertEqual(mock.callCount, 2, "500 should be retried once")
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
