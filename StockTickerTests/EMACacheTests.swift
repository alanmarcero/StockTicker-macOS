import XCTest
@testable import StockTicker

// MARK: - EMA Cache Tests

final class EMACacheTests: XCTestCase {

    private let testCacheDirectory = URL(fileURLWithPath: "/tmp/test-ema")
    private let testCacheFile = "/tmp/test-ema/ema-cache.json"

    // MARK: - Load Tests

    func testLoad_whenCacheDoesNotExist_cacheIsNil() async {
        let mockFS = MockFileSystem()
        let cacheManager = EMACacheManager(
            fileSystem: mockFS,
            cacheDirectory: testCacheDirectory
        )

        await cacheManager.load()

        let entry = await cacheManager.getEntry(for: "AAPL")
        XCTAssertNil(entry)
    }

    func testLoad_whenCacheExists_loadsEntries() async {
        let mockFS = MockFileSystem()

        let cacheData = EMACacheData(
            lastUpdated: "2026-02-15T12:00:00Z",
            entries: [
                "AAPL": EMACacheEntry(day: 150.0, week: 148.0, month: 145.0),
                "SPY": EMACacheEntry(day: 500.0, week: nil, month: 490.0),
            ]
        )
        let jsonData = try! JSONEncoder().encode(cacheData)
        mockFS.files[testCacheFile] = jsonData

        let cacheManager = EMACacheManager(
            fileSystem: mockFS,
            cacheDirectory: testCacheDirectory
        )

        await cacheManager.load()

        let aaplEntry = await cacheManager.getEntry(for: "AAPL")
        let spyEntry = await cacheManager.getEntry(for: "SPY")

        XCTAssertEqual(aaplEntry?.day, 150.0)
        XCTAssertEqual(aaplEntry?.week, 148.0)
        XCTAssertEqual(aaplEntry?.month, 145.0)
        XCTAssertEqual(spyEntry?.day, 500.0)
        XCTAssertNil(spyEntry?.week)
        XCTAssertEqual(spyEntry?.month, 490.0)
    }

    // MARK: - Save Tests

    func testSave_writesCacheToFile() async {
        let mockFS = MockFileSystem()
        let cacheManager = EMACacheManager(
            fileSystem: mockFS,
            cacheDirectory: testCacheDirectory
        )

        await cacheManager.setEntry(for: "AAPL", entry: EMACacheEntry(day: 150.0, week: 148.0, month: 145.0))
        await cacheManager.save()

        let cacheURL = URL(fileURLWithPath: testCacheFile)
        XCTAssertNotNil(mockFS.writtenFiles[cacheURL])

        if let writtenData = mockFS.writtenFiles[cacheURL] {
            let decoded = try! JSONDecoder().decode(EMACacheData.self, from: writtenData)
            XCTAssertEqual(decoded.entries["AAPL"]?.day, 150.0)
            XCTAssertEqual(decoded.entries["AAPL"]?.week, 148.0)
            XCTAssertEqual(decoded.entries["AAPL"]?.month, 145.0)
        }
    }

    // MARK: - Missing Symbols Tests

    func testGetMissingSymbols_returnsSymbolsNotInCache() async {
        let mockFS = MockFileSystem()

        let cacheData = EMACacheData(
            lastUpdated: "2026-02-15T12:00:00Z",
            entries: ["AAPL": EMACacheEntry(day: 150.0, week: 148.0, month: 145.0)]
        )
        let jsonData = try! JSONEncoder().encode(cacheData)
        mockFS.files[testCacheFile] = jsonData

        let cacheManager = EMACacheManager(
            fileSystem: mockFS,
            cacheDirectory: testCacheDirectory
        )

        await cacheManager.load()

        let missing = await cacheManager.getMissingSymbols(from: ["AAPL", "SPY", "QQQ"])
        XCTAssertEqual(Set(missing), Set(["SPY", "QQQ"]))
    }

    func testGetMissingSymbols_whenCacheEmpty_returnsAllSymbols() async {
        let mockFS = MockFileSystem()
        let cacheManager = EMACacheManager(
            fileSystem: mockFS,
            cacheDirectory: testCacheDirectory
        )

        await cacheManager.load()

        let missing = await cacheManager.getMissingSymbols(from: ["AAPL", "SPY"])
        XCTAssertEqual(Set(missing), Set(["AAPL", "SPY"]))
    }

    // MARK: - Get All Entries Tests

    func testGetAllEntries_returnsAllCachedEntries() async {
        let mockFS = MockFileSystem()

        let cacheData = EMACacheData(
            lastUpdated: "2026-02-15T12:00:00Z",
            entries: [
                "AAPL": EMACacheEntry(day: 150.0, week: 148.0, month: 145.0),
                "SPY": EMACacheEntry(day: 500.0, week: 495.0, month: 490.0),
            ]
        )
        let jsonData = try! JSONEncoder().encode(cacheData)
        mockFS.files[testCacheFile] = jsonData

        let cacheManager = EMACacheManager(
            fileSystem: mockFS,
            cacheDirectory: testCacheDirectory
        )

        await cacheManager.load()

        let allEntries = await cacheManager.getAllEntries()
        XCTAssertEqual(allEntries.count, 2)
        XCTAssertEqual(allEntries["AAPL"]?.day, 150.0)
        XCTAssertEqual(allEntries["SPY"]?.day, 500.0)
    }

    // MARK: - Needs Daily Refresh Tests

    func testNeedsDailyRefresh_whenCacheIsNil_returnsTrue() async {
        let mockFS = MockFileSystem()
        let cacheManager = EMACacheManager(
            fileSystem: mockFS,
            cacheDirectory: testCacheDirectory
        )

        await cacheManager.load()

        let needsRefresh = await cacheManager.needsDailyRefresh()
        XCTAssertTrue(needsRefresh)
    }

    func testNeedsDailyRefresh_sameDay_returnsFalse() async {
        let mockFS = MockFileSystem()
        let mockDateProvider = MockDateProvider(year: 2026, month: 2, day: 15, hour: 14)

        let todayString = ISO8601DateFormatter().string(from: mockDateProvider.now())
        let cacheData = EMACacheData(
            lastUpdated: todayString,
            entries: ["AAPL": EMACacheEntry(day: 150.0, week: 148.0, month: 145.0)]
        )
        let jsonData = try! JSONEncoder().encode(cacheData)
        mockFS.files[testCacheFile] = jsonData

        let cacheManager = EMACacheManager(
            fileSystem: mockFS,
            dateProvider: mockDateProvider,
            cacheDirectory: testCacheDirectory
        )

        await cacheManager.load()

        let needsRefresh = await cacheManager.needsDailyRefresh()
        XCTAssertFalse(needsRefresh)
    }

    func testNeedsDailyRefresh_differentDay_returnsTrue() async {
        let mockFS = MockFileSystem()
        let mockDateProvider = MockDateProvider(year: 2026, month: 2, day: 16)

        let yesterdayProvider = MockDateProvider(year: 2026, month: 2, day: 15)
        let yesterdayString = ISO8601DateFormatter().string(from: yesterdayProvider.now())
        let cacheData = EMACacheData(
            lastUpdated: yesterdayString,
            entries: ["AAPL": EMACacheEntry(day: 150.0, week: 148.0, month: 145.0)]
        )
        let jsonData = try! JSONEncoder().encode(cacheData)
        mockFS.files[testCacheFile] = jsonData

        let cacheManager = EMACacheManager(
            fileSystem: mockFS,
            dateProvider: mockDateProvider,
            cacheDirectory: testCacheDirectory
        )

        await cacheManager.load()

        let needsRefresh = await cacheManager.needsDailyRefresh()
        XCTAssertTrue(needsRefresh)
    }

    // MARK: - Clear For Daily Refresh Tests

    func testClearForDailyRefresh_emptiesEntries() async {
        let mockFS = MockFileSystem()

        let cacheData = EMACacheData(
            lastUpdated: "2026-02-15T12:00:00Z",
            entries: [
                "AAPL": EMACacheEntry(day: 150.0, week: 148.0, month: 145.0),
                "SPY": EMACacheEntry(day: 500.0, week: 495.0, month: 490.0),
            ]
        )
        let jsonData = try! JSONEncoder().encode(cacheData)
        mockFS.files[testCacheFile] = jsonData

        let cacheManager = EMACacheManager(
            fileSystem: mockFS,
            cacheDirectory: testCacheDirectory
        )

        await cacheManager.load()
        await cacheManager.clearForDailyRefresh()

        let allEntries = await cacheManager.getAllEntries()
        XCTAssertTrue(allEntries.isEmpty)

        await cacheManager.save()

        let cacheURL = URL(fileURLWithPath: testCacheFile)
        if let writtenData = mockFS.writtenFiles[cacheURL] {
            let decoded = try! JSONDecoder().decode(EMACacheData.self, from: writtenData)
            XCTAssertTrue(decoded.entries.isEmpty)
            XCTAssertEqual(decoded.lastUpdated, "")
        } else {
            XCTFail("Cache was not written")
        }
    }

    // MARK: - Nil Entry Values Tests

    func testSetEntry_withNilValues_storesCorrectly() async {
        let mockFS = MockFileSystem()
        let cacheManager = EMACacheManager(
            fileSystem: mockFS,
            cacheDirectory: testCacheDirectory
        )

        await cacheManager.setEntry(for: "BTC-USD", entry: EMACacheEntry(day: nil, week: nil, month: nil))
        await cacheManager.save()

        let entry = await cacheManager.getEntry(for: "BTC-USD")
        XCTAssertNotNil(entry)
        XCTAssertNil(entry?.day)
        XCTAssertNil(entry?.week)
        XCTAssertNil(entry?.month)
    }
}
