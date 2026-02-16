import XCTest
@testable import StockTicker

// MARK: - Forward P/E Cache Tests

final class ForwardPECacheTests: XCTestCase {

    private let testCacheDirectory = URL(fileURLWithPath: "/tmp/test-forward-pe")
    private let testCacheFile = "/tmp/test-forward-pe/forward-pe-cache.json"

    // MARK: - Load Tests

    func testLoad_whenCacheDoesNotExist_cacheIsNil() async {
        let mockFS = MockFileSystem()
        let cacheManager = ForwardPECacheManager(
            fileSystem: mockFS,
            cacheDirectory: testCacheDirectory
        )

        await cacheManager.load()

        let data = await cacheManager.getAllData()
        XCTAssertTrue(data.isEmpty)
    }

    func testLoad_whenCacheExists_loadsData() async {
        let mockFS = MockFileSystem()

        let cacheData = ForwardPECacheData(
            quarterRange: "Q1-2023:Q4-2025",
            lastUpdated: "2026-02-15T12:00:00Z",
            symbols: [
                "AAPL": ["Q4-2025": 28.5, "Q3-2025": 30.2],
                "MSFT": ["Q4-2025": 32.1]
            ]
        )
        let jsonData = try! JSONEncoder().encode(cacheData)
        mockFS.files[testCacheFile] = jsonData

        let cacheManager = ForwardPECacheManager(
            fileSystem: mockFS,
            cacheDirectory: testCacheDirectory
        )

        await cacheManager.load()

        let data = await cacheManager.getAllData()
        XCTAssertEqual(data["AAPL"]?["Q4-2025"], 28.5)
        XCTAssertEqual(data["AAPL"]?["Q3-2025"], 30.2)
        XCTAssertEqual(data["MSFT"]?["Q4-2025"], 32.1)
    }

    // MARK: - Save Tests

    func testSave_writesCacheToFile() async {
        let mockFS = MockFileSystem()
        let cacheManager = ForwardPECacheManager(
            fileSystem: mockFS,
            cacheDirectory: testCacheDirectory
        )

        await cacheManager.clearForNewRange("Q1-2023:Q4-2025")
        await cacheManager.setForwardPE(symbol: "AAPL", quarterPEs: ["Q4-2025": 28.5])
        await cacheManager.save()

        let cacheURL = URL(fileURLWithPath: testCacheFile)
        XCTAssertNotNil(mockFS.writtenFiles[cacheURL])

        if let writtenData = mockFS.writtenFiles[cacheURL] {
            let decoded = try! JSONDecoder().decode(ForwardPECacheData.self, from: writtenData)
            XCTAssertEqual(decoded.symbols["AAPL"]?["Q4-2025"], 28.5)
            XCTAssertEqual(decoded.quarterRange, "Q1-2023:Q4-2025")
        }
    }

    // MARK: - Needs Invalidation Tests

    func testNeedsInvalidation_whenCacheIsNil_returnsTrue() async {
        let mockFS = MockFileSystem()
        let cacheManager = ForwardPECacheManager(
            fileSystem: mockFS,
            cacheDirectory: testCacheDirectory
        )

        await cacheManager.load()

        let needsInvalidation = await cacheManager.needsInvalidation(currentRange: "Q1-2023:Q4-2025")
        XCTAssertTrue(needsInvalidation)
    }

    func testNeedsInvalidation_whenRangeMatches_returnsFalse() async {
        let mockFS = MockFileSystem()

        let cacheData = ForwardPECacheData(
            quarterRange: "Q1-2023:Q4-2025",
            lastUpdated: "2026-02-15T12:00:00Z",
            symbols: ["AAPL": ["Q4-2025": 28.5]]
        )
        let jsonData = try! JSONEncoder().encode(cacheData)
        mockFS.files[testCacheFile] = jsonData

        let cacheManager = ForwardPECacheManager(
            fileSystem: mockFS,
            cacheDirectory: testCacheDirectory
        )

        await cacheManager.load()

        let needsInvalidation = await cacheManager.needsInvalidation(currentRange: "Q1-2023:Q4-2025")
        XCTAssertFalse(needsInvalidation)
    }

    func testNeedsInvalidation_whenRangeDiffers_returnsTrue() async {
        let mockFS = MockFileSystem()

        let cacheData = ForwardPECacheData(
            quarterRange: "Q4-2022:Q3-2025",
            lastUpdated: "2025-12-15T12:00:00Z",
            symbols: ["AAPL": ["Q3-2025": 29.0]]
        )
        let jsonData = try! JSONEncoder().encode(cacheData)
        mockFS.files[testCacheFile] = jsonData

        let cacheManager = ForwardPECacheManager(
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

        let cacheData = ForwardPECacheData(
            quarterRange: "Q4-2022:Q3-2025",
            lastUpdated: "2025-12-15T12:00:00Z",
            symbols: ["AAPL": ["Q3-2025": 29.0], "SPY": [:]]
        )
        let jsonData = try! JSONEncoder().encode(cacheData)
        mockFS.files[testCacheFile] = jsonData

        let cacheManager = ForwardPECacheManager(
            fileSystem: mockFS,
            dateProvider: mockDateProvider,
            cacheDirectory: testCacheDirectory
        )

        await cacheManager.load()
        await cacheManager.clearForNewRange("Q1-2023:Q4-2025")

        let data = await cacheManager.getAllData()
        XCTAssertTrue(data.isEmpty)

        let needsInvalidation = await cacheManager.needsInvalidation(currentRange: "Q1-2023:Q4-2025")
        XCTAssertFalse(needsInvalidation)
    }

    // MARK: - Missing Symbols Tests

    func testGetMissingSymbols_returnsSymbolsNotInCache() async {
        let mockFS = MockFileSystem()

        let cacheData = ForwardPECacheData(
            quarterRange: "Q1-2023:Q4-2025",
            lastUpdated: "2026-02-15T12:00:00Z",
            symbols: ["AAPL": ["Q4-2025": 28.5]]
        )
        let jsonData = try! JSONEncoder().encode(cacheData)
        mockFS.files[testCacheFile] = jsonData

        let cacheManager = ForwardPECacheManager(
            fileSystem: mockFS,
            cacheDirectory: testCacheDirectory
        )

        await cacheManager.load()

        let missing = await cacheManager.getMissingSymbols(from: ["AAPL", "SPY", "QQQ"])
        XCTAssertEqual(Set(missing), Set(["SPY", "QQQ"]))
    }

    func testGetMissingSymbols_whenCacheEmpty_returnsAllSymbols() async {
        let mockFS = MockFileSystem()
        let cacheManager = ForwardPECacheManager(
            fileSystem: mockFS,
            cacheDirectory: testCacheDirectory
        )

        await cacheManager.load()

        let missing = await cacheManager.getMissingSymbols(from: ["AAPL", "SPY"])
        XCTAssertEqual(Set(missing), Set(["AAPL", "SPY"]))
    }

    func testGetMissingSymbols_emptyDictCountsAsCached() async {
        let mockFS = MockFileSystem()

        let cacheData = ForwardPECacheData(
            quarterRange: "Q1-2023:Q4-2025",
            lastUpdated: "2026-02-15T12:00:00Z",
            symbols: [
                "AAPL": ["Q4-2025": 28.5],
                "BTC-USD": [:]  // Empty dict = no P/E data available, but cached
            ]
        )
        let jsonData = try! JSONEncoder().encode(cacheData)
        mockFS.files[testCacheFile] = jsonData

        let cacheManager = ForwardPECacheManager(
            fileSystem: mockFS,
            cacheDirectory: testCacheDirectory
        )

        await cacheManager.load()

        let missing = await cacheManager.getMissingSymbols(from: ["AAPL", "BTC-USD", "SPY"])
        XCTAssertEqual(missing, ["SPY"])
    }

    // MARK: - Get All Data Tests

    func testGetAllData_returnsAllStoredData() async {
        let mockFS = MockFileSystem()

        let cacheData = ForwardPECacheData(
            quarterRange: "Q1-2023:Q4-2025",
            lastUpdated: "2026-02-15T12:00:00Z",
            symbols: [
                "AAPL": ["Q4-2025": 28.5, "Q3-2025": 30.2],
                "MSFT": ["Q4-2025": 32.1]
            ]
        )
        let jsonData = try! JSONEncoder().encode(cacheData)
        mockFS.files[testCacheFile] = jsonData

        let cacheManager = ForwardPECacheManager(
            fileSystem: mockFS,
            cacheDirectory: testCacheDirectory
        )

        await cacheManager.load()

        let data = await cacheManager.getAllData()
        XCTAssertEqual(data.count, 2)
        XCTAssertEqual(data["AAPL"]?.count, 2)
        XCTAssertEqual(data["MSFT"]?.count, 1)
    }
}
