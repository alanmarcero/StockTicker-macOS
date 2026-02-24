import XCTest
@testable import StockTicker

final class SymbolAddErrorTests: XCTestCase {

    // MARK: - Error message tests

    func testEmptyError_hasCorrectMessage() {
        let error = SymbolAddError.empty
        XCTAssertEqual(error.message, "Please enter a symbol")
    }

    func testListFullError_hasCorrectMessage() {
        let error = SymbolAddError.listFull
        XCTAssertEqual(error.message, "Maximum \(LayoutConfig.Watchlist.maxSize) symbols allowed")
    }

    func testDuplicateError_hasCorrectMessage() {
        let error = SymbolAddError.duplicate
        XCTAssertEqual(error.message, "Symbol already in watchlist")
    }

    func testNotFoundError_includesSymbolInMessage() {
        let error = SymbolAddError.notFound(symbol: "INVALID")
        XCTAssertEqual(error.message, "Invalid symbol: INVALID not found")
    }

    func testNotFoundError_differentSymbols() {
        let error1 = SymbolAddError.notFound(symbol: "ABC")
        let error2 = SymbolAddError.notFound(symbol: "XYZ")
        XCTAssertEqual(error1.message, "Invalid symbol: ABC not found")
        XCTAssertEqual(error2.message, "Invalid symbol: XYZ not found")
    }

}
