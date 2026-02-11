import XCTest
@testable import StockTicker

// MARK: - Mock Validator

struct MockSymbolValidator: SymbolValidator {
    var validSymbols: Set<String>
    var delay: TimeInterval

    init(validSymbols: Set<String> = ["AAPL", "SPY", "QQQ", "MSFT", "GOOGL"], delay: TimeInterval = 0) {
        self.validSymbols = validSymbols
        self.delay = delay
    }

    func validate(_ symbol: String) async -> Bool {
        if delay > 0 {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
        return validSymbols.contains(symbol.uppercased())
    }
}

struct AlwaysValidValidator: SymbolValidator {
    func validate(_ symbol: String) async -> Bool {
        return true
    }
}

struct AlwaysInvalidValidator: SymbolValidator {
    func validate(_ symbol: String) async -> Bool {
        return false
    }
}

// MARK: - WatchlistEditorState Tests

@MainActor
final class WatchlistEditorStateTests: XCTestCase {

    // MARK: - Initialization tests

    func testInit_sortsSymbols() {
        let state = WatchlistEditorState(symbols: ["QQQ", "AAPL", "SPY"])
        XCTAssertEqual(state.symbols, ["AAPL", "QQQ", "SPY"])
    }

    func testInit_preservesOriginalSymbols() {
        let state = WatchlistEditorState(symbols: ["QQQ", "AAPL", "SPY"])
        XCTAssertEqual(state.originalSymbols, ["QQQ", "AAPL", "SPY"])
    }

    func testInit_emptySymbols() {
        let state = WatchlistEditorState(symbols: [])
        XCTAssertEqual(state.symbols, [])
        XCTAssertEqual(state.originalSymbols, [])
    }

    func testInit_defaultState() {
        let state = WatchlistEditorState(symbols: ["SPY"])
        XCTAssertEqual(state.newSymbol, "")
        XCTAssertFalse(state.isValidating)
        XCTAssertNil(state.validationError)
        XCTAssertTrue(state.isSortAscending)
    }

    // MARK: - hasChanges tests

    func testHasChanges_noChanges_returnsFalse() {
        let state = WatchlistEditorState(symbols: ["SPY", "QQQ"])
        XCTAssertFalse(state.hasChanges)
    }

    func testHasChanges_symbolAdded_returnsTrue() {
        let state = WatchlistEditorState(symbols: ["SPY", "QQQ"])
        state.symbols.append("AAPL")
        XCTAssertTrue(state.hasChanges)
    }

    func testHasChanges_symbolRemoved_returnsTrue() {
        let state = WatchlistEditorState(symbols: ["SPY", "QQQ"])
        state.symbols.removeAll { $0 == "SPY" }
        XCTAssertTrue(state.hasChanges)
    }

    func testHasChanges_orderChanged_returnsFalse() {
        let state = WatchlistEditorState(symbols: ["SPY", "QQQ"])
        state.symbols = ["QQQ", "SPY"]
        XCTAssertFalse(state.hasChanges)
    }

    // MARK: - removeSymbol tests

    func testRemoveSymbol_removesTicker() {
        let state = WatchlistEditorState(symbols: ["SPY", "QQQ", "AAPL"])
        state.removeSymbol("QQQ")
        XCTAssertEqual(state.symbols, ["AAPL", "SPY"])
    }

    func testRemoveSymbol_tickerNotInList_noChange() {
        let state = WatchlistEditorState(symbols: ["SPY", "QQQ"])
        state.removeSymbol("AAPL")
        XCTAssertEqual(state.symbols, ["QQQ", "SPY"])
    }

    // MARK: - sortSymbolsAscending tests

    func testSortSymbolsAscending_sortsCorrectly() {
        let state = WatchlistEditorState(symbols: ["SPY", "AAPL", "QQQ"])
        state.symbols = ["SPY", "AAPL", "QQQ"]  // Unsort for test
        state.sortSymbolsAscending()
        XCTAssertEqual(state.symbols, ["AAPL", "QQQ", "SPY"])
        XCTAssertTrue(state.isSortAscending)
    }

    // MARK: - sortSymbolsDescending tests

    func testSortSymbolsDescending_sortsCorrectly() {
        let state = WatchlistEditorState(symbols: ["AAPL", "QQQ", "SPY"])
        state.sortSymbolsDescending()
        XCTAssertEqual(state.symbols, ["SPY", "QQQ", "AAPL"])
        XCTAssertFalse(state.isSortAscending)
    }

    // MARK: - validateAndAddSymbol tests (synchronous validation errors)

    func testValidateAndAddSymbol_emptyInput_setsError() {
        let state = WatchlistEditorState(symbols: [], validator: MockSymbolValidator())
        state.newSymbol = ""
        state.validateAndAddSymbol()
        XCTAssertEqual(state.validationError, "Please enter a symbol")
    }

    func testValidateAndAddSymbol_whitespaceOnly_setsError() {
        let state = WatchlistEditorState(symbols: [], validator: MockSymbolValidator())
        state.newSymbol = "   "
        state.validateAndAddSymbol()
        XCTAssertEqual(state.validationError, "Please enter a symbol")
    }

    func testValidateAndAddSymbol_duplicate_setsError() {
        let state = WatchlistEditorState(symbols: ["SPY", "QQQ"], validator: MockSymbolValidator())
        state.newSymbol = "SPY"
        state.validateAndAddSymbol()
        XCTAssertEqual(state.validationError, "Symbol already in watchlist")
    }

    func testValidateAndAddSymbol_duplicateCaseInsensitive_setsError() {
        let state = WatchlistEditorState(symbols: ["SPY", "QQQ"], validator: MockSymbolValidator())
        state.newSymbol = "spy"
        state.validateAndAddSymbol()
        XCTAssertEqual(state.validationError, "Symbol already in watchlist")
    }

    func testValidateAndAddSymbol_listFull_setsError() {
        let maxSize = LayoutConfig.Watchlist.maxSize
        let fullList = (1...maxSize).map { "T\($0)" }
        let state = WatchlistEditorState(symbols: fullList, validator: MockSymbolValidator())
        state.newSymbol = "NEW"
        state.validateAndAddSymbol()
        XCTAssertEqual(state.validationError, "Maximum \(maxSize) symbols allowed")
    }

    // MARK: - validateAndAddSymbol tests (async validation)

    func testValidateAndAddSymbol_validTicker_addsTicker() async throws {
        let state = WatchlistEditorState(symbols: ["SPY"], validator: AlwaysValidValidator())
        state.newSymbol = "AAPL"
        state.validateAndAddSymbol()

        // Wait for async validation
        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertTrue(state.symbols.contains("AAPL"))
        XCTAssertEqual(state.newSymbol, "")
        XCTAssertNil(state.validationError)
    }

    func testValidateAndAddSymbol_invalidTicker_setsError() async throws {
        let state = WatchlistEditorState(symbols: ["SPY"], validator: AlwaysInvalidValidator())
        state.newSymbol = "INVALID"
        state.validateAndAddSymbol()

        // Wait for async validation
        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertFalse(state.symbols.contains("INVALID"))
        XCTAssertEqual(state.validationError, "Invalid symbol: INVALID not found")
    }

    func testValidateAndAddSymbol_setsIsValidatingDuringValidation() async throws {
        let state = WatchlistEditorState(symbols: [], validator: MockSymbolValidator(delay: 0.2))
        state.newSymbol = "AAPL"

        XCTAssertFalse(state.isValidating)
        state.validateAndAddSymbol()

        // Should be validating now
        try await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertTrue(state.isValidating)

        // Wait for completion
        try await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertFalse(state.isValidating)
    }

    func testValidateAndAddSymbol_normalizesInput() async throws {
        let state = WatchlistEditorState(symbols: [], validator: AlwaysValidValidator())
        state.newSymbol = "  aapl  "
        state.validateAndAddSymbol()

        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertTrue(state.symbols.contains("AAPL"))
    }

    // MARK: - Callback tests

    func testSave_callsCallback() {
        let state = WatchlistEditorState(symbols: ["QQQ", "SPY"])
        var savedTickers: [String]?

        state.setCallbacks(
            onSave: { symbols in savedTickers = symbols },
            onCancel: { }
        )

        state.save()

        // Callback is async, wait for it
        let expectation = XCTestExpectation(description: "Save callback")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertEqual(savedTickers, ["QQQ", "SPY"])
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    func testSave_returnsSortedSymbols() {
        let state = WatchlistEditorState(symbols: ["SPY", "AAPL", "QQQ"])
        state.symbols = ["SPY", "AAPL", "QQQ"]  // Unsorted
        var savedTickers: [String]?

        state.setCallbacks(
            onSave: { symbols in savedTickers = symbols },
            onCancel: { }
        )

        state.save()

        let expectation = XCTestExpectation(description: "Save callback")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertEqual(savedTickers, ["AAPL", "QQQ", "SPY"])
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    func testCancel_callsCallback() {
        let state = WatchlistEditorState(symbols: ["SPY"])
        var cancelCalled = false

        state.setCallbacks(
            onSave: { _ in },
            onCancel: { cancelCalled = true }
        )

        state.cancel()

        XCTAssertTrue(cancelCalled)
    }

    func testSave_clearsCallbacks() {
        let state = WatchlistEditorState(symbols: ["SPY"])
        var callCount = 0

        state.setCallbacks(
            onSave: { _ in callCount += 1 },
            onCancel: { }
        )

        state.save()
        state.save()  // Second call should not invoke callback

        let expectation = XCTestExpectation(description: "Callbacks cleared")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            XCTAssertEqual(callCount, 1)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    func testClearCallbacks_preventsCallbacks() {
        let state = WatchlistEditorState(symbols: ["SPY"])
        var saveCalled = false
        var cancelCalled = false

        state.setCallbacks(
            onSave: { _ in saveCalled = true },
            onCancel: { cancelCalled = true }
        )

        state.clearCallbacks()
        state.save()
        state.cancel()

        let expectation = XCTestExpectation(description: "No callbacks")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertFalse(saveCalled)
            XCTAssertFalse(cancelCalled)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }
}
