import XCTest
@testable import StockTicker

final class WatchlistSourceTests: XCTestCase {

    // MARK: - OptionSet basics

    func testRawValues() {
        XCTAssertEqual(WatchlistSource.megaCap.rawValue, 1)
        XCTAssertEqual(WatchlistSource.topAUMETFs.rawValue, 2)
        XCTAssertEqual(WatchlistSource.topVolETFs.rawValue, 4)
        XCTAssertEqual(WatchlistSource.personal.rawValue, 8)
    }

    func testAllSources_containsAllBits() {
        let all = WatchlistSource.allSources
        XCTAssertTrue(all.contains(.megaCap))
        XCTAssertTrue(all.contains(.topAUMETFs))
        XCTAssertTrue(all.contains(.topVolETFs))
        XCTAssertTrue(all.contains(.personal))
        XCTAssertEqual(all.rawValue, 15)
    }

    func testAllCases_hasFourSources() {
        XCTAssertEqual(WatchlistSource.allCases.count, 4)
    }

    // MARK: - Display names

    func testDisplayName_megaCap() {
        XCTAssertEqual(WatchlistSource.megaCap.displayName, "$200B+")
    }

    func testDisplayName_topAUMETFs() {
        XCTAssertEqual(WatchlistSource.topAUMETFs.displayName, "Top AUM ETFs")
    }

    func testDisplayName_topVolETFs() {
        XCTAssertEqual(WatchlistSource.topVolETFs.displayName, "Top Vol ETFs")
    }

    func testDisplayName_personal() {
        XCTAssertEqual(WatchlistSource.personal.displayName, "My Watchlist")
    }

    // MARK: - symbols()

    func testSymbols_personalOnly_returnsPersonalWatchlist() {
        let source = WatchlistSource.personal
        let result = source.symbols(personalWatchlist: ["AAPL", "MSFT"])
        XCTAssertEqual(result, ["AAPL", "MSFT"])
    }

    func testSymbols_megaCapOnly_returnsMegaCapSymbols() {
        let source = WatchlistSource.megaCap
        let result = source.symbols(personalWatchlist: [])
        XCTAssertEqual(result, MegaCapEquities.symbols)
    }

    func testSymbols_allSources_deduplicates() {
        let personal = ["AAPL", "SPY", "CUSTOM"]
        let result = WatchlistSource.allSources.symbols(personalWatchlist: personal)
        let aapl = result.filter { $0 == "AAPL" }
        let spy = result.filter { $0 == "SPY" }
        XCTAssertEqual(aapl.count, 1, "AAPL should appear once (from megaCap)")
        XCTAssertEqual(spy.count, 1, "SPY should appear once (from topAUM)")
        XCTAssertTrue(result.contains("CUSTOM"), "Personal-only symbol should be included")
    }

    func testSymbols_emptySources_returnsEmpty() {
        let source = WatchlistSource(rawValue: 0)
        let result = source.symbols(personalWatchlist: ["AAPL"])
        XCTAssertTrue(result.isEmpty)
    }

    func testSymbols_orderPreserved_megaCapFirst() {
        let source: WatchlistSource = [.megaCap, .personal]
        let result = source.symbols(personalWatchlist: ["ZZZZ"])
        XCTAssertEqual(result.first, MegaCapEquities.symbols.first)
        XCTAssertEqual(result.last, "ZZZZ")
    }

    // MARK: - allSymbols()

    func testAllSymbols_includesAllSources() {
        let personal = ["CUSTOM1", "CUSTOM2"]
        let result = WatchlistSource.allSymbols(personalWatchlist: personal)
        XCTAssertTrue(result.contains("CUSTOM1"))
        XCTAssertTrue(result.contains("CUSTOM2"))
        XCTAssertTrue(result.contains(MegaCapEquities.symbols[0]))
        XCTAssertTrue(result.contains(TopAUMETFs.symbols[0]))
        XCTAssertTrue(result.contains(TopVolumeETFs.symbols[0]))
    }

    // MARK: - allBundledSymbols

    func testAllBundledSymbols_doesNotIncludePersonal() {
        let bundled = WatchlistSource.allBundledSymbols
        XCTAssertFalse(bundled.contains("CUSTOM_SYMBOL"))
        XCTAssertTrue(bundled.contains("AAPL"))
        XCTAssertTrue(bundled.contains("SPY"))
    }

    // MARK: - Codable

    func testCodable_roundTrip() throws {
        let source: WatchlistSource = [.megaCap, .personal]
        let data = try JSONEncoder().encode(source)
        let decoded = try JSONDecoder().decode(WatchlistSource.self, from: data)
        XCTAssertEqual(decoded, source)
    }

    func testCodable_allSources_roundTrip() throws {
        let source = WatchlistSource.allSources
        let data = try JSONEncoder().encode(source)
        let decoded = try JSONDecoder().decode(WatchlistSource.self, from: data)
        XCTAssertEqual(decoded, source)
    }
}
