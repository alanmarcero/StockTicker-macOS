import XCTest
@testable import StockTicker

// MARK: - Highest Close Cache Tests

final class HighestCloseCacheTests: XCTestCase {

    private let testCacheDirectory = URL(fileURLWithPath: "/tmp/test-highest-close")
    private let testCacheFile = "/tmp/test-highest-close/highest-close-cache.json"

    // MARK: - Load Tests

    func testLoad_whenCacheDoesNotExist_cacheIsNil() async {
        let mockFS = MockFileSystem()
        let cacheManager = HighestCloseCacheManager(
            fileSystem: mockFS,
            cacheDirectory: testCacheDirectory
        )

        await cacheManager.load()

        let price = await cacheManager.getHighestClose(for: "AAPL")
        XCTAssertNil(price)
    }

    func testLoad_whenCacheExists_loadsPrices() async {
        let mockFS = MockFileSystem()

        let cacheData = HighestCloseCacheData(
            quarterRange: "Q1-2026",
            lastUpdated: "2026-02-15T12:00:00Z",
            prices: ["AAPL": 260.50, "SPY": 690.10]
        )
        let jsonData = try! JSONEncoder().encode(cacheData)
        mockFS.files[testCacheFile] = jsonData

        let cacheManager = HighestCloseCacheManager(
            fileSystem: mockFS,
            cacheDirectory: testCacheDirectory
        )

        await cacheManager.load()

        let aaplPrice = await cacheManager.getHighestClose(for: "AAPL")
        let spyPrice = await cacheManager.getHighestClose(for: "SPY")

        XCTAssertEqual(aaplPrice, 260.50)
        XCTAssertEqual(spyPrice, 690.10)
    }

    // MARK: - Save Tests

    func testSave_writesCacheToFile() async {
        let mockFS = MockFileSystem()
        let cacheManager = HighestCloseCacheManager(
            fileSystem: mockFS,
            cacheDirectory: testCacheDirectory
        )

        await cacheManager.clearForNewRange("Q1-2026")
        await cacheManager.setHighestClose(for: "AAPL", price: 260.50)
        await cacheManager.save()

        let cacheURL = URL(fileURLWithPath: testCacheFile)
        XCTAssertNotNil(mockFS.writtenFiles[cacheURL])

        if let writtenData = mockFS.writtenFiles[cacheURL] {
            let decoded = try! JSONDecoder().decode(HighestCloseCacheData.self, from: writtenData)
            XCTAssertEqual(decoded.prices["AAPL"], 260.50)
            XCTAssertEqual(decoded.quarterRange, "Q1-2026")
        }
    }

    // MARK: - Needs Invalidation Tests

    func testNeedsInvalidation_whenCacheIsNil_returnsTrue() async {
        let mockFS = MockFileSystem()
        let cacheManager = HighestCloseCacheManager(
            fileSystem: mockFS,
            cacheDirectory: testCacheDirectory
        )

        await cacheManager.load()

        let needsInvalidation = await cacheManager.needsInvalidation(currentRange: "Q1-2026")
        XCTAssertTrue(needsInvalidation)
    }

    func testNeedsInvalidation_whenRangeMatches_returnsFalse() async {
        let mockFS = MockFileSystem()

        let cacheData = HighestCloseCacheData(
            quarterRange: "Q1-2026",
            lastUpdated: "2026-02-15T12:00:00Z",
            prices: ["AAPL": 260.50]
        )
        let jsonData = try! JSONEncoder().encode(cacheData)
        mockFS.files[testCacheFile] = jsonData

        let cacheManager = HighestCloseCacheManager(
            fileSystem: mockFS,
            cacheDirectory: testCacheDirectory
        )

        await cacheManager.load()

        let needsInvalidation = await cacheManager.needsInvalidation(currentRange: "Q1-2026")
        XCTAssertFalse(needsInvalidation)
    }

    func testNeedsInvalidation_whenRangeDiffers_returnsTrue() async {
        let mockFS = MockFileSystem()

        let cacheData = HighestCloseCacheData(
            quarterRange: "Q4-2025",
            lastUpdated: "2025-12-15T12:00:00Z",
            prices: ["AAPL": 250.00]
        )
        let jsonData = try! JSONEncoder().encode(cacheData)
        mockFS.files[testCacheFile] = jsonData

        let cacheManager = HighestCloseCacheManager(
            fileSystem: mockFS,
            cacheDirectory: testCacheDirectory
        )

        await cacheManager.load()

        let needsInvalidation = await cacheManager.needsInvalidation(currentRange: "Q1-2026")
        XCTAssertTrue(needsInvalidation)
    }

    // MARK: - Clear For New Range Tests

    func testClearForNewRange_resetsCache() async {
        let mockFS = MockFileSystem()
        let mockDateProvider = MockDateProvider(year: 2026, month: 2, day: 15)

        let cacheData = HighestCloseCacheData(
            quarterRange: "Q4-2025",
            lastUpdated: "2025-12-15T12:00:00Z",
            prices: ["AAPL": 250.00, "SPY": 680.00]
        )
        let jsonData = try! JSONEncoder().encode(cacheData)
        mockFS.files[testCacheFile] = jsonData

        let cacheManager = HighestCloseCacheManager(
            fileSystem: mockFS,
            dateProvider: mockDateProvider,
            cacheDirectory: testCacheDirectory
        )

        await cacheManager.load()
        await cacheManager.clearForNewRange("Q1-2026")

        let price = await cacheManager.getHighestClose(for: "AAPL")
        XCTAssertNil(price)

        let allPrices = await cacheManager.getAllPrices()
        XCTAssertTrue(allPrices.isEmpty)

        let needsInvalidation = await cacheManager.needsInvalidation(currentRange: "Q1-2026")
        XCTAssertFalse(needsInvalidation)
    }

    // MARK: - Missing Symbols Tests

    func testGetMissingSymbols_returnsSymbolsNotInCache() async {
        let mockFS = MockFileSystem()

        let cacheData = HighestCloseCacheData(
            quarterRange: "Q1-2026",
            lastUpdated: "2026-02-15T12:00:00Z",
            prices: ["AAPL": 260.50]
        )
        let jsonData = try! JSONEncoder().encode(cacheData)
        mockFS.files[testCacheFile] = jsonData

        let cacheManager = HighestCloseCacheManager(
            fileSystem: mockFS,
            cacheDirectory: testCacheDirectory
        )

        await cacheManager.load()

        let missing = await cacheManager.getMissingSymbols(from: ["AAPL", "SPY", "QQQ"])
        XCTAssertEqual(Set(missing), Set(["SPY", "QQQ"]))
    }

    func testGetMissingSymbols_whenCacheEmpty_returnsAllSymbols() async {
        let mockFS = MockFileSystem()
        let cacheManager = HighestCloseCacheManager(
            fileSystem: mockFS,
            cacheDirectory: testCacheDirectory
        )

        await cacheManager.load()

        let missing = await cacheManager.getMissingSymbols(from: ["AAPL", "SPY"])
        XCTAssertEqual(Set(missing), Set(["AAPL", "SPY"]))
    }

    // MARK: - Get All Prices Tests

    func testGetAllPrices_returnsAllCachedPrices() async {
        let mockFS = MockFileSystem()

        let cacheData = HighestCloseCacheData(
            quarterRange: "Q1-2026",
            lastUpdated: "2026-02-15T12:00:00Z",
            prices: ["AAPL": 260.50, "SPY": 690.10]
        )
        let jsonData = try! JSONEncoder().encode(cacheData)
        mockFS.files[testCacheFile] = jsonData

        let cacheManager = HighestCloseCacheManager(
            fileSystem: mockFS,
            cacheDirectory: testCacheDirectory
        )

        await cacheManager.load()

        let allPrices = await cacheManager.getAllPrices()
        XCTAssertEqual(allPrices["AAPL"], 260.50)
        XCTAssertEqual(allPrices["SPY"], 690.10)
        XCTAssertEqual(allPrices.count, 2)
    }

    // MARK: - Needs Daily Refresh Tests

    func testNeedsDailyRefresh_whenCacheIsNil_returnsTrue() async {
        let mockFS = MockFileSystem()
        let cacheManager = HighestCloseCacheManager(
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
        let cacheData = HighestCloseCacheData(
            quarterRange: "Q1-2026",
            lastUpdated: todayString,
            prices: ["AAPL": 260.50]
        )
        let jsonData = try! JSONEncoder().encode(cacheData)
        mockFS.files[testCacheFile] = jsonData

        let cacheManager = HighestCloseCacheManager(
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
        let cacheData = HighestCloseCacheData(
            quarterRange: "Q1-2026",
            lastUpdated: yesterdayString,
            prices: ["AAPL": 260.50]
        )
        let jsonData = try! JSONEncoder().encode(cacheData)
        mockFS.files[testCacheFile] = jsonData

        let cacheManager = HighestCloseCacheManager(
            fileSystem: mockFS,
            dateProvider: mockDateProvider,
            cacheDirectory: testCacheDirectory
        )

        await cacheManager.load()

        let needsRefresh = await cacheManager.needsDailyRefresh()
        XCTAssertTrue(needsRefresh)
    }

    // MARK: - Clear Prices For Daily Refresh Tests

    func testClearPricesForDailyRefresh_emptiesPricesKeepsQuarterRange() async {
        let mockFS = MockFileSystem()

        let cacheData = HighestCloseCacheData(
            quarterRange: "Q1-2026",
            lastUpdated: "2026-02-15T12:00:00Z",
            prices: ["AAPL": 260.50, "SPY": 690.10]
        )
        let jsonData = try! JSONEncoder().encode(cacheData)
        mockFS.files[testCacheFile] = jsonData

        let cacheManager = HighestCloseCacheManager(
            fileSystem: mockFS,
            cacheDirectory: testCacheDirectory
        )

        await cacheManager.load()
        await cacheManager.clearPricesForDailyRefresh()

        let allPrices = await cacheManager.getAllPrices()
        XCTAssertTrue(allPrices.isEmpty)

        let needsInvalidation = await cacheManager.needsInvalidation(currentRange: "Q1-2026")
        XCTAssertFalse(needsInvalidation)

        await cacheManager.save()

        let cacheURL = URL(fileURLWithPath: testCacheFile)
        if let writtenData = mockFS.writtenFiles[cacheURL] {
            let decoded = try! JSONDecoder().decode(HighestCloseCacheData.self, from: writtenData)
            XCTAssertEqual(decoded.quarterRange, "Q1-2026")
            XCTAssertTrue(decoded.prices.isEmpty)
            XCTAssertEqual(decoded.lastUpdated, "")
        } else {
            XCTFail("Cache was not written")
        }
    }
}
