import XCTest
@testable import StockTicker

final class DictionaryMergeTests: XCTestCase {

    // MARK: - mergeKeepingNew

    func testMergeKeepingNew_overwritesExistingKeys() {
        var dict = ["a": 1, "b": 2]
        dict.mergeKeepingNew(["b": 99, "c": 3])
        XCTAssertEqual(dict, ["a": 1, "b": 99, "c": 3])
    }

    func testMergeKeepingNew_emptyOther_noChange() {
        var dict = ["a": 1]
        dict.mergeKeepingNew([:])
        XCTAssertEqual(dict, ["a": 1])
    }

    func testMergeKeepingNew_emptyBase_copiesAll() {
        var dict: [String: Int] = [:]
        dict.mergeKeepingNew(["x": 10])
        XCTAssertEqual(dict, ["x": 10])
    }

    // MARK: - mergeKeepingExisting

    func testMergeKeepingExisting_preservesExistingKeys() {
        var dict = ["a": 1, "b": 2]
        dict.mergeKeepingExisting(["b": 99, "c": 3])
        XCTAssertEqual(dict, ["a": 1, "b": 2, "c": 3])
    }

    func testMergeKeepingExisting_emptyOther_noChange() {
        var dict = ["a": 1]
        dict.mergeKeepingExisting([:])
        XCTAssertEqual(dict, ["a": 1])
    }

    func testMergeKeepingExisting_emptyBase_copiesAll() {
        var dict: [String: Int] = [:]
        dict.mergeKeepingExisting(["x": 10])
        XCTAssertEqual(dict, ["x": 10])
    }

    // MARK: - mergingKeepingExisting

    func testMergingKeepingExisting_returnsNewDictionary() {
        let dict = ["a": 1, "b": 2]
        let result = dict.mergingKeepingExisting(["b": 99, "c": 3])
        XCTAssertEqual(result, ["a": 1, "b": 2, "c": 3])
        // Original unchanged
        XCTAssertEqual(dict, ["a": 1, "b": 2])
    }

    func testMergingKeepingExisting_emptyOther_returnsCopy() {
        let dict = ["a": 1]
        let result = dict.mergingKeepingExisting([:])
        XCTAssertEqual(result, ["a": 1])
    }

    func testMergingKeepingExisting_emptyBase_returnsOther() {
        let dict: [String: Int] = [:]
        let result = dict.mergingKeepingExisting(["x": 10])
        XCTAssertEqual(result, ["x": 10])
    }
}
