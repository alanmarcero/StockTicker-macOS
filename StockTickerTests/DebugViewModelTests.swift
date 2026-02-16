import XCTest
@testable import StockTicker

@MainActor
final class DebugViewModelTests: XCTestCase {

    func testRefresh_populatesEntriesFromLogger() async {
        let logger = RequestLogger()
        let url = URL(string: "https://example.com")!
        await logger.log(RequestLogEntry(url: url, statusCode: 200, responseSize: 100, duration: 0.1))

        let viewModel = DebugViewModel(logger: logger)
        viewModel.refresh()

        // Allow the inner Task to complete
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(viewModel.entries.count, 1)
        XCTAssertEqual(viewModel.errorCount, 0)
        XCTAssertNil(viewModel.lastErrorMessage)
    }

    func testRefresh_populatesErrorInfo() async {
        let logger = RequestLogger()
        let url = URL(string: "https://example.com")!
        await logger.log(RequestLogEntry(url: url, statusCode: 500, responseSize: 0, duration: 0.1, error: "Server error"))

        let viewModel = DebugViewModel(logger: logger)
        viewModel.refresh()

        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(viewModel.entries.count, 1)
        XCTAssertEqual(viewModel.errorCount, 1)
        XCTAssertEqual(viewModel.lastErrorMessage, "Server error")
    }

    func testClear_resetsAllState() async {
        let logger = RequestLogger()
        let url = URL(string: "https://example.com")!
        await logger.log(RequestLogEntry(url: url, statusCode: 500, responseSize: 0, duration: 0.1, error: "Error"))

        let viewModel = DebugViewModel(logger: logger)
        viewModel.refresh()
        try? await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(viewModel.errorCount, 1)

        viewModel.clear()
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(viewModel.entries.count, 0)
        XCTAssertEqual(viewModel.errorCount, 0)
        XCTAssertNil(viewModel.lastErrorMessage)
    }

    func testRefresh_showsHTTPStatusWhenNoErrorMessage() async {
        let logger = RequestLogger()
        let url = URL(string: "https://example.com")!
        await logger.log(RequestLogEntry(url: url, statusCode: 404, responseSize: 0, duration: 0.1))

        let viewModel = DebugViewModel(logger: logger)
        viewModel.refresh()
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(viewModel.lastErrorMessage, "HTTP 404")
    }
}
