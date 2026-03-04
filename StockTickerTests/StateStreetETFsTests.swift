import XCTest
@testable import StockTicker

final class StateStreetETFsTests: XCTestCase {

    func testSymbolCount_isTop50Percent() {
        // 69 symbols = top 50% of ~137 SPDR ETFs
        XCTAssertEqual(StateStreetETFs.symbols.count, 69)
    }

    func testFirstSymbol_isSPY() {
        XCTAssertEqual(StateStreetETFs.symbols.first, "SPY")
    }

    func testContainsKeyETFs() {
        let symbols = Set(StateStreetETFs.symbols)
        XCTAssertTrue(symbols.contains("SPY"))
        XCTAssertTrue(symbols.contains("GLD"))
        XCTAssertTrue(symbols.contains("XLK"))
        XCTAssertTrue(symbols.contains("XLF"))
        XCTAssertTrue(symbols.contains("DIA"))
    }

    func testNoDuplicates() {
        let unique = Set(StateStreetETFs.symbols)
        XCTAssertEqual(unique.count, StateStreetETFs.symbols.count)
    }
}
