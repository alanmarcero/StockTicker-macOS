import XCTest
@testable import StockTicker

final class SPDRSectorETFsTests: XCTestCase {

    func testSymbolCount() {
        XCTAssertEqual(SPDRSectorETFs.symbols.count, 12)
    }

    func testFirstSymbol_isSPY() {
        XCTAssertEqual(SPDRSectorETFs.symbols.first, "SPY")
    }

    func testContainsAllSectorETFs() {
        let symbols = Set(SPDRSectorETFs.symbols)
        for expected in ["SPY", "XLE", "XLK", "XLB", "XLV", "XLY", "XLI", "XLC", "XLU", "XLF", "XLRE", "XLP"] {
            XCTAssertTrue(symbols.contains(expected), "\(expected) should be in SPDR Sectors")
        }
    }

    func testNoDuplicates() {
        let unique = Set(SPDRSectorETFs.symbols)
        XCTAssertEqual(unique.count, SPDRSectorETFs.symbols.count)
    }
}
