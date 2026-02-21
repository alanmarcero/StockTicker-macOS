import XCTest
@testable import StockTicker

final class SymbolRoutingTests: XCTestCase {

    // MARK: - historicalSource (always Yahoo — candle endpoint requires paid tier)

    func testHistoricalSource_equity_withKey_returnsYahoo() {
        let source = SymbolRouting.historicalSource(for: "AAPL", finnhubApiKey: "test_key")
        XCTAssertEqual(source, .yahoo)
    }

    func testHistoricalSource_index_withKey_returnsYahoo() {
        let source = SymbolRouting.historicalSource(for: "^GSPC", finnhubApiKey: "test_key")
        XCTAssertEqual(source, .yahoo)
    }

    func testHistoricalSource_equity_nilKey_returnsYahoo() {
        let source = SymbolRouting.historicalSource(for: "AAPL", finnhubApiKey: "")
        XCTAssertEqual(source, .yahoo)
    }

    // MARK: - isFinnhubCompatible

    func testIsFinnhubCompatible_equity_returnsTrue() {
        XCTAssertTrue(SymbolRouting.isFinnhubCompatible("AAPL"))
        XCTAssertTrue(SymbolRouting.isFinnhubCompatible("SPY"))
    }

    func testIsFinnhubCompatible_index_returnsFalse() {
        XCTAssertFalse(SymbolRouting.isFinnhubCompatible("^GSPC"))
        XCTAssertFalse(SymbolRouting.isFinnhubCompatible("^DJI"))
    }

    func testIsFinnhubCompatible_crypto_returnsFalse() {
        XCTAssertFalse(SymbolRouting.isFinnhubCompatible("BTC-USD"))
        XCTAssertFalse(SymbolRouting.isFinnhubCompatible("BRK-B"))
    }

    // MARK: - partition

    func testPartition_mixedSymbols_splitsCorrectly() {
        let symbols = ["AAPL", "^GSPC", "BTC-USD", "SPY", "^DJI", "ETH-USD", "MSFT"]
        let (finnhub, yahoo) = SymbolRouting.partition(symbols, finnhubApiKey: "test_key")

        XCTAssertEqual(Set(finnhub), Set(["AAPL", "SPY", "MSFT"]))
        XCTAssertEqual(Set(yahoo), Set(["^GSPC", "BTC-USD", "^DJI", "ETH-USD"]))
    }

    func testPartition_nilKey_allYahoo() {
        let symbols = ["AAPL", "^GSPC", "BTC-USD", "SPY"]
        let (finnhub, yahoo) = SymbolRouting.partition(symbols, finnhubApiKey: "")

        XCTAssertTrue(finnhub.isEmpty)
        XCTAssertEqual(Set(yahoo), Set(symbols))
    }

    func testPartition_emptyArray_returnsBothEmpty() {
        let (finnhub, yahoo) = SymbolRouting.partition([], finnhubApiKey: "test_key")

        XCTAssertTrue(finnhub.isEmpty)
        XCTAssertTrue(yahoo.isEmpty)
    }

    func testPartition_allEquities_allFinnhub() {
        let symbols = ["AAPL", "MSFT", "GOOGL"]
        let (finnhub, yahoo) = SymbolRouting.partition(symbols, finnhubApiKey: "test_key")

        XCTAssertEqual(finnhub, symbols)
        XCTAssertTrue(yahoo.isEmpty)
    }
}