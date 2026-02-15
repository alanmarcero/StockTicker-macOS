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
}
