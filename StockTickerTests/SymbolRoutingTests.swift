import XCTest
@testable import StockTicker

final class SymbolRoutingTests: XCTestCase {

    // MARK: - historicalSource

    func testHistoricalSource_equity_withKey_returnsFinnhub() {
        let source = SymbolRouting.historicalSource(for: "AAPL", finnhubApiKey: "test_key")
        XCTAssertEqual(source, .finnhub)
    }

    func testHistoricalSource_etf_withKey_returnsFinnhub() {
        let source = SymbolRouting.historicalSource(for: "SPY", finnhubApiKey: "test_key")
        XCTAssertEqual(source, .finnhub)
    }

    func testHistoricalSource_index_withKey_returnsYahoo() {
        let source = SymbolRouting.historicalSource(for: "^GSPC", finnhubApiKey: "test_key")
        XCTAssertEqual(source, .yahoo)
    }

    func testHistoricalSource_crypto_withKey_returnsYahoo() {
        let source = SymbolRouting.historicalSource(for: "BTC-USD", finnhubApiKey: "test_key")
        XCTAssertEqual(source, .yahoo)
    }

    func testHistoricalSource_brkb_withKey_returnsYahoo() {
        let source = SymbolRouting.historicalSource(for: "BRK-B", finnhubApiKey: "test_key")
        XCTAssertEqual(source, .yahoo)
    }

    func testHistoricalSource_equity_nilKey_returnsYahoo() {
        let source = SymbolRouting.historicalSource(for: "AAPL", finnhubApiKey: nil)
        XCTAssertEqual(source, .yahoo)
    }

    func testHistoricalSource_index_nilKey_returnsYahoo() {
        let source = SymbolRouting.historicalSource(for: "^GSPC", finnhubApiKey: nil)
        XCTAssertEqual(source, .yahoo)
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
        let (finnhub, yahoo) = SymbolRouting.partition(symbols, finnhubApiKey: nil)

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