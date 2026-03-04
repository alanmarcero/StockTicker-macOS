import XCTest
@testable import StockTicker

final class VanguardETFsTests: XCTestCase {

    func testSymbolCount_isTop50Percent() {
        // 52 symbols = top 50% of ~103 Vanguard ETFs
        XCTAssertEqual(VanguardETFs.symbols.count, 52)
    }

    func testFirstSymbol_isVOO() {
        XCTAssertEqual(VanguardETFs.symbols.first, "VOO")
    }

    func testContainsKeyETFs() {
        let symbols = Set(VanguardETFs.symbols)
        XCTAssertTrue(symbols.contains("VOO"))
        XCTAssertTrue(symbols.contains("VTI"))
        XCTAssertTrue(symbols.contains("VEA"))
        XCTAssertTrue(symbols.contains("BND"))
        XCTAssertTrue(symbols.contains("VGT"))
    }

    func testNoDuplicates() {
        let unique = Set(VanguardETFs.symbols)
        XCTAssertEqual(unique.count, VanguardETFs.symbols.count)
    }
}
