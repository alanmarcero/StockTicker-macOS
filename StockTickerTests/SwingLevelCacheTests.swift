import XCTest
@testable import StockTicker

// MARK: - Swing Level Cache Tests

final class SwingLevelCacheTests: XCTestCase {

    private let testCacheDirectory = URL(fileURLWithPath: "/tmp/test-swing-level")
    private let testCacheFile = "/tmp/test-swing-level/swing-level-cache.json"

    // MARK: - Load Tests

    func testLoad_whenCacheDoesNotExist_cacheIsNil() async {
        let mockFS = MockFileSystem()
        let cacheManager = SwingLevelCacheManager(
            fileSystem: mockFS,
            cacheDirectory: testCacheDirectory
        )

        await cacheManager.load()

        let entry = await cacheManager.getEntry(for: "AAPL")
        XCTAssertNil(entry)
    }

    func testLoad_whenCacheExists_loadsEntries() async {
        let mockFS = MockFileSystem()

        let cacheData = SwingLevelCacheData(
            quarterRange: "Q1-2023:Q4-2025",
            lastUpdated: "2026-02-15T12:00:00Z",
            entries: [
                "AAPL": SwingLevelCacheEntry(breakoutPrice: 200.0, breakoutDate: "1/15/25", breakdownPrice: 120.0, breakdownDate: "6/10/24"),
                "SPY": SwingLevelCacheEntry(breakoutPrice: 500.0, breakoutDate: "3/20/25", breakdownPrice: nil, breakdownDate: nil)
            ]
        )
        let jsonData = try! JSONEncoder().encode(cacheData)
        mockFS.files[testCacheFile] = jsonData

        let cacheManager = SwingLevelCacheManager(
            fileSystem: mockFS,
            cacheDirectory: testCacheDirectory
        )

        await cacheManager.load()

        let aaplEntry = await cacheManager.getEntry(for: "AAPL")
        XCTAssertEqual(aaplEntry?.breakoutPrice, 200.0)
        XCTAssertEqual(aaplEntry?.breakdownPrice, 120.0)

        let spyEntry = await cacheManager.getEntry(for: "SPY")
        XCTAssertEqual(spyEntry?.breakoutPrice, 500.0)
        XCTAssertNil(spyEntry?.breakdownPrice)
    }

    // MARK: - Save Tests

    func testSave_writesCacheToFile() async {
        let mockFS = MockFileSystem()
        let cacheManager = SwingLevelCacheManager(
            fileSystem: mockFS,
            cacheDirectory: testCacheDirectory
        )

        await cacheManager.clearForNewRange("Q1-2023:Q4-2025")
        await cacheManager.setEntry(for: "AAPL", entry: SwingLevelCacheEntry(breakoutPrice: 200.0, breakoutDate: "1/15/25", breakdownPrice: 120.0, breakdownDate: "6/10/24"))
        await cacheManager.save()

        let cacheURL = URL(fileURLWithPath: testCacheFile)
        XCTAssertNotNil(mockFS.writtenFiles[cacheURL])

        if let writtenData = mockFS.writtenFiles[cacheURL] {
            let decoded = try! JSONDecoder().decode(SwingLevelCacheData.self, from: writtenData)
            XCTAssertEqual(decoded.entries["AAPL"]?.breakoutPrice, 200.0)
            XCTAssertEqual(decoded.entries["AAPL"]?.breakdownPrice, 120.0)
            XCTAssertEqual(decoded.quarterRange, "Q1-2023:Q4-2025")
        }
    }

    // MARK: - Needs Invalidation Tests

    func testNeedsInvalidation_whenCacheIsNil_returnsTrue() async {
        let mockFS = MockFileSystem()
        let cacheManager = SwingLevelCacheManager(
            fileSystem: mockFS,
            cacheDirectory: testCacheDirectory
        )

        await cacheManager.load()

        let needsInvalidation = await cacheManager.needsInvalidation(currentRange: "Q1-2023:Q4-2025")
        XCTAssertTrue(needsInvalidation)
    }

    func testNeedsInvalidation_whenRangeMatches_returnsFalse() async {
        let mockFS = MockFileSystem()

        let cacheData = SwingLevelCacheData(
            quarterRange: "Q1-2023:Q4-2025",
            lastUpdated: "2026-02-15T12:00:00Z",
            entries: ["AAPL": SwingLevelCacheEntry(breakoutPrice: 200.0, breakoutDate: "1/15/25", breakdownPrice: nil, breakdownDate: nil)]
        )
        let jsonData = try! JSONEncoder().encode(cacheData)
        mockFS.files[testCacheFile] = jsonData

        let cacheManager = SwingLevelCacheManager(
            fileSystem: mockFS,
            cacheDirectory: testCacheDirectory
        )

        await cacheManager.load()

        let needsInvalidation = await cacheManager.needsInvalidation(currentRange: "Q1-2023:Q4-2025")
        XCTAssertFalse(needsInvalidation)
    }

    func testNeedsInvalidation_whenRangeDiffers_returnsTrue() async {
        let mockFS = MockFileSystem()

        let cacheData = SwingLevelCacheData(
            quarterRange: "Q1-2022:Q4-2024",
            lastUpdated: "2025-12-15T12:00:00Z",
            entries: ["AAPL": SwingLevelCacheEntry(breakoutPrice: 200.0, breakoutDate: "1/15/25", breakdownPrice: nil, breakdownDate: nil)]
        )
        let jsonData = try! JSONEncoder().encode(cacheData)
        mockFS.files[testCacheFile] = jsonData

        let cacheManager = SwingLevelCacheManager(
            fileSystem: mockFS,
            cacheDirectory: testCacheDirectory
        )

        await cacheManager.load()

        let needsInvalidation = await cacheManager.needsInvalidation(currentRange: "Q1-2023:Q4-2025")
        XCTAssertTrue(needsInvalidation)
    }

    // MARK: - Clear For New Range Tests

    func testClearForNewRange_resetsCache() async {
        let mockFS = MockFileSystem()
        let mockDateProvider = MockDateProvider(year: 2026, month: 2, day: 15)

        let cacheData = SwingLevelCacheData(
            quarterRange: "Q1-2022:Q4-2024",
            lastUpdated: "2025-12-15T12:00:00Z",
            entries: [
                "AAPL": SwingLevelCacheEntry(breakoutPrice: 200.0, breakoutDate: "1/15/25", breakdownPrice: 120.0, breakdownDate: "6/10/24"),
                "SPY": SwingLevelCacheEntry(breakoutPrice: 500.0, breakoutDate: "3/20/25", breakdownPrice: nil, breakdownDate: nil)
            ]
        )
        let jsonData = try! JSONEncoder().encode(cacheData)
        mockFS.files[testCacheFile] = jsonData

        let cacheManager = SwingLevelCacheManager(
            fileSystem: mockFS,
            dateProvider: mockDateProvider,
            cacheDirectory: testCacheDirectory
        )

        await cacheManager.load()
        await cacheManager.clearForNewRange("Q1-2023:Q4-2025")

        let entry = await cacheManager.getEntry(for: "AAPL")
        XCTAssertNil(entry)

        let allEntries = await cacheManager.getAllEntries()
        XCTAssertTrue(allEntries.isEmpty)

        let needsInvalidation = await cacheManager.needsInvalidation(currentRange: "Q1-2023:Q4-2025")
        XCTAssertFalse(needsInvalidation)
    }

    // MARK: - Missing Symbols Tests

    func testGetMissingSymbols_returnsSymbolsNotInCache() async {
        let mockFS = MockFileSystem()

        let cacheData = SwingLevelCacheData(
            quarterRange: "Q1-2023:Q4-2025",
            lastUpdated: "2026-02-15T12:00:00Z",
            entries: ["AAPL": SwingLevelCacheEntry(breakoutPrice: 200.0, breakoutDate: "1/15/25", breakdownPrice: nil, breakdownDate: nil)]
        )
        let jsonData = try! JSONEncoder().encode(cacheData)
        mockFS.files[testCacheFile] = jsonData

        let cacheManager = SwingLevelCacheManager(
            fileSystem: mockFS,
            cacheDirectory: testCacheDirectory
        )

        await cacheManager.load()

        let missing = await cacheManager.getMissingSymbols(from: ["AAPL", "SPY", "QQQ"])
        XCTAssertEqual(Set(missing), Set(["SPY", "QQQ"]))
    }

    func testGetMissingSymbols_whenCacheEmpty_returnsAllSymbols() async {
        let mockFS = MockFileSystem()
        let cacheManager = SwingLevelCacheManager(
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

        let cacheData = SwingLevelCacheData(
            quarterRange: "Q1-2023:Q4-2025",
            lastUpdated: "2026-02-15T12:00:00Z",
            entries: [
                "AAPL": SwingLevelCacheEntry(breakoutPrice: 200.0, breakoutDate: "1/15/25", breakdownPrice: 120.0, breakdownDate: "6/10/24"),
                "SPY": SwingLevelCacheEntry(breakoutPrice: 500.0, breakoutDate: "3/20/25", breakdownPrice: nil, breakdownDate: nil)
            ]
        )
        let jsonData = try! JSONEncoder().encode(cacheData)
        mockFS.files[testCacheFile] = jsonData

        let cacheManager = SwingLevelCacheManager(
            fileSystem: mockFS,
            cacheDirectory: testCacheDirectory
        )

        await cacheManager.load()

        let allEntries = await cacheManager.getAllEntries()
        XCTAssertEqual(allEntries.count, 2)
        XCTAssertEqual(allEntries["AAPL"]?.breakoutPrice, 200.0)
        XCTAssertEqual(allEntries["SPY"]?.breakoutPrice, 500.0)
    }

    // MARK: - Needs Daily Refresh Tests

    func testNeedsDailyRefresh_whenCacheIsNil_returnsTrue() async {
        let mockFS = MockFileSystem()
        let cacheManager = SwingLevelCacheManager(
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
        let cacheData = SwingLevelCacheData(
            quarterRange: "Q1-2023:Q4-2025",
            lastUpdated: todayString,
            entries: ["AAPL": SwingLevelCacheEntry(breakoutPrice: 200.0, breakoutDate: "1/15/25", breakdownPrice: nil, breakdownDate: nil)]
        )
        let jsonData = try! JSONEncoder().encode(cacheData)
        mockFS.files[testCacheFile] = jsonData

        let cacheManager = SwingLevelCacheManager(
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
        let cacheData = SwingLevelCacheData(
            quarterRange: "Q1-2023:Q4-2025",
            lastUpdated: yesterdayString,
            entries: ["AAPL": SwingLevelCacheEntry(breakoutPrice: 200.0, breakoutDate: "1/15/25", breakdownPrice: nil, breakdownDate: nil)]
        )
        let jsonData = try! JSONEncoder().encode(cacheData)
        mockFS.files[testCacheFile] = jsonData

        let cacheManager = SwingLevelCacheManager(
            fileSystem: mockFS,
            dateProvider: mockDateProvider,
            cacheDirectory: testCacheDirectory
        )

        await cacheManager.load()

        let needsRefresh = await cacheManager.needsDailyRefresh()
        XCTAssertTrue(needsRefresh)
    }

    // MARK: - Clear Entries For Daily Refresh Tests

    func testClearEntriesForDailyRefresh_emptiesEntriesKeepsQuarterRange() async {
        let mockFS = MockFileSystem()

        let cacheData = SwingLevelCacheData(
            quarterRange: "Q1-2023:Q4-2025",
            lastUpdated: "2026-02-15T12:00:00Z",
            entries: [
                "AAPL": SwingLevelCacheEntry(breakoutPrice: 200.0, breakoutDate: "1/15/25", breakdownPrice: 120.0, breakdownDate: "6/10/24"),
                "SPY": SwingLevelCacheEntry(breakoutPrice: 500.0, breakoutDate: "3/20/25", breakdownPrice: nil, breakdownDate: nil)
            ]
        )
        let jsonData = try! JSONEncoder().encode(cacheData)
        mockFS.files[testCacheFile] = jsonData

        let cacheManager = SwingLevelCacheManager(
            fileSystem: mockFS,
            cacheDirectory: testCacheDirectory
        )

        await cacheManager.load()
        await cacheManager.clearEntriesForDailyRefresh()

        let allEntries = await cacheManager.getAllEntries()
        XCTAssertTrue(allEntries.isEmpty)

        let needsInvalidation = await cacheManager.needsInvalidation(currentRange: "Q1-2023:Q4-2025")
        XCTAssertFalse(needsInvalidation)

        await cacheManager.save()

        let cacheURL = URL(fileURLWithPath: testCacheFile)
        if let writtenData = mockFS.writtenFiles[cacheURL] {
            let decoded = try! JSONDecoder().decode(SwingLevelCacheData.self, from: writtenData)
            XCTAssertEqual(decoded.quarterRange, "Q1-2023:Q4-2025")
            XCTAssertTrue(decoded.entries.isEmpty)
            XCTAssertEqual(decoded.lastUpdated, "")
        } else {
            XCTFail("Cache was not written")
        }
    }

    // MARK: - Set Entry with Nil Values

    func testSetEntry_withNilValues_storesCorrectly() async {
        let mockFS = MockFileSystem()
        let cacheManager = SwingLevelCacheManager(
            fileSystem: mockFS,
            cacheDirectory: testCacheDirectory
        )

        await cacheManager.clearForNewRange("Q1-2023:Q4-2025")
        await cacheManager.setEntry(for: "BTC-USD", entry: SwingLevelCacheEntry(breakoutPrice: nil, breakoutDate: nil, breakdownPrice: nil, breakdownDate: nil))

        let entry = await cacheManager.getEntry(for: "BTC-USD")
        XCTAssertNotNil(entry)
        XCTAssertNil(entry?.breakoutPrice)
        XCTAssertNil(entry?.breakdownPrice)

        // Symbol should not be considered missing since it has an entry
        let missing = await cacheManager.getMissingSymbols(from: ["BTC-USD"])
        XCTAssertTrue(missing.isEmpty)
    }
}
