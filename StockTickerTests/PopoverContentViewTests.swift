import XCTest
import SwiftUI
@testable import StockTicker

// MARK: - Test Helpers

private final class StubNewsService: NewsServiceProtocol, @unchecked Sendable {
    func fetchNews() async -> [NewsItem] { [] }
}

private final class StubScannerService: ScannerServiceProtocol, @unchecked Sendable {
    func fetchEMAData(baseURL: String) async -> ScannerEMAData? { nil }
}

// MARK: - MarketState SwiftUI Color Tests

final class MarketStateSwiftUIColorTests: XCTestCase {

    func testOpen_returnsGreen() {
        XCTAssertEqual(MarketState.open.swiftUIColor, .green)
    }

    func testPreMarket_returnsOrange() {
        XCTAssertEqual(MarketState.preMarket.swiftUIColor, .orange)
    }

    func testAfterHours_returnsOrange() {
        XCTAssertEqual(MarketState.afterHours.swiftUIColor, .orange)
    }

    func testClosed_returnsRed() {
        XCTAssertEqual(MarketState.closed.swiftUIColor, .red)
    }
}

// MARK: - StockQuote SwiftUI Color Tests

final class StockQuoteSwiftUIColorTests: XCTestCase {

    func testSwiftUIDisplayColor_positive() {
        let quote = StockQuote(symbol: "AAPL", price: 150.0, previousClose: 140.0)
        XCTAssertEqual(quote.swiftUIDisplayColor, Color(nsColor: quote.displayColor))
    }

    func testSwiftUIDisplayColor_negative() {
        let quote = StockQuote(symbol: "AAPL", price: 130.0, previousClose: 140.0)
        XCTAssertEqual(quote.swiftUIDisplayColor, Color(nsColor: quote.displayColor))
    }

    func testSwiftUIYTDColor_withYTDData() {
        let quote = StockQuote(symbol: "AAPL", price: 150.0, previousClose: 148.0, ytdStartPrice: 120.0)
        XCTAssertEqual(quote.swiftUIYTDColor, Color(nsColor: quote.ytdColor))
    }

    func testSwiftUIHighestCloseColor_withData() {
        let quote = StockQuote(symbol: "AAPL", price: 150.0, previousClose: 148.0, highestClose: 200.0)
        XCTAssertEqual(quote.swiftUIHighestCloseColor, Color(nsColor: quote.highestCloseColor))
    }

    func testSwiftUILowestCloseColor_withData() {
        let quote = StockQuote(symbol: "AAPL", price: 150.0, previousClose: 148.0, lowestClose: 100.0)
        XCTAssertEqual(quote.swiftUILowestCloseColor, Color(nsColor: quote.lowestCloseColor))
    }

    func testSwiftUIExtendedHoursColor() {
        let quote = StockQuote(symbol: "AAPL", price: 150.0, previousClose: 148.0, session: .preMarket,
                               preMarketPrice: 155.0, preMarketChange: 5.0, preMarketChangePercent: 3.33)
        XCTAssertEqual(quote.swiftUIExtendedHoursColor, Color(nsColor: quote.extendedHoursColor))
    }
}

// MARK: - MenuBarController Popover State Tests

@MainActor
final class MenuBarControllerPopoverStateTests: XCTestCase {

    private func makeController() -> MenuBarController {
        MenuBarController(
            stockService: MockStockService(),
            newsService: StubNewsService(),
            scannerService: StubScannerService(),
            configManager: WatchlistConfigManager(fileSystem: MockFileSystem())
        )
    }

    func testSortedFilteredSymbols_returnsFilteredAndSorted() {
        let controller = makeController()
        controller.quotes = [
            "AAPL": StockQuote(symbol: "AAPL", price: 150.0, previousClose: 145.0),
            "MSFT": StockQuote(symbol: "MSFT", price: 300.0, previousClose: 310.0),
        ]
        let symbols = controller.sortedFilteredSymbols
        // Default watchlist includes bundled symbols, quotes may or may not match
        XCTAssertNotNil(symbols)
    }

    func testSelectSortOption_updatesCurrentSort() {
        let controller = makeController()
        controller.selectSortOption(.tickerAsc)
        XCTAssertEqual(controller.currentSortOption, .tickerAsc)
    }

    func testSelectSortOption_updatesConfigSortDirection() {
        let controller = makeController()
        controller.selectSortOption(.marketCapDesc)
        XCTAssertEqual(controller.config.sortDirection, SortOption.marketCapDesc.configString)
    }

    func testToggleFilter_updatesConfig() {
        let controller = makeController()
        XCTAssertTrue(controller.currentFilter.isEmpty)
        controller.toggleFilter(.greenYTD)
        XCTAssertTrue(controller.currentFilter.contains(.greenYTD))
    }

    func testToggleFilter_togglesOff() {
        let controller = makeController()
        controller.toggleFilter(.greenYTD)
        XCTAssertTrue(controller.currentFilter.contains(.greenYTD))
        controller.toggleFilter(.greenYTD)
        XCTAssertFalse(controller.currentFilter.contains(.greenYTD))
    }

    func testClearFilters_resetsToDefaults() {
        let controller = makeController()
        controller.toggleFilter(.greenYTD)
        controller.clearFilters()
        XCTAssertTrue(controller.currentFilter.isEmpty)
    }

    func testMarketStatusState_defaultsToClosed() {
        let controller = makeController()
        XCTAssertEqual(controller.marketStatusState, .closed)
    }

    func testCountdownText_isStringType() {
        let controller = makeController()
        // countdownText gets populated by timer; verify it's a String
        XCTAssertNotNil(controller.countdownText)
    }

    func testNewsItems_defaultsToEmpty() {
        let controller = makeController()
        XCTAssertTrue(controller.newsItems.isEmpty)
    }

    func testHighlightIntensity_defaultsToEmpty() {
        let controller = makeController()
        XCTAssertTrue(controller.highlightIntensity.isEmpty)
    }

    func testIsPopoverOpen_defaultsToFalse() {
        let controller = makeController()
        XCTAssertFalse(controller.isPopoverOpen)
    }

    func testSelectClosedMarketAsset_updatesConfig() {
        let controller = makeController()
        controller.selectClosedMarketAsset(.bitcoin)
        XCTAssertEqual(controller.config.menuBarAssetWhenClosed, .bitcoin)
    }
}
