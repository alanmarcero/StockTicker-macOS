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

    // MARK: - Equatable tests

    func testEquatable_sameErrors_areEqual() {
        XCTAssertEqual(SymbolAddError.empty, SymbolAddError.empty)
        XCTAssertEqual(SymbolAddError.listFull, SymbolAddError.listFull)
        XCTAssertEqual(SymbolAddError.duplicate, SymbolAddError.duplicate)
        XCTAssertEqual(
            SymbolAddError.notFound(symbol: "ABC"),
            SymbolAddError.notFound(symbol: "ABC")
        )
    }

    func testEquatable_differentErrors_areNotEqual() {
        XCTAssertNotEqual(SymbolAddError.empty, SymbolAddError.listFull)
        XCTAssertNotEqual(SymbolAddError.listFull, SymbolAddError.duplicate)
        XCTAssertNotEqual(
            SymbolAddError.notFound(symbol: "ABC"),
            SymbolAddError.notFound(symbol: "XYZ")
        )
    }
}

final class SymbolAddResultTests: XCTestCase {

    // MARK: - Equatable tests

    func testEquatable_canAdd_sameNormalized_areEqual() {
        XCTAssertEqual(
            SymbolAddResult.canAdd(normalized: "AAPL"),
            SymbolAddResult.canAdd(normalized: "AAPL")
        )
    }

    func testEquatable_canAdd_differentNormalized_areNotEqual() {
        XCTAssertNotEqual(
            SymbolAddResult.canAdd(normalized: "AAPL"),
            SymbolAddResult.canAdd(normalized: "SPY")
        )
    }

    func testEquatable_invalid_sameReason_areEqual() {
        XCTAssertEqual(
            SymbolAddResult.invalid(reason: .duplicate),
            SymbolAddResult.invalid(reason: .duplicate)
        )
    }

    func testEquatable_invalid_differentReason_areNotEqual() {
        XCTAssertNotEqual(
            SymbolAddResult.invalid(reason: .duplicate),
            SymbolAddResult.invalid(reason: .empty)
        )
    }

    func testEquatable_canAddAndInvalid_areNotEqual() {
        XCTAssertNotEqual(
            SymbolAddResult.canAdd(normalized: "AAPL"),
            SymbolAddResult.invalid(reason: .duplicate)
        )
    }
}
