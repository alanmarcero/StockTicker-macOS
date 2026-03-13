import XCTest
@testable import StockTicker

final class CommodityETFsTests: XCTestCase {

    func testSymbolCount() {
        XCTAssertEqual(CommodityETFs.symbols.count, 14)
    }

    func testFirstSymbol_isGLD() {
        XCTAssertEqual(CommodityETFs.symbols.first, "GLD")
    }

    func testContainsAllCommodityETFs() {
        let symbols = Set(CommodityETFs.symbols)
        for expected in ["GLD", "IAU", "SLV", "PPLT", "PALL", "GDX", "GDXJ", "SIL", "COPX", "RING", "XME", "IBIT", "ETHE", "BITO"] {
            XCTAssertTrue(symbols.contains(expected), "\(expected) should be in Commodity ETFs")
        }
    }

    func testNoDuplicates() {
        let unique = Set(CommodityETFs.symbols)
        XCTAssertEqual(unique.count, CommodityETFs.symbols.count)
    }
}
