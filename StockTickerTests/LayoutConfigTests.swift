import XCTest
@testable import StockTicker

// MARK: - LayoutConfig Tests

final class LayoutConfigTests: XCTestCase {

    // MARK: - Positive Value Tests

    func testTicker_allWidths_arePositive() {
        XCTAssertGreaterThan(LayoutConfig.Ticker.symbolWidth, 0)
        XCTAssertGreaterThan(LayoutConfig.Ticker.priceWidth, 0)
        XCTAssertGreaterThan(LayoutConfig.Ticker.changeWidth, 0)
        XCTAssertGreaterThan(LayoutConfig.Ticker.percentWidth, 0)
    }

    func testFont_allSizes_arePositive() {
        XCTAssertGreaterThan(LayoutConfig.Font.size, 0)
        XCTAssertGreaterThan(LayoutConfig.Font.headerSize, 0)
        XCTAssertGreaterThan(LayoutConfig.Font.scheduleSize, 0)
    }

    func testMarquee_dimensions_arePositive() {
        XCTAssertGreaterThan(LayoutConfig.Marquee.width, 0)
        XCTAssertGreaterThan(LayoutConfig.Marquee.height, 0)
    }

    func testHeadlines_values_arePositive() {
        XCTAssertGreaterThan(LayoutConfig.Headlines.maxLength, 0)
        XCTAssertGreaterThan(LayoutConfig.Headlines.itemsPerSource, 0)
    }

    func testEditorWindow_dimensions_arePositive() {
        XCTAssertGreaterThan(LayoutConfig.EditorWindow.defaultWidth, 0)
        XCTAssertGreaterThan(LayoutConfig.EditorWindow.defaultHeight, 0)
        XCTAssertGreaterThan(LayoutConfig.EditorWindow.minWidth, 0)
        XCTAssertGreaterThan(LayoutConfig.EditorWindow.minHeight, 0)
        XCTAssertGreaterThan(LayoutConfig.EditorWindow.buttonWidth, 0)
    }

    func testDebugWindow_dimensions_arePositive() {
        XCTAssertGreaterThan(LayoutConfig.DebugWindow.width, 0)
        XCTAssertGreaterThan(LayoutConfig.DebugWindow.height, 0)
        XCTAssertGreaterThan(LayoutConfig.DebugWindow.minWidth, 0)
        XCTAssertGreaterThan(LayoutConfig.DebugWindow.minHeight, 0)
        XCTAssertGreaterThan(LayoutConfig.DebugWindow.statusColumnWidth, 0)
    }

    func testWatchlist_maxSize_isPositive() {
        XCTAssertGreaterThan(LayoutConfig.Watchlist.maxSize, 0)
    }

    // MARK: - Constraint Tests

    func testEditorWindow_minWidth_lessThanDefaultWidth() {
        XCTAssertLessThan(LayoutConfig.EditorWindow.minWidth, LayoutConfig.EditorWindow.defaultWidth)
    }

    func testEditorWindow_minHeight_lessThanDefaultHeight() {
        XCTAssertLessThan(LayoutConfig.EditorWindow.minHeight, LayoutConfig.EditorWindow.defaultHeight)
    }

    func testDebugWindow_minWidth_lessThanWidth() {
        XCTAssertLessThan(LayoutConfig.DebugWindow.minWidth, LayoutConfig.DebugWindow.width)
    }

    func testDebugWindow_minHeight_lessThanHeight() {
        XCTAssertLessThan(LayoutConfig.DebugWindow.minHeight, LayoutConfig.DebugWindow.height)
    }

    func testMarquee_width_greaterThanHeight() {
        XCTAssertGreaterThan(LayoutConfig.Marquee.width, LayoutConfig.Marquee.height)
    }

    func testHeadlines_maxLength_isReasonable() {
        XCTAssertGreaterThanOrEqual(LayoutConfig.Headlines.maxLength, 20)
        XCTAssertLessThanOrEqual(LayoutConfig.Headlines.maxLength, 100)
    }

    func testWatchlist_maxSize_isReasonable() {
        XCTAssertGreaterThanOrEqual(LayoutConfig.Watchlist.maxSize, 1)
        XCTAssertLessThanOrEqual(LayoutConfig.Watchlist.maxSize, 100)
    }
}
