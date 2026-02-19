import XCTest
@testable import StockTicker

final class ThrottledTaskGroupTests: XCTestCase {

    func testMap_emptyItems_returnsEmptyDict() async {
        let result = await ThrottledTaskGroup.map(items: [String]()) { _ in
            return 1
        }

        XCTAssertTrue(result.isEmpty)
    }

    func testMap_allSucceed_returnsAllResults() async {
        let items = ["A", "B", "C", "D", "E"]
        let result = await ThrottledTaskGroup.map(items: items) { item in
            return item.lowercased()
        }

        XCTAssertEqual(result.count, 5)
        XCTAssertEqual(result["A"], "a")
        XCTAssertEqual(result["B"], "b")
        XCTAssertEqual(result["C"], "c")
        XCTAssertEqual(result["D"], "d")
        XCTAssertEqual(result["E"], "e")
    }

    func testMap_someReturnNil_excludedFromResults() async {
        let items = ["A", "B", "C"]
        let result = await ThrottledTaskGroup.map(items: items) { item -> String? in
            return item == "B" ? nil : item.lowercased()
        }

        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result["A"], "a")
        XCTAssertNil(result["B"])
        XCTAssertEqual(result["C"], "c")
    }

    func testMap_respectsMaxConcurrency() async {
        let concurrentCount = ManagedAtomic(0)
        let maxObserved = ManagedAtomic(0)
        let items = (1...50).map { "item-\($0)" }

        _ = await ThrottledTaskGroup.map(items: items, maxConcurrency: 5) { _ -> Int? in
            let current = concurrentCount.add(1)
            maxObserved.max(current)
            try? await Task.sleep(nanoseconds: 1_000_000) // 1ms
            concurrentCount.add(-1)
            return 1
        }

        XCTAssertLessThanOrEqual(maxObserved.value, 5)
    }

    func testMap_singleItem_returnsResult() async {
        let result = await ThrottledTaskGroup.map(items: ["only"]) { item in
            return 42
        }

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result["only"], 42)
    }

    func testMap_moreThanMaxConcurrency_processesAll() async {
        let items = (1...100).map { "s\($0)" }
        let result = await ThrottledTaskGroup.map(items: items, maxConcurrency: 3) { item in
            return item
        }

        XCTAssertEqual(result.count, 100)
    }

    func testMap_customDelayParameter_accepted() async {
        let items = ["A", "B", "C"]
        let result = await ThrottledTaskGroup.map(items: items, delay: 1_000) { item in
            return item.lowercased()
        }

        XCTAssertEqual(result.count, 3)
        XCTAssertEqual(result["A"], "a")
    }

    func testBackfillConstants_accessible() {
        XCTAssertEqual(ThrottledTaskGroup.Backfill.maxConcurrency, 1)
        XCTAssertEqual(ThrottledTaskGroup.Backfill.delayNanoseconds, 2_000_000_000)
    }
}

// Simple thread-safe atomic counter for testing
private final class ManagedAtomic: @unchecked Sendable {
    private var _value: Int
    private let lock = NSLock()

    var value: Int {
        lock.lock()
        defer { lock.unlock() }
        return _value
    }

    init(_ initial: Int) {
        _value = initial
    }

    @discardableResult
    func add(_ delta: Int) -> Int {
        lock.lock()
        defer { lock.unlock() }
        _value += delta
        return _value
    }

    func max(_ candidate: Int) {
        lock.lock()
        defer { lock.unlock() }
        if candidate > _value { _value = candidate }
    }
}
