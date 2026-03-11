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
                "AAPL": EMACacheEntry(day: 150.0, week: 148.0, weekCrossoverWeeksBelow: nil, weekBelowCount: nil),
                "SPY": EMACacheEntry(day: 500.0, week: nil, weekCrossoverWeeksBelow: nil, weekBelowCount: nil),
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
        XCTAssertEqual(spyEntry?.day, 500.0)
        XCTAssertNil(spyEntry?.week)
    }

    // MARK: - Save Tests

    func testSave_writesCacheToFile() async {
        let mockFS = MockFileSystem()
        let cacheManager = EMACacheManager(
            fileSystem: mockFS,
            cacheDirectory: testCacheDirectory
        )

        await cacheManager.setEntry(for: "AAPL", entry: EMACacheEntry(day: 150.0, week: 148.0, weekCrossoverWeeksBelow: nil, weekBelowCount: nil))
        await cacheManager.save()

        let cacheURL = URL(fileURLWithPath: testCacheFile)
        XCTAssertNotNil(mockFS.writtenFiles[cacheURL])

        if let writtenData = mockFS.writtenFiles[cacheURL] {
            let decoded = try! JSONDecoder().decode(EMACacheData.self, from: writtenData)
            XCTAssertEqual(decoded.entries["AAPL"]?.day, 150.0)
            XCTAssertEqual(decoded.entries["AAPL"]?.week, 148.0)
        }
    }

    // MARK: - Missing Symbols Tests

    func testGetMissingSymbols_returnsSymbolsNotInCache() async {
        let mockFS = MockFileSystem()

        let cacheData = EMACacheData(
            lastUpdated: "2026-02-15T12:00:00Z",
            entries: ["AAPL": EMACacheEntry(day: 150.0, week: 148.0, weekCrossoverWeeksBelow: nil, weekBelowCount: nil)]
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
                "AAPL": EMACacheEntry(day: 150.0, week: 148.0, weekCrossoverWeeksBelow: nil, weekBelowCount: nil),
                "SPY": EMACacheEntry(day: 500.0, week: 495.0, weekCrossoverWeeksBelow: nil, weekBelowCount: nil),
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
            entries: ["AAPL": EMACacheEntry(day: 150.0, week: 148.0, weekCrossoverWeeksBelow: nil, weekBelowCount: nil)]
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
            entries: ["AAPL": EMACacheEntry(day: 150.0, week: 148.0, weekCrossoverWeeksBelow: nil, weekBelowCount: nil)]
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
                "AAPL": EMACacheEntry(day: 150.0, week: 148.0, weekCrossoverWeeksBelow: nil, weekBelowCount: nil),
                "SPY": EMACacheEntry(day: 500.0, week: 495.0, weekCrossoverWeeksBelow: nil, weekBelowCount: nil),
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

        await cacheManager.setEntry(for: "BTC-USD", entry: EMACacheEntry(day: nil, week: nil, weekCrossoverWeeksBelow: nil, weekBelowCount: nil))
        await cacheManager.save()

        let entry = await cacheManager.getEntry(for: "BTC-USD")
        XCTAssertNotNil(entry)
        XCTAssertNil(entry?.day)
        XCTAssertNil(entry?.week)
        XCTAssertNil(entry?.weekCrossoverWeeksBelow)
    }

    // MARK: - Crossover Field Tests

    func testSetEntry_withCrossover_storesCorrectly() async {
        let mockFS = MockFileSystem()
        let cacheManager = EMACacheManager(
            fileSystem: mockFS,
            cacheDirectory: testCacheDirectory
        )

        await cacheManager.setEntry(for: "AAPL", entry: EMACacheEntry(day: 150.0, week: 148.0, weekCrossoverWeeksBelow: 3, weekBelowCount: nil))
        await cacheManager.save()

        let cacheURL = URL(fileURLWithPath: testCacheFile)
        if let writtenData = mockFS.writtenFiles[cacheURL] {
            let decoded = try! JSONDecoder().decode(EMACacheData.self, from: writtenData)
            XCTAssertEqual(decoded.entries["AAPL"]?.weekCrossoverWeeksBelow, 3)
        } else {
            XCTFail("Cache was not written")
        }
    }

    // MARK: - Sneak Peek Refresh Tests

    func testNeedsSneakPeekRefresh_friday2PM_firstEntry_true() async {
        let mockFS = MockFileSystem()
        let et = MarketSchedule.easternTimeZone
        // Friday Feb 20 2026, 2:30 PM ET — first entry into sneak peek window
        let mockDateProvider = MockDateProvider(year: 2026, month: 2, day: 20, hour: 14, minute: 30, timeZone: et)

        let cacheTimeProvider = MockDateProvider(year: 2026, month: 2, day: 20, hour: 10, minute: 0, timeZone: et)
        let cacheTimestamp = ISO8601DateFormatter().string(from: cacheTimeProvider.now())

        let cacheData = EMACacheData(
            lastUpdated: cacheTimestamp,
            entries: ["AAPL": EMACacheEntry(day: 150.0, week: 148.0, weekCrossoverWeeksBelow: nil, weekBelowCount: nil)]
        )
        let jsonData = try! JSONEncoder().encode(cacheData)
        mockFS.files[testCacheFile] = jsonData

        let cacheManager = EMACacheManager(
            fileSystem: mockFS,
            dateProvider: mockDateProvider,
            cacheDirectory: testCacheDirectory
        )
        await cacheManager.load()

        let needs = await cacheManager.needsSneakPeekRefresh()
        XCTAssertTrue(needs)
    }

    func testNeedsSneakPeekRefresh_friday2PM_firstEntry_ignoresRecentCacheUpdate_true() async {
        let mockFS = MockFileSystem()
        let et = MarketSchedule.easternTimeZone
        // Friday Feb 20 2026, 2:01 PM ET — cache was updated 1 minute ago by backfill
        let mockDateProvider = MockDateProvider(year: 2026, month: 2, day: 20, hour: 14, minute: 1, timeZone: et)

        // Cache updated at 2:00 PM ET (backfill just wrote an entry)
        let cacheTimeProvider = MockDateProvider(year: 2026, month: 2, day: 20, hour: 14, minute: 0, timeZone: et)
        let cacheTimestamp = ISO8601DateFormatter().string(from: cacheTimeProvider.now())

        let cacheData = EMACacheData(
            lastUpdated: cacheTimestamp,
            entries: ["AAPL": EMACacheEntry(day: 150.0, week: 148.0, weekCrossoverWeeksBelow: nil, weekBelowCount: nil)]
        )
        let jsonData = try! JSONEncoder().encode(cacheData)
        mockFS.files[testCacheFile] = jsonData

        let cacheManager = EMACacheManager(
            fileSystem: mockFS,
            dateProvider: mockDateProvider,
            cacheDirectory: testCacheDirectory
        )
        await cacheManager.load()

        // First entry should trigger regardless of cache.lastUpdated
        let needs = await cacheManager.needsSneakPeekRefresh()
        XCTAssertTrue(needs)
    }

    func testNeedsSneakPeekRefresh_afterMarkDone_withinFiveMinutes_false() async {
        let mockFS = MockFileSystem()
        let et = MarketSchedule.easternTimeZone
        let mockDateProvider = MockDateProvider(year: 2026, month: 2, day: 20, hour: 14, minute: 0, timeZone: et)

        let cacheTimestamp = ISO8601DateFormatter().string(from: mockDateProvider.now())
        let cacheData = EMACacheData(
            lastUpdated: cacheTimestamp,
            entries: ["AAPL": EMACacheEntry(day: 150.0, week: 148.0, weekCrossoverWeeksBelow: nil, weekBelowCount: nil)]
        )
        let jsonData = try! JSONEncoder().encode(cacheData)
        mockFS.files[testCacheFile] = jsonData

        let cacheManager = EMACacheManager(
            fileSystem: mockFS,
            dateProvider: mockDateProvider,
            cacheDirectory: testCacheDirectory
        )
        await cacheManager.load()

        // Simulate sneak peek was done at 2:00 PM
        await cacheManager.markSneakPeekDone()

        // Advance to 2:03 PM (3 minutes later — within 5-minute interval)
        mockDateProvider.currentDate = MockDateProvider(year: 2026, month: 2, day: 20, hour: 14, minute: 3, timeZone: et).now()

        let needs = await cacheManager.needsSneakPeekRefresh()
        XCTAssertFalse(needs)
    }

    func testNeedsSneakPeekRefresh_afterMarkDone_afterFiveMinutes_true() async {
        let mockFS = MockFileSystem()
        let et = MarketSchedule.easternTimeZone
        let mockDateProvider = MockDateProvider(year: 2026, month: 2, day: 20, hour: 14, minute: 0, timeZone: et)

        let cacheTimestamp = ISO8601DateFormatter().string(from: mockDateProvider.now())
        let cacheData = EMACacheData(
            lastUpdated: cacheTimestamp,
            entries: ["AAPL": EMACacheEntry(day: 150.0, week: 148.0, weekCrossoverWeeksBelow: nil, weekBelowCount: nil)]
        )
        let jsonData = try! JSONEncoder().encode(cacheData)
        mockFS.files[testCacheFile] = jsonData

        let cacheManager = EMACacheManager(
            fileSystem: mockFS,
            dateProvider: mockDateProvider,
            cacheDirectory: testCacheDirectory
        )
        await cacheManager.load()

        // Simulate sneak peek was done at 2:00 PM
        await cacheManager.markSneakPeekDone()

        // Advance to 2:05 PM (5 minutes later)
        mockDateProvider.currentDate = MockDateProvider(year: 2026, month: 2, day: 20, hour: 14, minute: 5, timeZone: et).now()

        let needs = await cacheManager.needsSneakPeekRefresh()
        XCTAssertTrue(needs)
    }

    func testNeedsSneakPeekRefresh_friday1PM_false() async {
        let mockFS = MockFileSystem()
        let et = MarketSchedule.easternTimeZone
        // Friday Feb 20 2026, 1:00 PM ET — not in sneak peek window
        let mockDateProvider = MockDateProvider(year: 2026, month: 2, day: 20, hour: 13, minute: 0, timeZone: et)

        let cacheTimeProvider = MockDateProvider(year: 2026, month: 2, day: 20, hour: 10, minute: 0, timeZone: et)
        let cacheTimestamp = ISO8601DateFormatter().string(from: cacheTimeProvider.now())

        let cacheData = EMACacheData(
            lastUpdated: cacheTimestamp,
            entries: ["AAPL": EMACacheEntry(day: 150.0, week: 148.0, weekCrossoverWeeksBelow: nil, weekBelowCount: nil)]
        )
        let jsonData = try! JSONEncoder().encode(cacheData)
        mockFS.files[testCacheFile] = jsonData

        let cacheManager = EMACacheManager(
            fileSystem: mockFS,
            dateProvider: mockDateProvider,
            cacheDirectory: testCacheDirectory
        )
        await cacheManager.load()

        let needs = await cacheManager.needsSneakPeekRefresh()
        XCTAssertFalse(needs)
    }

    func testNeedsSneakPeekRefresh_thursday2PM_false() async {
        let mockFS = MockFileSystem()
        let et = MarketSchedule.easternTimeZone
        // Thursday Feb 19 2026, 2:30 PM ET — not Friday
        let mockDateProvider = MockDateProvider(year: 2026, month: 2, day: 19, hour: 14, minute: 30, timeZone: et)

        let cacheTimeProvider = MockDateProvider(year: 2026, month: 2, day: 19, hour: 10, minute: 0, timeZone: et)
        let cacheTimestamp = ISO8601DateFormatter().string(from: cacheTimeProvider.now())

        let cacheData = EMACacheData(
            lastUpdated: cacheTimestamp,
            entries: ["AAPL": EMACacheEntry(day: 150.0, week: 148.0, weekCrossoverWeeksBelow: nil, weekBelowCount: nil)]
        )
        let jsonData = try! JSONEncoder().encode(cacheData)
        mockFS.files[testCacheFile] = jsonData

        let cacheManager = EMACacheManager(
            fileSystem: mockFS,
            dateProvider: mockDateProvider,
            cacheDirectory: testCacheDirectory
        )
        await cacheManager.load()

        let needs = await cacheManager.needsSneakPeekRefresh()
        XCTAssertFalse(needs)
    }

    func testNeedsSneakPeekRefresh_noCache_false() async {
        let mockFS = MockFileSystem()
        let et = MarketSchedule.easternTimeZone
        // Friday Feb 20 2026, 2:30 PM ET — but no cache
        let mockDateProvider = MockDateProvider(year: 2026, month: 2, day: 20, hour: 14, minute: 30, timeZone: et)

        let cacheManager = EMACacheManager(
            fileSystem: mockFS,
            dateProvider: mockDateProvider,
            cacheDirectory: testCacheDirectory
        )
        await cacheManager.load()

        let needs = await cacheManager.needsSneakPeekRefresh()
        XCTAssertFalse(needs)
    }

    // MARK: - Market Close Refresh Tests

    func testNeedsMarketCloseRefresh_before4pmET_returnsFalse() async {
        let mockFS = MockFileSystem()
        let et = MarketSchedule.easternTimeZone
        // Wednesday Feb 18 2026, 3:30 PM ET — before 4 PM
        let mockDateProvider = MockDateProvider(year: 2026, month: 2, day: 18, hour: 15, minute: 30, timeZone: et)

        let cacheTimeProvider = MockDateProvider(year: 2026, month: 2, day: 18, hour: 10, minute: 0, timeZone: et)
        let cacheTimestamp = ISO8601DateFormatter().string(from: cacheTimeProvider.now())

        let cacheData = EMACacheData(
            lastUpdated: cacheTimestamp,
            entries: ["AAPL": EMACacheEntry(day: 150.0, week: 148.0, weekCrossoverWeeksBelow: nil, weekBelowCount: nil)]
        )
        let jsonData = try! JSONEncoder().encode(cacheData)
        mockFS.files[testCacheFile] = jsonData

        let cacheManager = EMACacheManager(
            fileSystem: mockFS,
            dateProvider: mockDateProvider,
            cacheDirectory: testCacheDirectory
        )
        await cacheManager.load()

        let needs = await cacheManager.needsMarketCloseRefresh()
        XCTAssertFalse(needs)
    }

    func testNeedsMarketCloseRefresh_after4pmCacheUpdatedBefore4pm_returnsTrue() async {
        let mockFS = MockFileSystem()
        let et = MarketSchedule.easternTimeZone
        // Wednesday Feb 18 2026, 4:30 PM ET
        let mockDateProvider = MockDateProvider(year: 2026, month: 2, day: 18, hour: 16, minute: 30, timeZone: et)

        // Cache updated at 2 PM ET same day — before 4 PM
        let cacheTimeProvider = MockDateProvider(year: 2026, month: 2, day: 18, hour: 14, minute: 0, timeZone: et)
        let cacheTimestamp = ISO8601DateFormatter().string(from: cacheTimeProvider.now())

        let cacheData = EMACacheData(
            lastUpdated: cacheTimestamp,
            entries: ["AAPL": EMACacheEntry(day: 150.0, week: 148.0, weekCrossoverWeeksBelow: nil, weekBelowCount: nil)]
        )
        let jsonData = try! JSONEncoder().encode(cacheData)
        mockFS.files[testCacheFile] = jsonData

        let cacheManager = EMACacheManager(
            fileSystem: mockFS,
            dateProvider: mockDateProvider,
            cacheDirectory: testCacheDirectory
        )
        await cacheManager.load()

        let needs = await cacheManager.needsMarketCloseRefresh()
        XCTAssertTrue(needs)
    }

    func testNeedsMarketCloseRefresh_after4pmCacheUpdatedAfter4pm_returnsFalse() async {
        let mockFS = MockFileSystem()
        let et = MarketSchedule.easternTimeZone
        // Wednesday Feb 18 2026, 5:00 PM ET
        let mockDateProvider = MockDateProvider(year: 2026, month: 2, day: 18, hour: 17, minute: 0, timeZone: et)

        // Cache updated at 4:15 PM ET same day — after 4 PM
        let cacheTimeProvider = MockDateProvider(year: 2026, month: 2, day: 18, hour: 16, minute: 15, timeZone: et)
        let cacheTimestamp = ISO8601DateFormatter().string(from: cacheTimeProvider.now())

        let cacheData = EMACacheData(
            lastUpdated: cacheTimestamp,
            entries: ["AAPL": EMACacheEntry(day: 150.0, week: 148.0, weekCrossoverWeeksBelow: nil, weekBelowCount: nil)]
        )
        let jsonData = try! JSONEncoder().encode(cacheData)
        mockFS.files[testCacheFile] = jsonData

        let cacheManager = EMACacheManager(
            fileSystem: mockFS,
            dateProvider: mockDateProvider,
            cacheDirectory: testCacheDirectory
        )
        await cacheManager.load()

        let needs = await cacheManager.needsMarketCloseRefresh()
        XCTAssertFalse(needs)
    }

    func testNeedsMarketCloseRefresh_weekend_returnsFalse() async {
        let mockFS = MockFileSystem()
        let et = MarketSchedule.easternTimeZone
        // Saturday Feb 21 2026, 5:00 PM ET
        let mockDateProvider = MockDateProvider(year: 2026, month: 2, day: 21, hour: 17, minute: 0, timeZone: et)

        let cacheTimeProvider = MockDateProvider(year: 2026, month: 2, day: 20, hour: 10, minute: 0, timeZone: et)
        let cacheTimestamp = ISO8601DateFormatter().string(from: cacheTimeProvider.now())

        let cacheData = EMACacheData(
            lastUpdated: cacheTimestamp,
            entries: ["AAPL": EMACacheEntry(day: 150.0, week: 148.0, weekCrossoverWeeksBelow: nil, weekBelowCount: nil)]
        )
        let jsonData = try! JSONEncoder().encode(cacheData)
        mockFS.files[testCacheFile] = jsonData

        let cacheManager = EMACacheManager(
            fileSystem: mockFS,
            dateProvider: mockDateProvider,
            cacheDirectory: testCacheDirectory
        )
        await cacheManager.load()

        let needs = await cacheManager.needsMarketCloseRefresh()
        XCTAssertFalse(needs)
    }

    // MARK: - Clear Daily Fields Tests

    func testClearDailyFields_preservesWeeklyData() async {
        let mockFS = MockFileSystem()

        let cacheData = EMACacheData(
            lastUpdated: "2026-02-18T12:00:00Z",
            entries: [
                "AAPL": EMACacheEntry(day: 150.0, week: 148.0, weekCrossoverWeeksBelow: 3, weekCrossdownWeeksAbove: 7, weekBelowCount: 2, dayAboveCount: 5, weekAboveCount: 10),
                "SPY": EMACacheEntry(day: 500.0, week: 495.0, weekCrossoverWeeksBelow: nil, weekCrossdownWeeksAbove: nil, weekBelowCount: nil, dayAboveCount: 8, weekAboveCount: nil),
            ]
        )
        let jsonData = try! JSONEncoder().encode(cacheData)
        mockFS.files[testCacheFile] = jsonData

        let cacheManager = EMACacheManager(
            fileSystem: mockFS,
            cacheDirectory: testCacheDirectory
        )
        await cacheManager.load()
        await cacheManager.clearDailyFields()

        let aaplEntry = await cacheManager.getEntry(for: "AAPL")
        XCTAssertNil(aaplEntry?.day)
        XCTAssertNil(aaplEntry?.dayAboveCount)
        XCTAssertEqual(aaplEntry?.week, 148.0)
        XCTAssertEqual(aaplEntry?.weekCrossoverWeeksBelow, 3)
        XCTAssertEqual(aaplEntry?.weekBelowCount, 2)
        XCTAssertEqual(aaplEntry?.weekAboveCount, 10)
        XCTAssertEqual(aaplEntry?.weekCrossdownWeeksAbove, 7)

        let spyEntry = await cacheManager.getEntry(for: "SPY")
        XCTAssertNil(spyEntry?.day)
        XCTAssertNil(spyEntry?.dayAboveCount)
        XCTAssertEqual(spyEntry?.week, 495.0)
        XCTAssertNil(spyEntry?.weekCrossoverWeeksBelow)
        XCTAssertNil(spyEntry?.weekAboveCount)
        XCTAssertNil(spyEntry?.weekCrossdownWeeksAbove)

        // Entries still exist (not removed, just daily fields cleared)
        let allEntries = await cacheManager.getAllEntries()
        XCTAssertEqual(allEntries.count, 2)
    }

    // MARK: - Update Daily Fields Tests

    func testUpdateDailyFields_preservesWeeklyData() async {
        let mockFS = MockFileSystem()

        let cacheData = EMACacheData(
            lastUpdated: "2026-02-15T12:00:00Z",
            entries: [
                "AAPL": EMACacheEntry(day: nil, week: 148.0, weekCrossoverWeeksBelow: 3, weekCrossdownWeeksAbove: 7, weekBelowCount: 2, dayAboveCount: nil, weekAboveCount: 10),
            ]
        )
        let jsonData = try! JSONEncoder().encode(cacheData)
        mockFS.files[testCacheFile] = jsonData

        let cacheManager = EMACacheManager(
            fileSystem: mockFS,
            cacheDirectory: testCacheDirectory
        )
        await cacheManager.load()
        await cacheManager.updateDailyFields(for: "AAPL", day: 155.0, dayAboveCount: 12)

        let entry = await cacheManager.getEntry(for: "AAPL")
        XCTAssertEqual(entry?.day, 155.0)
        XCTAssertEqual(entry?.dayAboveCount, 12)
        XCTAssertEqual(entry?.week, 148.0)
        XCTAssertEqual(entry?.weekCrossoverWeeksBelow, 3)
        XCTAssertEqual(entry?.weekCrossdownWeeksAbove, 7)
        XCTAssertEqual(entry?.weekBelowCount, 2)
        XCTAssertEqual(entry?.weekAboveCount, 10)
    }

    func testUpdateDailyFields_missingSymbol_noOp() async {
        let mockFS = MockFileSystem()
        let cacheManager = EMACacheManager(
            fileSystem: mockFS,
            cacheDirectory: testCacheDirectory
        )

        await cacheManager.setEntry(for: "AAPL", entry: EMACacheEntry(day: 150.0, week: 148.0, weekCrossoverWeeksBelow: nil, weekBelowCount: nil))
        await cacheManager.updateDailyFields(for: "SPY", day: 500.0, dayAboveCount: 5)

        let entry = await cacheManager.getEntry(for: "SPY")
        XCTAssertNil(entry)
    }

    func testLoad_withCrossoverField_decodesCorrectly() async {
        let mockFS = MockFileSystem()

        let cacheData = EMACacheData(
            lastUpdated: "2026-02-18T12:00:00Z",
            entries: [
                "AAPL": EMACacheEntry(day: 150.0, week: 148.0, weekCrossoverWeeksBelow: 2, weekBelowCount: nil),
                "SPY": EMACacheEntry(day: 500.0, week: 495.0, weekCrossoverWeeksBelow: nil, weekBelowCount: nil),
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

        XCTAssertEqual(aaplEntry?.weekCrossoverWeeksBelow, 2)
        XCTAssertNil(spyEntry?.weekCrossoverWeeksBelow)
    }
}
