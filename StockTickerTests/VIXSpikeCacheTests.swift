import XCTest
@testable import StockTicker

// MARK: - VIX Spike Cache Tests

final class VIXSpikeCacheTests: XCTestCase {

    private let testCacheDirectory = URL(fileURLWithPath: "/tmp/test-vix-spike")
    private let testCacheFile = "/tmp/test-vix-spike/vix-spike-cache.json"

    // MARK: - Load Tests

    func testLoad_whenCacheDoesNotExist_cacheIsNil() async {
        let mockFS = MockFileSystem()
        let cacheManager = VIXSpikeCacheManager(
            fileSystem: mockFS,
            cacheDirectory: testCacheDirectory
        )

        await cacheManager.load()

        let spikes = await cacheManager.getSpikes()
        XCTAssertTrue(spikes.isEmpty)
    }

    func testLoad_whenCacheExists_loadsData() async {
        let mockFS = MockFileSystem()

        let spike = VIXSpike(dateString: "3/15/23", timestamp: 1678867200, vixClose: 26.5)
        let cacheData = VIXSpikeCacheData(
            lastUpdated: "2026-02-15T12:00:00Z",
            spikes: [spike],
            symbolPrices: ["AAPL": ["3/15/23": 150.0]]
        )
        let jsonData = try! JSONEncoder().encode(cacheData)
        mockFS.files[testCacheFile] = jsonData

        let cacheManager = VIXSpikeCacheManager(
            fileSystem: mockFS,
            cacheDirectory: testCacheDirectory
        )

        await cacheManager.load()

        let spikes = await cacheManager.getSpikes()
        XCTAssertEqual(spikes.count, 1)
        XCTAssertEqual(spikes[0].dateString, "3/15/23")
        XCTAssertEqual(spikes[0].vixClose, 26.5)

        let prices = await cacheManager.getPrices(for: "AAPL")
        XCTAssertEqual(prices?["3/15/23"], 150.0)
    }

    // MARK: - Save Tests

    func testSave_writesCacheToFile() async {
        let mockFS = MockFileSystem()
        let cacheManager = VIXSpikeCacheManager(
            fileSystem: mockFS,
            cacheDirectory: testCacheDirectory
        )

        let spike = VIXSpike(dateString: "3/15/23", timestamp: 1678867200, vixClose: 26.5)
        await cacheManager.setSpikes([spike])
        await cacheManager.save()

        let cacheURL = URL(fileURLWithPath: testCacheFile)
        XCTAssertNotNil(mockFS.writtenFiles[cacheURL])

        if let writtenData = mockFS.writtenFiles[cacheURL] {
            let decoded = try! JSONDecoder().decode(VIXSpikeCacheData.self, from: writtenData)
            XCTAssertEqual(decoded.spikes.count, 1)
            XCTAssertEqual(decoded.spikes[0].vixClose, 26.5)
        }
    }

    // MARK: - Missing Symbols Tests

    func testGetMissingSymbols_returnsSymbolsNotInCache() async {
        let mockFS = MockFileSystem()

        let cacheData = VIXSpikeCacheData(
            lastUpdated: "2026-02-15T12:00:00Z",
            spikes: [],
            symbolPrices: ["AAPL": ["3/15/23": 150.0]]
        )
        let jsonData = try! JSONEncoder().encode(cacheData)
        mockFS.files[testCacheFile] = jsonData

        let cacheManager = VIXSpikeCacheManager(
            fileSystem: mockFS,
            cacheDirectory: testCacheDirectory
        )

        await cacheManager.load()

        let missing = await cacheManager.getMissingSymbols(from: ["AAPL", "SPY", "QQQ"])
        XCTAssertEqual(Set(missing), Set(["SPY", "QQQ"]))
    }

    func testGetMissingSymbols_whenCacheEmpty_returnsAllSymbols() async {
        let mockFS = MockFileSystem()
        let cacheManager = VIXSpikeCacheManager(
            fileSystem: mockFS,
            cacheDirectory: testCacheDirectory
        )

        await cacheManager.load()

        let missing = await cacheManager.getMissingSymbols(from: ["AAPL", "SPY"])
        XCTAssertEqual(Set(missing), Set(["AAPL", "SPY"]))
    }

    // MARK: - Set/Get Prices Tests

    func testSetPrices_getPrices_roundTrip() async {
        let mockFS = MockFileSystem()
        let cacheManager = VIXSpikeCacheManager(
            fileSystem: mockFS,
            cacheDirectory: testCacheDirectory
        )

        await cacheManager.setPrices(for: "AAPL", prices: ["3/15/23": 150.0, "8/5/24": 210.0])

        let prices = await cacheManager.getPrices(for: "AAPL")
        XCTAssertEqual(prices?["3/15/23"], 150.0)
        XCTAssertEqual(prices?["8/5/24"], 210.0)
    }

    func testGetAllSymbolPrices_returnsAllData() async {
        let mockFS = MockFileSystem()
        let cacheManager = VIXSpikeCacheManager(
            fileSystem: mockFS,
            cacheDirectory: testCacheDirectory
        )

        await cacheManager.setPrices(for: "AAPL", prices: ["3/15/23": 150.0])
        await cacheManager.setPrices(for: "SPY", prices: ["3/15/23": 400.0])

        let allPrices = await cacheManager.getAllSymbolPrices()
        XCTAssertEqual(allPrices.count, 2)
        XCTAssertEqual(allPrices["AAPL"]?["3/15/23"], 150.0)
        XCTAssertEqual(allPrices["SPY"]?["3/15/23"], 400.0)
    }

    // MARK: - Needs Daily Refresh Tests

    func testNeedsDailyRefresh_whenCacheIsNil_returnsTrue() async {
        let mockFS = MockFileSystem()
        let cacheManager = VIXSpikeCacheManager(
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
        let cacheData = VIXSpikeCacheData(
            lastUpdated: todayString,
            spikes: [],
            symbolPrices: [:]
        )
        let jsonData = try! JSONEncoder().encode(cacheData)
        mockFS.files[testCacheFile] = jsonData

        let cacheManager = VIXSpikeCacheManager(
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
        let cacheData = VIXSpikeCacheData(
            lastUpdated: yesterdayString,
            spikes: [],
            symbolPrices: [:]
        )
        let jsonData = try! JSONEncoder().encode(cacheData)
        mockFS.files[testCacheFile] = jsonData

        let cacheManager = VIXSpikeCacheManager(
            fileSystem: mockFS,
            dateProvider: mockDateProvider,
            cacheDirectory: testCacheDirectory
        )

        await cacheManager.load()

        let needsRefresh = await cacheManager.needsDailyRefresh()
        XCTAssertTrue(needsRefresh)
    }

    // MARK: - Replace Spikes If Changed

    func testReplaceSpikesAndClearIfChanged_sameDates_keepsPrices() async {
        let mockFS = MockFileSystem()

        let spike = VIXSpike(dateString: "3/15/23", timestamp: 1678867200, vixClose: 26.5)
        let cacheData = VIXSpikeCacheData(
            lastUpdated: "2026-02-15T12:00:00Z",
            spikes: [spike],
            symbolPrices: ["AAPL": ["3/15/23": 150.0]]
        )
        let jsonData = try! JSONEncoder().encode(cacheData)
        mockFS.files[testCacheFile] = jsonData

        let cacheManager = VIXSpikeCacheManager(
            fileSystem: mockFS,
            cacheDirectory: testCacheDirectory
        )

        await cacheManager.load()

        // Same dateString, different vixClose (peak updated but same day)
        let updatedSpike = VIXSpike(dateString: "3/15/23", timestamp: 1678867200, vixClose: 28.0)
        let pricesCleared = await cacheManager.replaceSpikesAndClearIfChanged([updatedSpike])

        XCTAssertFalse(pricesCleared)

        let spikes = await cacheManager.getSpikes()
        XCTAssertEqual(spikes[0].vixClose, 28.0)

        let prices = await cacheManager.getAllSymbolPrices()
        XCTAssertEqual(prices["AAPL"]?["3/15/23"], 150.0)
    }

    func testReplaceSpikesAndClearIfChanged_datesChanged_clearsOnlyRemovedDates() async {
        let mockFS = MockFileSystem()

        let spike = VIXSpike(dateString: "3/15/23", timestamp: 1678867200, vixClose: 26.5)
        let cacheData = VIXSpikeCacheData(
            lastUpdated: "2026-02-15T12:00:00Z",
            spikes: [spike],
            symbolPrices: ["AAPL": ["3/15/23": 150.0]]
        )
        let jsonData = try! JSONEncoder().encode(cacheData)
        mockFS.files[testCacheFile] = jsonData

        let cacheManager = VIXSpikeCacheManager(
            fileSystem: mockFS,
            cacheDirectory: testCacheDirectory
        )

        await cacheManager.load()

        // Peak moved to a different day — old date removed
        let newSpike = VIXSpike(dateString: "3/16/23", timestamp: 1678953600, vixClose: 30.0)
        let pricesCleared = await cacheManager.replaceSpikesAndClearIfChanged([newSpike])

        XCTAssertTrue(pricesCleared)

        let spikes = await cacheManager.getSpikes()
        XCTAssertEqual(spikes[0].dateString, "3/16/23")

        // Old date's prices removed, symbol still exists but with empty prices
        let prices = await cacheManager.getPrices(for: "AAPL")
        XCTAssertNotNil(prices)
        XCTAssertNil(prices?["3/15/23"])
    }

    func testReplaceSpikesAndClearIfChanged_newSpikeAdded_keepsOldPrices() async {
        let mockFS = MockFileSystem()

        let spike = VIXSpike(dateString: "3/15/23", timestamp: 1678867200, vixClose: 26.5)
        let cacheData = VIXSpikeCacheData(
            lastUpdated: "2026-02-15T12:00:00Z",
            spikes: [spike],
            symbolPrices: ["AAPL": ["3/15/23": 150.0]]
        )
        let jsonData = try! JSONEncoder().encode(cacheData)
        mockFS.files[testCacheFile] = jsonData

        let cacheManager = VIXSpikeCacheManager(
            fileSystem: mockFS,
            cacheDirectory: testCacheDirectory
        )

        await cacheManager.load()

        // New spike detected — old spike unchanged
        let newSpike = VIXSpike(dateString: "3/3/26", timestamp: 1772611200, vixClose: 22.0)
        let pricesCleared = await cacheManager.replaceSpikesAndClearIfChanged([spike, newSpike])

        XCTAssertTrue(pricesCleared)

        let spikes = await cacheManager.getSpikes()
        XCTAssertEqual(spikes.count, 2)

        // Old spike prices preserved
        let prices = await cacheManager.getPrices(for: "AAPL")
        XCTAssertEqual(prices?["3/15/23"], 150.0)
    }

    // MARK: - Clear For Daily Refresh

    func testClearForDailyRefresh_clearsOnlyMostRecentSpikePrices() async {
        let mockFS = MockFileSystem()

        let oldSpike = VIXSpike(dateString: "3/15/23", timestamp: 1678867200, vixClose: 26.5)
        let recentSpike = VIXSpike(dateString: "3/3/26", timestamp: 1772611200, vixClose: 22.0)
        let cacheData = VIXSpikeCacheData(
            lastUpdated: "2026-02-15T12:00:00Z",
            spikes: [oldSpike, recentSpike],
            symbolPrices: ["AAPL": ["3/15/23": 150.0, "3/3/26": 210.0]]
        )
        let jsonData = try! JSONEncoder().encode(cacheData)
        mockFS.files[testCacheFile] = jsonData

        let cacheManager = VIXSpikeCacheManager(
            fileSystem: mockFS,
            cacheDirectory: testCacheDirectory
        )

        await cacheManager.load()
        await cacheManager.clearForDailyRefresh()

        let spikes = await cacheManager.getSpikes()
        XCTAssertEqual(spikes.count, 2)

        // Old spike prices preserved, most recent cleared
        let prices = await cacheManager.getPrices(for: "AAPL")
        XCTAssertEqual(prices?["3/15/23"], 150.0)
        XCTAssertNil(prices?["3/3/26"])
    }

    // MARK: - Symbols Needing Refresh

    func testGetSymbolsNeedingRefresh_returnsSymbolsMissingAnyDate() async {
        let mockFS = MockFileSystem()

        let spike1 = VIXSpike(dateString: "3/15/23", timestamp: 1678867200, vixClose: 26.5)
        let spike2 = VIXSpike(dateString: "3/3/26", timestamp: 1772611200, vixClose: 22.0)
        let cacheData = VIXSpikeCacheData(
            lastUpdated: "2026-02-15T12:00:00Z",
            spikes: [spike1, spike2],
            symbolPrices: [
                "AAPL": ["3/15/23": 150.0, "3/3/26": 210.0],  // has both
                "SPY": ["3/15/23": 400.0],                      // missing recent
            ]
        )
        let jsonData = try! JSONEncoder().encode(cacheData)
        mockFS.files[testCacheFile] = jsonData

        let cacheManager = VIXSpikeCacheManager(
            fileSystem: mockFS,
            cacheDirectory: testCacheDirectory
        )

        await cacheManager.load()

        let needing = await cacheManager.getSymbolsNeedingRefresh(from: ["AAPL", "SPY", "QQQ"])
        XCTAssertEqual(Set(needing), Set(["SPY", "QQQ"]))
    }

    func testGetSymbolsNeedingRefresh_allCached_returnsEmpty() async {
        let mockFS = MockFileSystem()

        let spike = VIXSpike(dateString: "3/15/23", timestamp: 1678867200, vixClose: 26.5)
        let cacheData = VIXSpikeCacheData(
            lastUpdated: "2026-02-15T12:00:00Z",
            spikes: [spike],
            symbolPrices: ["AAPL": ["3/15/23": 150.0]]
        )
        let jsonData = try! JSONEncoder().encode(cacheData)
        mockFS.files[testCacheFile] = jsonData

        let cacheManager = VIXSpikeCacheManager(
            fileSystem: mockFS,
            cacheDirectory: testCacheDirectory
        )

        await cacheManager.load()

        let needing = await cacheManager.getSymbolsNeedingRefresh(from: ["AAPL"])
        XCTAssertTrue(needing.isEmpty)
    }

    // MARK: - Merge Prices

    func testMergePrices_addsNewDatesPreservesExisting() async {
        let mockFS = MockFileSystem()
        let cacheManager = VIXSpikeCacheManager(
            fileSystem: mockFS,
            cacheDirectory: testCacheDirectory
        )

        await cacheManager.setPrices(for: "AAPL", prices: ["3/15/23": 150.0])
        await cacheManager.mergePrices(for: "AAPL", newPrices: ["3/3/26": 210.0])

        let prices = await cacheManager.getPrices(for: "AAPL")
        XCTAssertEqual(prices?["3/15/23"], 150.0)
        XCTAssertEqual(prices?["3/3/26"], 210.0)
    }

    func testMergePrices_overwritesExistingDateWithNewValue() async {
        let mockFS = MockFileSystem()
        let cacheManager = VIXSpikeCacheManager(
            fileSystem: mockFS,
            cacheDirectory: testCacheDirectory
        )

        await cacheManager.setPrices(for: "AAPL", prices: ["3/15/23": 150.0])
        await cacheManager.mergePrices(for: "AAPL", newPrices: ["3/15/23": 155.0])

        let prices = await cacheManager.getPrices(for: "AAPL")
        XCTAssertEqual(prices?["3/15/23"], 155.0)
    }
}
