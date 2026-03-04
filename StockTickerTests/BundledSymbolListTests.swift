import XCTest
@testable import StockTicker

final class BundledSymbolListTests: XCTestCase {

    // MARK: - MegaCapEquities

    func testMegaCapEquities_hasExpectedCount() {
        XCTAssertEqual(MegaCapEquities.symbols.count, 89)
    }

    func testMegaCapEquities_noDuplicates() {
        let set = Set(MegaCapEquities.symbols)
        XCTAssertEqual(set.count, MegaCapEquities.symbols.count)
    }

    func testMegaCapEquities_spotCheckSymbols() {
        let symbols = MegaCapEquities.symbols
        XCTAssertTrue(symbols.contains("AAPL"))
        XCTAssertTrue(symbols.contains("MSFT"))
        XCTAssertTrue(symbols.contains("NVDA"))
        XCTAssertTrue(symbols.contains("GOOGL"))
        XCTAssertTrue(symbols.contains("AMZN"))
        XCTAssertTrue(symbols.contains("BRK-B"))
    }

    // MARK: - TopAUMETFs

    func testTopAUMETFs_has30Symbols() {
        XCTAssertEqual(TopAUMETFs.symbols.count, 30)
    }

    func testTopAUMETFs_noDuplicates() {
        let set = Set(TopAUMETFs.symbols)
        XCTAssertEqual(set.count, TopAUMETFs.symbols.count)
    }

    func testTopAUMETFs_spotCheckSymbols() {
        let symbols = TopAUMETFs.symbols
        XCTAssertTrue(symbols.contains("SPY"))
        XCTAssertTrue(symbols.contains("QQQ"))
        XCTAssertTrue(symbols.contains("VOO"))
        XCTAssertTrue(symbols.contains("GLD"))
        XCTAssertTrue(symbols.contains("IWM"))
    }

    // MARK: - TopVolumeETFs

    func testTopVolumeETFs_has10Symbols() {
        XCTAssertEqual(TopVolumeETFs.symbols.count, 10)
    }

    func testTopVolumeETFs_noDuplicates() {
        let set = Set(TopVolumeETFs.symbols)
        XCTAssertEqual(set.count, TopVolumeETFs.symbols.count)
    }

    func testTopVolumeETFs_spotCheckSymbols() {
        let symbols = TopVolumeETFs.symbols
        XCTAssertTrue(symbols.contains("SPY"))
        XCTAssertTrue(symbols.contains("SMH"))
        XCTAssertTrue(symbols.contains("IBIT"))
    }

    // MARK: - Cross-list overlap

    func testBundledLists_haveExpectedOverlap() {
        let megaCap = Set(MegaCapEquities.symbols)
        let aum = Set(TopAUMETFs.symbols)
        let vol = Set(TopVolumeETFs.symbols)

        // MegaCap and AUM should have no overlap (equities vs ETFs)
        let megaAumOverlap = megaCap.intersection(aum)
        XCTAssertTrue(megaAumOverlap.isEmpty, "MegaCap and AUM ETFs should not overlap: \(megaAumOverlap)")

        // AUM and Volume ETFs should overlap (SPY, QQQ, IWM are in both)
        let aumVolOverlap = aum.intersection(vol)
        XCTAssertFalse(aumVolOverlap.isEmpty, "AUM and Volume ETFs should overlap")
        XCTAssertTrue(aumVolOverlap.contains("SPY"))
        XCTAssertTrue(aumVolOverlap.contains("QQQ"))
    }
}
