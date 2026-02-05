import XCTest
@testable import StockTicker

// MARK: - Mock Date Provider for YTD Cache Tests

final class MockYTDDateProvider: DateProvider {
    var currentDate: Date

    init(year: Int, month: Int = 1, day: Int = 15) {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = 12
        self.currentDate = Calendar.current.date(from: components) ?? Date()
    }

    func now() -> Date {
        currentDate
    }
}

// MARK: - Mock File System for YTD Cache Tests

final class MockYTDFileSystem: FileSystemProtocol {
    var homeDirectoryForCurrentUser: URL {
        URL(fileURLWithPath: "/tmp/test-ytd")
    }

    var existingFiles: Set<String> = []
    var fileContents: [String: Data] = [:]
    var createdDirectories: [URL] = []
    var writtenFiles: [URL: Data] = [:]

    func fileExists(atPath path: String) -> Bool {
        existingFiles.contains(path)
    }

    func createDirectoryAt(_ url: URL, withIntermediateDirectories: Bool) throws {
        createdDirectories.append(url)
        existingFiles.insert(url.path)
    }

    func contentsOfFile(atPath path: String) -> Data? {
        fileContents[path]
    }

    func writeData(_ data: Data, to url: URL) throws {
        writtenFiles[url] = data
        existingFiles.insert(url.path)
    }
}

// MARK: - YTD Cache Tests

final class YTDCacheTests: XCTestCase {

    // MARK: - Load Tests

    func testLoad_whenCacheDoesNotExist_cacheIsNil() async {
        let mockFileSystem = MockYTDFileSystem()
        let cacheManager = YTDCacheManager(
            fileSystem: mockFileSystem,
            cacheDirectory: URL(fileURLWithPath: "/tmp/test-ytd")
        )

        await cacheManager.load()

        let price = await cacheManager.getStartPrice(for: "AAPL")
        XCTAssertNil(price)
    }

    func testLoad_whenCacheExists_loadsPrices() async {
        let mockFileSystem = MockYTDFileSystem()
        let cacheURL = URL(fileURLWithPath: "/tmp/test-ytd/ytd-cache.json")

        let cacheData = YTDCacheData(year: 2026, lastUpdated: "2026-01-15", prices: ["AAPL": 254.23, "SPY": 681.92])
        let jsonData = try! JSONEncoder().encode(cacheData)

        mockFileSystem.existingFiles.insert(cacheURL.path)
        mockFileSystem.fileContents[cacheURL.path] = jsonData

        let cacheManager = YTDCacheManager(
            fileSystem: mockFileSystem,
            cacheDirectory: URL(fileURLWithPath: "/tmp/test-ytd")
        )

        await cacheManager.load()

        let aaplPrice = await cacheManager.getStartPrice(for: "AAPL")
        let spyPrice = await cacheManager.getStartPrice(for: "SPY")

        XCTAssertEqual(aaplPrice, 254.23)
        XCTAssertEqual(spyPrice, 681.92)
    }

    // MARK: - Save Tests

    func testSave_writesCacheToFile() async {
        let mockFileSystem = MockYTDFileSystem()
        let cacheManager = YTDCacheManager(
            fileSystem: mockFileSystem,
            cacheDirectory: URL(fileURLWithPath: "/tmp/test-ytd")
        )

        await cacheManager.setStartPrice(for: "AAPL", price: 254.23)
        await cacheManager.save()

        let cacheURL = URL(fileURLWithPath: "/tmp/test-ytd/ytd-cache.json")
        XCTAssertNotNil(mockFileSystem.writtenFiles[cacheURL])

        if let writtenData = mockFileSystem.writtenFiles[cacheURL] {
            let decoded = try! JSONDecoder().decode(YTDCacheData.self, from: writtenData)
            XCTAssertEqual(decoded.prices["AAPL"], 254.23)
        }
    }

    // MARK: - Year Rollover Tests

    func testNeedsYearRollover_whenCacheIsNil_returnsTrue() async {
        let mockFileSystem = MockYTDFileSystem()
        let cacheManager = YTDCacheManager(
            fileSystem: mockFileSystem,
            cacheDirectory: URL(fileURLWithPath: "/tmp/test-ytd")
        )

        await cacheManager.load()

        let needsRollover = await cacheManager.needsYearRollover()
        XCTAssertTrue(needsRollover)
    }

    func testNeedsYearRollover_whenYearMatches_returnsFalse() async {
        let mockFileSystem = MockYTDFileSystem()
        let cacheURL = URL(fileURLWithPath: "/tmp/test-ytd/ytd-cache.json")

        let currentYear = Calendar.current.component(.year, from: Date())
        let cacheData = YTDCacheData(year: currentYear, lastUpdated: "2026-01-15", prices: [:])
        let jsonData = try! JSONEncoder().encode(cacheData)

        mockFileSystem.existingFiles.insert(cacheURL.path)
        mockFileSystem.fileContents[cacheURL.path] = jsonData

        let cacheManager = YTDCacheManager(
            fileSystem: mockFileSystem,
            cacheDirectory: URL(fileURLWithPath: "/tmp/test-ytd")
        )

        await cacheManager.load()

        let needsRollover = await cacheManager.needsYearRollover()
        XCTAssertFalse(needsRollover)
    }

    func testNeedsYearRollover_whenYearDiffers_returnsTrue() async {
        let mockFileSystem = MockYTDFileSystem()
        let cacheURL = URL(fileURLWithPath: "/tmp/test-ytd/ytd-cache.json")

        let cacheData = YTDCacheData(year: 2020, lastUpdated: "2020-01-15", prices: [:])
        let jsonData = try! JSONEncoder().encode(cacheData)

        mockFileSystem.existingFiles.insert(cacheURL.path)
        mockFileSystem.fileContents[cacheURL.path] = jsonData

        let cacheManager = YTDCacheManager(
            fileSystem: mockFileSystem,
            cacheDirectory: URL(fileURLWithPath: "/tmp/test-ytd")
        )

        await cacheManager.load()

        let needsRollover = await cacheManager.needsYearRollover()
        XCTAssertTrue(needsRollover)
    }

    func testClearForNewYear_resetsCache() async {
        let mockFileSystem = MockYTDFileSystem()
        let cacheURL = URL(fileURLWithPath: "/tmp/test-ytd/ytd-cache.json")

        let cacheData = YTDCacheData(year: 2020, lastUpdated: "2020-01-15", prices: ["AAPL": 100.0])
        let jsonData = try! JSONEncoder().encode(cacheData)

        mockFileSystem.existingFiles.insert(cacheURL.path)
        mockFileSystem.fileContents[cacheURL.path] = jsonData

        let cacheManager = YTDCacheManager(
            fileSystem: mockFileSystem,
            cacheDirectory: URL(fileURLWithPath: "/tmp/test-ytd")
        )

        await cacheManager.load()
        await cacheManager.clearForNewYear()

        let price = await cacheManager.getStartPrice(for: "AAPL")
        XCTAssertNil(price)

        let needsRollover = await cacheManager.needsYearRollover()
        XCTAssertFalse(needsRollover)
    }

    // MARK: - Missing Symbols Tests

    func testGetMissingSymbols_returnsSymbolsNotInCache() async {
        let mockFileSystem = MockYTDFileSystem()
        let cacheURL = URL(fileURLWithPath: "/tmp/test-ytd/ytd-cache.json")

        let currentYear = Calendar.current.component(.year, from: Date())
        let cacheData = YTDCacheData(year: currentYear, lastUpdated: "2026-01-15", prices: ["AAPL": 254.23])
        let jsonData = try! JSONEncoder().encode(cacheData)

        mockFileSystem.existingFiles.insert(cacheURL.path)
        mockFileSystem.fileContents[cacheURL.path] = jsonData

        let cacheManager = YTDCacheManager(
            fileSystem: mockFileSystem,
            cacheDirectory: URL(fileURLWithPath: "/tmp/test-ytd")
        )

        await cacheManager.load()

        let missing = await cacheManager.getMissingSymbols(from: ["AAPL", "SPY", "QQQ"])
        XCTAssertEqual(Set(missing), Set(["SPY", "QQQ"]))
    }

    func testGetMissingSymbols_whenCacheEmpty_returnsAllSymbols() async {
        let mockFileSystem = MockYTDFileSystem()
        let cacheManager = YTDCacheManager(
            fileSystem: mockFileSystem,
            cacheDirectory: URL(fileURLWithPath: "/tmp/test-ytd")
        )

        await cacheManager.load()

        let missing = await cacheManager.getMissingSymbols(from: ["AAPL", "SPY"])
        XCTAssertEqual(Set(missing), Set(["AAPL", "SPY"]))
    }

    // MARK: - Get All Prices Tests

    func testGetAllPrices_returnsAllCachedPrices() async {
        let mockFileSystem = MockYTDFileSystem()
        let cacheURL = URL(fileURLWithPath: "/tmp/test-ytd/ytd-cache.json")

        let currentYear = Calendar.current.component(.year, from: Date())
        let cacheData = YTDCacheData(year: currentYear, lastUpdated: "2026-01-15", prices: ["AAPL": 254.23, "SPY": 681.92])
        let jsonData = try! JSONEncoder().encode(cacheData)

        mockFileSystem.existingFiles.insert(cacheURL.path)
        mockFileSystem.fileContents[cacheURL.path] = jsonData

        let cacheManager = YTDCacheManager(
            fileSystem: mockFileSystem,
            cacheDirectory: URL(fileURLWithPath: "/tmp/test-ytd")
        )

        await cacheManager.load()

        let allPrices = await cacheManager.getAllPrices()
        XCTAssertEqual(allPrices["AAPL"], 254.23)
        XCTAssertEqual(allPrices["SPY"], 681.92)
        XCTAssertEqual(allPrices.count, 2)
    }

    // MARK: - DateProvider Injection Tests

    func testNeedsYearRollover_withMockDateProvider_usesInjectedDate() async {
        let mockFileSystem = MockYTDFileSystem()
        let mockDateProvider = MockYTDDateProvider(year: 2025)
        let cacheURL = URL(fileURLWithPath: "/tmp/test-ytd/ytd-cache.json")

        // Cache has year 2025
        let cacheData = YTDCacheData(year: 2025, lastUpdated: "2025-01-15", prices: [:])
        let jsonData = try! JSONEncoder().encode(cacheData)

        mockFileSystem.existingFiles.insert(cacheURL.path)
        mockFileSystem.fileContents[cacheURL.path] = jsonData

        let cacheManager = YTDCacheManager(
            fileSystem: mockFileSystem,
            dateProvider: mockDateProvider,
            cacheDirectory: URL(fileURLWithPath: "/tmp/test-ytd")
        )

        await cacheManager.load()

        // Mock date is 2025, cache year is 2025 - no rollover needed
        let needsRollover = await cacheManager.needsYearRollover()
        XCTAssertFalse(needsRollover)
    }

    func testNeedsYearRollover_withMockDateProvider_detectsYearChange() async {
        let mockFileSystem = MockYTDFileSystem()
        let mockDateProvider = MockYTDDateProvider(year: 2026)
        let cacheURL = URL(fileURLWithPath: "/tmp/test-ytd/ytd-cache.json")

        // Cache has year 2025
        let cacheData = YTDCacheData(year: 2025, lastUpdated: "2025-12-31", prices: ["AAPL": 100.0])
        let jsonData = try! JSONEncoder().encode(cacheData)

        mockFileSystem.existingFiles.insert(cacheURL.path)
        mockFileSystem.fileContents[cacheURL.path] = jsonData

        let cacheManager = YTDCacheManager(
            fileSystem: mockFileSystem,
            dateProvider: mockDateProvider,
            cacheDirectory: URL(fileURLWithPath: "/tmp/test-ytd")
        )

        await cacheManager.load()

        // Mock date is 2026, cache year is 2025 - rollover needed
        let needsRollover = await cacheManager.needsYearRollover()
        XCTAssertTrue(needsRollover)
    }

    func testClearForNewYear_withMockDateProvider_usesInjectedYear() async {
        let mockFileSystem = MockYTDFileSystem()
        let mockDateProvider = MockYTDDateProvider(year: 2030)

        let cacheManager = YTDCacheManager(
            fileSystem: mockFileSystem,
            dateProvider: mockDateProvider,
            cacheDirectory: URL(fileURLWithPath: "/tmp/test-ytd")
        )

        await cacheManager.clearForNewYear()
        await cacheManager.save()

        let cacheURL = URL(fileURLWithPath: "/tmp/test-ytd/ytd-cache.json")
        if let writtenData = mockFileSystem.writtenFiles[cacheURL] {
            let decoded = try! JSONDecoder().decode(YTDCacheData.self, from: writtenData)
            XCTAssertEqual(decoded.year, 2030)
        } else {
            XCTFail("Cache was not written")
        }
    }

    func testSetStartPrice_withMockDateProvider_updatesLastUpdated() async {
        let mockFileSystem = MockYTDFileSystem()
        let mockDateProvider = MockYTDDateProvider(year: 2026, month: 6, day: 15)

        let cacheManager = YTDCacheManager(
            fileSystem: mockFileSystem,
            dateProvider: mockDateProvider,
            cacheDirectory: URL(fileURLWithPath: "/tmp/test-ytd")
        )

        await cacheManager.setStartPrice(for: "AAPL", price: 150.0)
        await cacheManager.save()

        let cacheURL = URL(fileURLWithPath: "/tmp/test-ytd/ytd-cache.json")
        if let writtenData = mockFileSystem.writtenFiles[cacheURL] {
            let decoded = try! JSONDecoder().decode(YTDCacheData.self, from: writtenData)
            XCTAssertTrue(decoded.lastUpdated.contains("2026"))
            XCTAssertEqual(decoded.year, 2026)
        } else {
            XCTFail("Cache was not written")
        }
    }
}
