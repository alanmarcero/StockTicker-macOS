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

    func testRefresh_populatesEndpointCounts() async {
        let logger = RequestLogger()
        await logger.log(RequestLogEntry(url: URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/AAPL")!, statusCode: 200, responseSize: 100, duration: 0.1))
        await logger.log(RequestLogEntry(url: URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/MSFT")!, statusCode: 200, responseSize: 100, duration: 0.1))
        await logger.log(RequestLogEntry(url: URL(string: "https://query2.finance.yahoo.com/v7/finance/quote?symbols=AAPL")!, statusCode: 200, responseSize: 100, duration: 0.1))
        await logger.log(RequestLogEntry(url: URL(string: "https://finnhub.io/api/v1/quote?symbol=AAPL")!, statusCode: 200, responseSize: 100, duration: 0.1))
        await logger.log(RequestLogEntry(url: URL(string: "https://www.cnbc.com/id/100003114/device/rss/rss.html")!, statusCode: 200, responseSize: 100, duration: 0.1))

        let viewModel = DebugViewModel(logger: logger)
        viewModel.refresh()
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(viewModel.endpointCounts.count, 4)
        // Sorted by count descending: Yahoo Chart (2), then others (1 each)
        XCTAssertEqual(viewModel.endpointCounts[0].label, "Yahoo Chart")
        XCTAssertEqual(viewModel.endpointCounts[0].count, 2)
        let labels = Set(viewModel.endpointCounts.map { $0.label })
        XCTAssertTrue(labels.contains("Yahoo Quote"))
        XCTAssertTrue(labels.contains("Finnhub Quote"))
        XCTAssertTrue(labels.contains("CNBC RSS"))
    }

    func testFilteredEntries_returnsAllWhenFilterOff() async {
        let logger = RequestLogger()
        let url = URL(string: "https://example.com")!
        await logger.log(RequestLogEntry(url: url, statusCode: 200, responseSize: 100, duration: 0.1))
        await logger.log(RequestLogEntry(url: url, statusCode: 500, responseSize: 0, duration: 0.1, error: "Server error"))

        let viewModel = DebugViewModel(logger: logger)
        viewModel.refresh()
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertFalse(viewModel.showErrorsOnly)
        XCTAssertEqual(viewModel.filteredEntries.count, 2)
    }

    func testFilteredEntries_returnsOnlyErrorsWhenFilterOn() async {
        let logger = RequestLogger()
        let url = URL(string: "https://example.com")!
        await logger.log(RequestLogEntry(url: url, statusCode: 200, responseSize: 100, duration: 0.1))
        await logger.log(RequestLogEntry(url: url, statusCode: 500, responseSize: 0, duration: 0.1, error: "Server error"))
        await logger.log(RequestLogEntry(url: url, statusCode: 404, responseSize: 0, duration: 0.1))

        let viewModel = DebugViewModel(logger: logger)
        viewModel.refresh()
        try? await Task.sleep(nanoseconds: 50_000_000)

        viewModel.showErrorsOnly = true
        XCTAssertEqual(viewModel.filteredEntries.count, 2)
        XCTAssertTrue(viewModel.filteredEntries.allSatisfy { !$0.isSuccess })
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
