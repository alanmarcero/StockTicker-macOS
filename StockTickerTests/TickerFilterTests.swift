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
        XCTAssertEqual(TickerFilter.etf.rawValue, 8)
        XCTAssertEqual(TickerFilter.asset.rawValue, 16)
    }

    func testCombinedOptions_hasCorrectRawValue() {
        let filter: TickerFilter = [.greenYTD, .greenHigh]
        XCTAssertEqual(filter.rawValue, 3)
        XCTAssertTrue(filter.contains(.greenYTD))
        XCTAssertTrue(filter.contains(.greenHigh))
        XCTAssertFalse(filter.contains(.greenLow))
    }

    func testAllOptions_containsFiveOptions() {
        XCTAssertEqual(TickerFilter.allOptions.count, 5)
    }

    func testGreenOptions_containsThree() {
        XCTAssertEqual(TickerFilter.greenOptions.count, 3)
    }

    func testTypeOptions_containsTwo() {
        XCTAssertEqual(TickerFilter.typeOptions.count, 2)
    }

    // MARK: - displayName

    func testDisplayName_singleOptions() {
        XCTAssertEqual(TickerFilter.greenYTD.displayName, "Green YTD")
        XCTAssertEqual(TickerFilter.greenHigh.displayName, "Green High")
        XCTAssertEqual(TickerFilter.greenLow.displayName, "Green Low")
        XCTAssertEqual(TickerFilter.etf.displayName, "ETFs")
        XCTAssertEqual(TickerFilter.asset.displayName, "Assets")
    }

    // MARK: - isETF / isAsset predicates

    func testIsETF_nilMarketCap_returnsTrue() {
        let quote = StockQuote(symbol: "SPY", price: 100.0, previousClose: 99.0)
        XCTAssertTrue(quote.isETF)
    }

    func testIsETF_nonNilMarketCap_returnsFalse() {
        let quote = StockQuote(symbol: "AAPL", price: 100.0, previousClose: 99.0, marketCap: 3_000_000_000_000)
        XCTAssertFalse(quote.isETF)
    }

    func testIsAsset_nonNilMarketCap_returnsTrue() {
        let quote = StockQuote(symbol: "AAPL", price: 100.0, previousClose: 99.0, marketCap: 3_000_000_000_000)
        XCTAssertTrue(quote.isAsset)
    }

    func testIsAsset_nilMarketCap_returnsFalse() {
        let quote = StockQuote(symbol: "SPY", price: 100.0, previousClose: 99.0)
        XCTAssertFalse(quote.isAsset)
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

    func testMatches_etf_nilMarketCap_passes() {
        let quote = StockQuote(symbol: "SPY", price: 100.0, previousClose: 99.0)
        XCTAssertTrue(TickerFilter.etf.matches(quote))
    }

    func testMatches_etf_nonNilMarketCap_fails() {
        let quote = StockQuote(symbol: "AAPL", price: 100.0, previousClose: 99.0, marketCap: 3_000_000_000_000)
        XCTAssertFalse(TickerFilter.etf.matches(quote))
    }

    func testMatches_asset_nonNilMarketCap_passes() {
        let quote = StockQuote(symbol: "AAPL", price: 100.0, previousClose: 99.0, marketCap: 3_000_000_000_000)
        XCTAssertTrue(TickerFilter.asset.matches(quote))
    }

    func testMatches_asset_nilMarketCap_fails() {
        let quote = StockQuote(symbol: "SPY", price: 100.0, previousClose: 99.0)
        XCTAssertFalse(TickerFilter.asset.matches(quote))
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

    func testMatches_greenYTDAndAsset_requiresBoth() {
        // Positive YTD but no marketCap (ETF) → fails asset check
        let etf = StockQuote(symbol: "SPY", price: 110.0, previousClose: 109.0, ytdStartPrice: 100.0)
        let filter: TickerFilter = [.greenYTD, .asset]
        XCTAssertFalse(filter.matches(etf))

        // Positive YTD with marketCap → passes both
        let stock = StockQuote(symbol: "AAPL", price: 110.0, previousClose: 109.0, ytdStartPrice: 100.0, marketCap: 3_000_000_000_000)
        XCTAssertTrue(filter.matches(stock))
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

    func testFilter_etf_keepsOnlyETFs() {
        let quotes: [String: StockQuote] = [
            "SPY": StockQuote(symbol: "SPY", price: 100.0, previousClose: 99.0),
            "AAPL": StockQuote(symbol: "AAPL", price: 100.0, previousClose: 99.0, marketCap: 3_000_000_000_000)
        ]
        let result = TickerFilter.etf.filter(["SPY", "AAPL"], using: quotes)
        XCTAssertEqual(result, ["SPY"])
    }

    func testFilter_asset_keepsOnlyAssets() {
        let quotes: [String: StockQuote] = [
            "SPY": StockQuote(symbol: "SPY", price: 100.0, previousClose: 99.0),
            "AAPL": StockQuote(symbol: "AAPL", price: 100.0, previousClose: 99.0, marketCap: 3_000_000_000_000)
        ]
        let result = TickerFilter.asset.filter(["SPY", "AAPL"], using: quotes)
        XCTAssertEqual(result, ["AAPL"])
    }

    func testMatches_bothETFAndAsset_usesORSemantics() {
        let etf = StockQuote(symbol: "SPY", price: 100.0, previousClose: 99.0)
        let stock = StockQuote(symbol: "AAPL", price: 100.0, previousClose: 99.0, marketCap: 3_000_000_000_000)
        let filter: TickerFilter = [.etf, .asset]
        XCTAssertTrue(filter.matches(etf))
        XCTAssertTrue(filter.matches(stock))
    }

    func testFilter_bothETFAndAsset_keepsAll() {
        let quotes: [String: StockQuote] = [
            "SPY": StockQuote(symbol: "SPY", price: 100.0, previousClose: 99.0),
            "AAPL": StockQuote(symbol: "AAPL", price: 100.0, previousClose: 99.0, marketCap: 3_000_000_000_000)
        ]
        let filter: TickerFilter = [.etf, .asset]
        let result = filter.filter(["SPY", "AAPL"], using: quotes)
        XCTAssertEqual(result, ["SPY", "AAPL"])
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

    func testCodable_roundTrip_withTypeFilters() throws {
        let filter: TickerFilter = [.etf, .greenYTD]
        let data = try JSONEncoder().encode(filter)
        let decoded = try JSONDecoder().decode(TickerFilter.self, from: data)
        XCTAssertEqual(decoded, filter)
    }
}
