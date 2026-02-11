import XCTest
@testable import StockTicker

final class WatchlistOperationsTests: XCTestCase {

    // MARK: - normalize tests

    func testNormalize_trimsWhitespace() {
        XCTAssertEqual(WatchlistOperations.normalize("  AAPL  "), "AAPL")
    }

    func testNormalize_uppercases() {
        XCTAssertEqual(WatchlistOperations.normalize("aapl"), "AAPL")
    }

    func testNormalize_handlesEmptyString() {
        XCTAssertEqual(WatchlistOperations.normalize(""), "")
    }

    func testNormalize_handlesWhitespaceOnly() {
        XCTAssertEqual(WatchlistOperations.normalize("   "), "")
    }

    func testNormalize_combinesTrimmingAndUppercasing() {
        XCTAssertEqual(WatchlistOperations.normalize("  spy  "), "SPY")
    }

    // MARK: - canAddSymbol tests

    func testCanAddSymbol_validTicker_returnsCanAdd() {
        let result = WatchlistOperations.canAddSymbol("AAPL", to: ["SPY", "QQQ"])
        XCTAssertEqual(result, .canAdd(normalized: "AAPL"))
    }

    func testCanAddSymbol_normalizesInput() {
        let result = WatchlistOperations.canAddSymbol("  aapl  ", to: [])
        XCTAssertEqual(result, .canAdd(normalized: "AAPL"))
    }

    func testCanAddSymbol_emptyString_returnsEmpty() {
        let result = WatchlistOperations.canAddSymbol("", to: [])
        XCTAssertEqual(result, .invalid(reason: .empty))
    }

    func testCanAddSymbol_whitespaceOnly_returnsEmpty() {
        let result = WatchlistOperations.canAddSymbol("   ", to: [])
        XCTAssertEqual(result, .invalid(reason: .empty))
    }

    func testCanAddSymbol_duplicate_returnsDuplicate() {
        let result = WatchlistOperations.canAddSymbol("SPY", to: ["SPY", "QQQ"])
        XCTAssertEqual(result, .invalid(reason: .duplicate))
    }

    func testCanAddSymbol_duplicateCaseInsensitive_returnsDuplicate() {
        let result = WatchlistOperations.canAddSymbol("spy", to: ["SPY", "QQQ"])
        XCTAssertEqual(result, .invalid(reason: .duplicate))
    }

    func testCanAddSymbol_listFull_returnsListFull() {
        let maxSize = LayoutConfig.Watchlist.maxSize
        let fullList = (1...maxSize).map { "T\($0)" }
        let result = WatchlistOperations.canAddSymbol("NEW", to: fullList)
        XCTAssertEqual(result, .invalid(reason: .listFull))
    }

    func testCanAddSymbol_listAtMaxMinusOne_returnsCanAdd() {
        let maxSize = LayoutConfig.Watchlist.maxSize
        let almostFullList = (1...(maxSize - 1)).map { "T\($0)" }
        let result = WatchlistOperations.canAddSymbol("NEW", to: almostFullList)
        XCTAssertEqual(result, .canAdd(normalized: "NEW"))
    }

    // MARK: - addSymbol tests

    func testAddSymbol_appendsToList() {
        let result = WatchlistOperations.addSymbol("AAPL", to: ["SPY", "QQQ"])
        XCTAssertEqual(result, ["SPY", "QQQ", "AAPL"])
    }

    func testAddSymbol_toEmptyList() {
        let result = WatchlistOperations.addSymbol("AAPL", to: [])
        XCTAssertEqual(result, ["AAPL"])
    }

    func testAddSymbol_doesNotMutateOriginal() {
        let original = ["SPY", "QQQ"]
        _ = WatchlistOperations.addSymbol("AAPL", to: original)
        XCTAssertEqual(original, ["SPY", "QQQ"])
    }

    // MARK: - removeSymbol tests

    func testRemoveSymbol_removesFromList() {
        let result = WatchlistOperations.removeSymbol("QQQ", from: ["SPY", "QQQ", "AAPL"])
        XCTAssertEqual(result, ["SPY", "AAPL"])
    }

    func testRemoveSymbol_tickerNotInList_returnsUnchanged() {
        let result = WatchlistOperations.removeSymbol("MSFT", from: ["SPY", "QQQ"])
        XCTAssertEqual(result, ["SPY", "QQQ"])
    }

    func testRemoveSymbol_fromEmptyList_returnsEmpty() {
        let result = WatchlistOperations.removeSymbol("SPY", from: [])
        XCTAssertEqual(result, [])
    }

    func testRemoveSymbol_removesAllOccurrences() {
        let result = WatchlistOperations.removeSymbol("SPY", from: ["SPY", "QQQ", "SPY"])
        XCTAssertEqual(result, ["QQQ"])
    }

    func testRemoveSymbol_doesNotMutateOriginal() {
        let original = ["SPY", "QQQ"]
        _ = WatchlistOperations.removeSymbol("SPY", from: original)
        XCTAssertEqual(original, ["SPY", "QQQ"])
    }

    // MARK: - sortAscending tests

    func testSortAscending_sortsAlphabetically() {
        let result = WatchlistOperations.sortAscending(["QQQ", "AAPL", "SPY"])
        XCTAssertEqual(result, ["AAPL", "QQQ", "SPY"])
    }

    func testSortAscending_emptyList_returnsEmpty() {
        let result = WatchlistOperations.sortAscending([])
        XCTAssertEqual(result, [])
    }

    func testSortAscending_singleItem_returnsSame() {
        let result = WatchlistOperations.sortAscending(["SPY"])
        XCTAssertEqual(result, ["SPY"])
    }

    func testSortAscending_alreadySorted_returnsSame() {
        let result = WatchlistOperations.sortAscending(["AAPL", "QQQ", "SPY"])
        XCTAssertEqual(result, ["AAPL", "QQQ", "SPY"])
    }

    // MARK: - sortDescending tests

    func testSortDescending_sortsReverseAlphabetically() {
        let result = WatchlistOperations.sortDescending(["QQQ", "AAPL", "SPY"])
        XCTAssertEqual(result, ["SPY", "QQQ", "AAPL"])
    }

    func testSortDescending_emptyList_returnsEmpty() {
        let result = WatchlistOperations.sortDescending([])
        XCTAssertEqual(result, [])
    }

    func testSortDescending_singleItem_returnsSame() {
        let result = WatchlistOperations.sortDescending(["SPY"])
        XCTAssertEqual(result, ["SPY"])
    }

    // MARK: - hasChanges tests

    func testHasChanges_sameContent_returnsFalse() {
        let result = WatchlistOperations.hasChanges(
            current: ["SPY", "QQQ"],
            original: ["SPY", "QQQ"]
        )
        XCTAssertFalse(result)
    }

    func testHasChanges_differentOrder_returnsFalse() {
        let result = WatchlistOperations.hasChanges(
            current: ["QQQ", "SPY"],
            original: ["SPY", "QQQ"]
        )
        XCTAssertFalse(result)
    }

    func testHasChanges_addedTicker_returnsTrue() {
        let result = WatchlistOperations.hasChanges(
            current: ["SPY", "QQQ", "AAPL"],
            original: ["SPY", "QQQ"]
        )
        XCTAssertTrue(result)
    }

    func testHasChanges_removedTicker_returnsTrue() {
        let result = WatchlistOperations.hasChanges(
            current: ["SPY"],
            original: ["SPY", "QQQ"]
        )
        XCTAssertTrue(result)
    }

    func testHasChanges_replacedTicker_returnsTrue() {
        let result = WatchlistOperations.hasChanges(
            current: ["SPY", "AAPL"],
            original: ["SPY", "QQQ"]
        )
        XCTAssertTrue(result)
    }

    func testHasChanges_bothEmpty_returnsFalse() {
        let result = WatchlistOperations.hasChanges(current: [], original: [])
        XCTAssertFalse(result)
    }

    // MARK: - maxWatchlistSize constant

    func testMaxWatchlistSize_matchesWatchlistConfig() {
        XCTAssertEqual(WatchlistOperations.maxWatchlistSize, WatchlistConfig.maxWatchlistSize)
        XCTAssertEqual(WatchlistOperations.maxWatchlistSize, LayoutConfig.Watchlist.maxSize)
    }
}
