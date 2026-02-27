import XCTest
@testable import StockTicker

final class TickerFilterTests: XCTestCase {

    // MARK: - OptionSet Basics

    func testEmpty_rawValueIsZero() {
        let filter = TickerFilter()
        XCTAssertEqual(filter.rawValue, 0)
        XCTAssertTrue(filter.isEmpty)
    }

    func testSingleOption_hasCorrectRawValue() {
        XCTAssertEqual(TickerFilter.greenYTD.rawValue, 1)
        XCTAssertEqual(TickerFilter.greenHigh.rawValue, 2)
        XCTAssertEqual(TickerFilter.greenLow.rawValue, 4)
    }

    func testCombinedOptions_hasCorrectRawValue() {
        let filter: TickerFilter = [.greenYTD, .greenHigh]
        XCTAssertEqual(filter.rawValue, 3)
        XCTAssertTrue(filter.contains(.greenYTD))
        XCTAssertTrue(filter.contains(.greenHigh))
        XCTAssertFalse(filter.contains(.greenLow))
    }

    func testAllOptions_containsThreeOptions() {
        XCTAssertEqual(TickerFilter.allOptions.count, 3)
    }

    // MARK: - displayName

    func testDisplayName_singleOptions() {
        XCTAssertEqual(TickerFilter.greenYTD.displayName, "Green YTD")
        XCTAssertEqual(TickerFilter.greenHigh.displayName, "Green High")
        XCTAssertEqual(TickerFilter.greenLow.displayName, "Green Low")
    }

    // MARK: - matches()

    func testMatches_emptyFilter_passesAll() {
        let filter = TickerFilter()
        let quote = StockQuote(symbol: "AAPL", price: 90.0, previousClose: 100.0)
        XCTAssertTrue(filter.matches(quote))
    }

    func testMatches_greenYTD_positiveYTD_passes() {
        let quote = StockQuote(symbol: "SPY", price: 110.0, previousClose: 109.0, ytdStartPrice: 100.0)
        XCTAssertTrue(TickerFilter.greenYTD.matches(quote))
    }

    func testMatches_greenYTD_negativeYTD_fails() {
        let quote = StockQuote(symbol: "SPY", price: 90.0, previousClose: 91.0, ytdStartPrice: 100.0)
        XCTAssertFalse(TickerFilter.greenYTD.matches(quote))
    }

    func testMatches_greenHigh_within5Percent_passes() {
        // price=97, highestClose=100 → changePercent = -3% → within -5% → green
        let quote = StockQuote(symbol: "SPY", price: 97.0, previousClose: 96.0, highestClose: 100.0)
        XCTAssertTrue(TickerFilter.greenHigh.matches(quote))
    }

    func testMatches_greenHigh_beyond5Percent_fails() {
        // price=90, highestClose=100 → changePercent = -10% → beyond -5% → red
        let quote = StockQuote(symbol: "SPY", price: 90.0, previousClose: 89.0, highestClose: 100.0)
        XCTAssertFalse(TickerFilter.greenHigh.matches(quote))
    }

    func testMatches_greenLow_above5Percent_passes() {
        // price=110, lowestClose=100 → changePercent = 10% → above 5% → green
        let quote = StockQuote(symbol: "SPY", price: 110.0, previousClose: 109.0, lowestClose: 100.0)
        XCTAssertTrue(TickerFilter.greenLow.matches(quote))
    }

    func testMatches_greenLow_within5Percent_fails() {
        // price=103, lowestClose=100 → changePercent = 3% → within 5% → red
        let quote = StockQuote(symbol: "SPY", price: 103.0, previousClose: 102.0, lowestClose: 100.0)
        XCTAssertFalse(TickerFilter.greenLow.matches(quote))
    }

    func testMatches_combinedFilter_requiresAll() {
        // Positive YTD but beyond 5% of high → fails combined [greenYTD, greenHigh]
        let quote = StockQuote(symbol: "SPY", price: 90.0, previousClose: 89.0, ytdStartPrice: 80.0, highestClose: 100.0)
        let filter: TickerFilter = [.greenYTD, .greenHigh]
        XCTAssertFalse(filter.matches(quote))
    }

    func testMatches_combinedFilter_allPass() {
        // Positive YTD, within 5% of high, above 5% of low
        let quote = StockQuote(symbol: "SPY", price: 99.0, previousClose: 98.0, ytdStartPrice: 90.0, highestClose: 100.0, lowestClose: 80.0)
        let filter: TickerFilter = [.greenYTD, .greenHigh, .greenLow]
        XCTAssertTrue(filter.matches(quote))
    }

    func testMatches_nilYTDData_excludedByGreenYTDFilter() {
        let quote = StockQuote(symbol: "SPY", price: 100.0, previousClose: 99.0)
        XCTAssertFalse(TickerFilter.greenYTD.matches(quote))
    }

    // MARK: - filter()

    func testFilter_emptyFilter_returnsAll() {
        let filter = TickerFilter()
        let symbols = ["SPY", "QQQ"]
        let quotes: [String: StockQuote] = [
            "SPY": StockQuote(symbol: "SPY", price: 90.0, previousClose: 100.0),
            "QQQ": StockQuote(symbol: "QQQ", price: 90.0, previousClose: 100.0)
        ]
        XCTAssertEqual(filter.filter(symbols, using: quotes), ["SPY", "QQQ"])
    }

    func testFilter_removesNonMatching() {
        let quotes: [String: StockQuote] = [
            "SPY": StockQuote(symbol: "SPY", price: 110.0, previousClose: 109.0, ytdStartPrice: 100.0),
            "QQQ": StockQuote(symbol: "QQQ", price: 90.0, previousClose: 91.0, ytdStartPrice: 100.0)
        ]
        let result = TickerFilter.greenYTD.filter(["SPY", "QQQ"], using: quotes)
        XCTAssertEqual(result, ["SPY"])
    }

    func testFilter_excludesMissingQuotes() {
        let quotes: [String: StockQuote] = [
            "SPY": StockQuote(symbol: "SPY", price: 110.0, previousClose: 109.0, ytdStartPrice: 100.0)
        ]
        let result = TickerFilter.greenYTD.filter(["SPY", "QQQ"], using: quotes)
        XCTAssertEqual(result, ["SPY"])
    }

    // MARK: - Toggle via formSymmetricDifference

    func testToggle_addsAndRemovesOption() {
        var filter = TickerFilter()
        filter.formSymmetricDifference(.greenYTD)
        XCTAssertTrue(filter.contains(.greenYTD))
        filter.formSymmetricDifference(.greenYTD)
        XCTAssertFalse(filter.contains(.greenYTD))
    }

    // MARK: - Codable

    func testCodable_roundTrip() throws {
        let filter: TickerFilter = [.greenYTD, .greenLow]
        let data = try JSONEncoder().encode(filter)
        let decoded = try JSONDecoder().decode(TickerFilter.self, from: data)
        XCTAssertEqual(decoded, filter)
    }
}
