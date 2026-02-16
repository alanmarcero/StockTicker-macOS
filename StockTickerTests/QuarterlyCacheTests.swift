import XCTest
@testable import StockTicker

// MARK: - Quarter Calculation Tests

final class QuarterCalculationTests: XCTestCase {

    // MARK: - lastNCompletedQuarters

    func testLastNCompletedQuarters_fromFeb2026_returns12Quarters() {
        let dateProvider = MockDateProvider(year: 2026, month: 2)
        let quarters = QuarterCalculation.lastNCompletedQuarters(from: dateProvider.now(), count: 12)

        XCTAssertEqual(quarters.count, 12)

        // Most recent first: Q4'25 through Q1'23
        XCTAssertEqual(quarters[0].identifier, "Q4-2025")
        XCTAssertEqual(quarters[0].displayLabel, "Q4'25")
        XCTAssertEqual(quarters[1].identifier, "Q3-2025")
        XCTAssertEqual(quarters[2].identifier, "Q2-2025")
        XCTAssertEqual(quarters[3].identifier, "Q1-2025")
        XCTAssertEqual(quarters[4].identifier, "Q4-2024")
        XCTAssertEqual(quarters[5].identifier, "Q3-2024")
        XCTAssertEqual(quarters[6].identifier, "Q2-2024")
        XCTAssertEqual(quarters[7].identifier, "Q1-2024")
        XCTAssertEqual(quarters[8].identifier, "Q4-2023")
        XCTAssertEqual(quarters[9].identifier, "Q3-2023")
        XCTAssertEqual(quarters[10].identifier, "Q2-2023")
        XCTAssertEqual(quarters[11].identifier, "Q1-2023")
    }

    func testLastNCompletedQuarters_fromJan2026_startsAtQ4_2025() {
        let dateProvider = MockDateProvider(year: 2026, month: 1)
        let quarters = QuarterCalculation.lastNCompletedQuarters(from: dateProvider.now(), count: 4)

        XCTAssertEqual(quarters[0].identifier, "Q4-2025")
        XCTAssertEqual(quarters[1].identifier, "Q3-2025")
        XCTAssertEqual(quarters[2].identifier, "Q2-2025")
        XCTAssertEqual(quarters[3].identifier, "Q1-2025")
    }

    func testLastNCompletedQuarters_fromApril2026_startsAtQ1_2026() {
        let dateProvider = MockDateProvider(year: 2026, month: 4)
        let quarters = QuarterCalculation.lastNCompletedQuarters(from: dateProvider.now(), count: 4)

        XCTAssertEqual(quarters[0].identifier, "Q1-2026")
        XCTAssertEqual(quarters[1].identifier, "Q4-2025")
        XCTAssertEqual(quarters[2].identifier, "Q3-2025")
        XCTAssertEqual(quarters[3].identifier, "Q2-2025")
    }

    func testLastNCompletedQuarters_fromJuly2025_startsAtQ2_2025() {
        let dateProvider = MockDateProvider(year: 2025, month: 7)
        let quarters = QuarterCalculation.lastNCompletedQuarters(from: dateProvider.now(), count: 2)

        XCTAssertEqual(quarters[0].identifier, "Q2-2025")
        XCTAssertEqual(quarters[1].identifier, "Q1-2025")
    }

    func testLastNCompletedQuarters_countZero_returnsEmpty() {
        let dateProvider = MockDateProvider(year: 2026, month: 2)
        let quarters = QuarterCalculation.lastNCompletedQuarters(from: dateProvider.now(), count: 0)

        XCTAssertTrue(quarters.isEmpty)
    }

    func testLastNCompletedQuarters_yearBoundary_crossesCorrectly() {
        let dateProvider = MockDateProvider(year: 2026, month: 1)
        let quarters = QuarterCalculation.lastNCompletedQuarters(from: dateProvider.now(), count: 2)

        XCTAssertEqual(quarters[0].identifier, "Q4-2025")
        XCTAssertEqual(quarters[0].year, 2025)
        XCTAssertEqual(quarters[0].quarter, 4)
        XCTAssertEqual(quarters[1].identifier, "Q3-2025")
    }

    // MARK: - quarterEndDateRange

    func testQuarterEndDateRange_Q4_2025_returnsDecemberRange() {
        let (period1, period2) = QuarterCalculation.quarterEndDateRange(year: 2025, quarter: 4)

        // Dec 31 is the end of Q4; period1 should be ~5 days before, period2 ~2 days after
        XCTAssertTrue(period1 > 0)
        XCTAssertTrue(period2 > period1)

        let p1Date = Date(timeIntervalSince1970: TimeInterval(period1))
        let p2Date = Date(timeIntervalSince1970: TimeInterval(period2))
        let calendar = Calendar.current

        // period1 should be around Dec 26
        XCTAssertEqual(calendar.component(.month, from: p1Date), 12)
        XCTAssertEqual(calendar.component(.day, from: p1Date), 26)

        // period2 should be around Jan 2
        XCTAssertEqual(calendar.component(.month, from: p2Date), 1)
        XCTAssertEqual(calendar.component(.day, from: p2Date), 2)
    }

    func testQuarterEndDateRange_Q1_2025_returnsMarchRange() {
        let (period1, period2) = QuarterCalculation.quarterEndDateRange(year: 2025, quarter: 1)

        let p1Date = Date(timeIntervalSince1970: TimeInterval(period1))
        let p2Date = Date(timeIntervalSince1970: TimeInterval(period2))
        let calendar = Calendar.current

        // period1 should be around Mar 26
        XCTAssertEqual(calendar.component(.month, from: p1Date), 3)
        XCTAssertEqual(calendar.component(.day, from: p1Date), 26)

        // period2 should be around Apr 2
        XCTAssertEqual(calendar.component(.month, from: p2Date), 4)
        XCTAssertEqual(calendar.component(.day, from: p2Date), 2)
    }

    func testQuarterEndDateRange_Q2_2025_returnsJuneRange() {
        let (period1, period2) = QuarterCalculation.quarterEndDateRange(year: 2025, quarter: 2)

        let p1Date = Date(timeIntervalSince1970: TimeInterval(period1))
        let p2Date = Date(timeIntervalSince1970: TimeInterval(period2))
        let calendar = Calendar.current

        // June has 30 days; period1 around Jun 25
        XCTAssertEqual(calendar.component(.month, from: p1Date), 6)
        XCTAssertEqual(calendar.component(.day, from: p1Date), 25)

        // period2 around Jul 2
        XCTAssertEqual(calendar.component(.month, from: p2Date), 7)
        XCTAssertEqual(calendar.component(.day, from: p2Date), 2)
    }

    func testQuarterEndDateRange_Q3_2025_returnsSeptemberRange() {
        let (period1, period2) = QuarterCalculation.quarterEndDateRange(year: 2025, quarter: 3)

        let p1Date = Date(timeIntervalSince1970: TimeInterval(period1))
        let p2Date = Date(timeIntervalSince1970: TimeInterval(period2))
        let calendar = Calendar.current

        // September has 30 days; period1 around Sep 25
        XCTAssertEqual(calendar.component(.month, from: p1Date), 9)
        XCTAssertEqual(calendar.component(.day, from: p1Date), 25)

        // period2 around Oct 2
        XCTAssertEqual(calendar.component(.month, from: p2Date), 10)
        XCTAssertEqual(calendar.component(.day, from: p2Date), 2)
    }

    // MARK: - quarterStartTimestamp

    func testQuarterStartTimestamp_Q1_returnsJan1() {
        let ts = QuarterCalculation.quarterStartTimestamp(year: 2025, quarter: 1)
        let date = Date(timeIntervalSince1970: TimeInterval(ts))
        let calendar = Calendar.current
        XCTAssertEqual(calendar.component(.year, from: date), 2025)
        XCTAssertEqual(calendar.component(.month, from: date), 1)
        XCTAssertEqual(calendar.component(.day, from: date), 1)
    }

    func testQuarterStartTimestamp_Q2_returnsApr1() {
        let ts = QuarterCalculation.quarterStartTimestamp(year: 2025, quarter: 2)
        let date = Date(timeIntervalSince1970: TimeInterval(ts))
        let calendar = Calendar.current
        XCTAssertEqual(calendar.component(.month, from: date), 4)
        XCTAssertEqual(calendar.component(.day, from: date), 1)
    }

    func testQuarterStartTimestamp_Q3_returnsJul1() {
        let ts = QuarterCalculation.quarterStartTimestamp(year: 2025, quarter: 3)
        let date = Date(timeIntervalSince1970: TimeInterval(ts))
        let calendar = Calendar.current
        XCTAssertEqual(calendar.component(.month, from: date), 7)
        XCTAssertEqual(calendar.component(.day, from: date), 1)
    }

    func testQuarterStartTimestamp_Q4_returnsOct1() {
        let ts = QuarterCalculation.quarterStartTimestamp(year: 2025, quarter: 4)
        let date = Date(timeIntervalSince1970: TimeInterval(ts))
        let calendar = Calendar.current
        XCTAssertEqual(calendar.component(.month, from: date), 10)
        XCTAssertEqual(calendar.component(.day, from: date), 1)
    }

    // MARK: - quarterIdentifier

    func testQuarterIdentifier_producesCorrectFormat() {
        XCTAssertEqual(QuarterCalculation.quarterIdentifier(year: 2025, quarter: 4), "Q4-2025")
        XCTAssertEqual(QuarterCalculation.quarterIdentifier(year: 2024, quarter: 1), "Q1-2024")
    }

    // MARK: - displayLabel

    func testDisplayLabel_producesShortFormat() {
        XCTAssertEqual(QuarterCalculation.displayLabel(year: 2025, quarter: 4), "Q4'25")
        XCTAssertEqual(QuarterCalculation.displayLabel(year: 2024, quarter: 1), "Q1'24")
        XCTAssertEqual(QuarterCalculation.displayLabel(year: 2000, quarter: 2), "Q2'00")
    }

    // MARK: - QuarterInfo equality

    func testQuarterInfo_equatable() {
        let a = QuarterInfo(identifier: "Q4-2025", displayLabel: "Q4'25", year: 2025, quarter: 4)
        let b = QuarterInfo(identifier: "Q4-2025", displayLabel: "Q4'25", year: 2025, quarter: 4)
        let c = QuarterInfo(identifier: "Q3-2025", displayLabel: "Q3'25", year: 2025, quarter: 3)

        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }
}

// MARK: - Quarterly Cache Manager Tests

final class QuarterlyCacheManagerTests: XCTestCase {

    private let testCacheDirectory = URL(fileURLWithPath: "/tmp/test-quarterly")
    private let testCacheFile = "/tmp/test-quarterly/quarterly-cache.json"

    // MARK: - Load Tests

    func testLoad_whenCacheDoesNotExist_cacheIsNil() async {
        let mockFS = MockFileSystem()
        let manager = QuarterlyCacheManager(
            fileSystem: mockFS,
            cacheDirectory: testCacheDirectory
        )

        await manager.load()

        let price = await manager.getPrice(symbol: "AAPL", quarter: "Q4-2025")
        XCTAssertNil(price)
    }

    func testLoad_whenCacheExists_loadsPrices() async {
        let mockFS = MockFileSystem()

        let cacheData = QuarterlyCacheData(
            lastUpdated: "2026-01-15",
            quarters: ["Q4-2025": ["AAPL": 254.23, "SPY": 681.92]]
        )
        let jsonData = try! JSONEncoder().encode(cacheData)
        mockFS.files[testCacheFile] = jsonData

        let manager = QuarterlyCacheManager(
            fileSystem: mockFS,
            cacheDirectory: testCacheDirectory
        )

        await manager.load()

        let aaplPrice = await manager.getPrice(symbol: "AAPL", quarter: "Q4-2025")
        let spyPrice = await manager.getPrice(symbol: "SPY", quarter: "Q4-2025")

        XCTAssertEqual(aaplPrice, 254.23)
        XCTAssertEqual(spyPrice, 681.92)
    }

    func testLoad_whenInvalidJSON_cacheIsNil() async {
        let mockFS = MockFileSystem()
        mockFS.files[testCacheFile] = "invalid json".data(using: .utf8)!

        let manager = QuarterlyCacheManager(
            fileSystem: mockFS,
            cacheDirectory: testCacheDirectory
        )

        await manager.load()

        let price = await manager.getPrice(symbol: "AAPL", quarter: "Q4-2025")
        XCTAssertNil(price)
    }

    // MARK: - Save Tests

    func testSave_writesCacheToFile() async {
        let mockFS = MockFileSystem()
        let manager = QuarterlyCacheManager(
            fileSystem: mockFS,
            cacheDirectory: testCacheDirectory
        )

        await manager.setPrices(quarter: "Q4-2025", prices: ["AAPL": 254.23])
        await manager.save()

        let cacheURL = URL(fileURLWithPath: testCacheFile)
        XCTAssertNotNil(mockFS.writtenFiles[cacheURL])

        if let writtenData = mockFS.writtenFiles[cacheURL] {
            let decoded = try! JSONDecoder().decode(QuarterlyCacheData.self, from: writtenData)
            XCTAssertEqual(decoded.quarters["Q4-2025"]?["AAPL"], 254.23)
        }
    }

    func testSave_whenNilCache_doesNotWrite() async {
        let mockFS = MockFileSystem()
        let manager = QuarterlyCacheManager(
            fileSystem: mockFS,
            cacheDirectory: testCacheDirectory
        )

        await manager.save()

        let cacheURL = URL(fileURLWithPath: testCacheFile)
        XCTAssertNil(mockFS.writtenFiles[cacheURL])
    }

    // MARK: - SetPrices Tests

    func testSetPrices_multipleQuarters() async {
        let mockFS = MockFileSystem()
        let manager = QuarterlyCacheManager(
            fileSystem: mockFS,
            cacheDirectory: testCacheDirectory
        )

        await manager.setPrices(quarter: "Q4-2025", prices: ["AAPL": 254.23])
        await manager.setPrices(quarter: "Q3-2025", prices: ["AAPL": 220.00, "SPY": 550.00])

        let q4Price = await manager.getPrice(symbol: "AAPL", quarter: "Q4-2025")
        let q3AaplPrice = await manager.getPrice(symbol: "AAPL", quarter: "Q3-2025")
        let q3SpyPrice = await manager.getPrice(symbol: "SPY", quarter: "Q3-2025")

        XCTAssertEqual(q4Price, 254.23)
        XCTAssertEqual(q3AaplPrice, 220.00)
        XCTAssertEqual(q3SpyPrice, 550.00)
    }

    func testSetPrices_mergesWithExistingQuarterData() async {
        let mockFS = MockFileSystem()
        let manager = QuarterlyCacheManager(
            fileSystem: mockFS,
            cacheDirectory: testCacheDirectory
        )

        await manager.setPrices(quarter: "Q4-2025", prices: ["AAPL": 254.23])
        await manager.setPrices(quarter: "Q4-2025", prices: ["SPY": 681.92])

        let aaplPrice = await manager.getPrice(symbol: "AAPL", quarter: "Q4-2025")
        let spyPrice = await manager.getPrice(symbol: "SPY", quarter: "Q4-2025")

        XCTAssertEqual(aaplPrice, 254.23)
        XCTAssertEqual(spyPrice, 681.92)
    }

    // MARK: - GetAllQuarterPrices Tests

    func testGetAllQuarterPrices_returnsAllData() async {
        let mockFS = MockFileSystem()

        let cacheData = QuarterlyCacheData(
            lastUpdated: "2026-01-15",
            quarters: [
                "Q4-2025": ["AAPL": 254.23],
                "Q3-2025": ["SPY": 550.00]
            ]
        )
        let jsonData = try! JSONEncoder().encode(cacheData)
        mockFS.files[testCacheFile] = jsonData

        let manager = QuarterlyCacheManager(
            fileSystem: mockFS,
            cacheDirectory: testCacheDirectory
        )

        await manager.load()

        let allPrices = await manager.getAllQuarterPrices()
        XCTAssertEqual(allPrices.count, 2)
        XCTAssertEqual(allPrices["Q4-2025"]?["AAPL"], 254.23)
        XCTAssertEqual(allPrices["Q3-2025"]?["SPY"], 550.00)
    }

    func testGetAllQuarterPrices_whenEmpty_returnsEmptyDict() async {
        let mockFS = MockFileSystem()
        let manager = QuarterlyCacheManager(
            fileSystem: mockFS,
            cacheDirectory: testCacheDirectory
        )

        let allPrices = await manager.getAllQuarterPrices()
        XCTAssertTrue(allPrices.isEmpty)
    }

    // MARK: - GetMissingSymbols Tests

    func testGetMissingSymbols_returnsSymbolsNotInQuarter() async {
        let mockFS = MockFileSystem()
        let manager = QuarterlyCacheManager(
            fileSystem: mockFS,
            cacheDirectory: testCacheDirectory
        )

        await manager.setPrices(quarter: "Q4-2025", prices: ["AAPL": 254.23])

        let missing = await manager.getMissingSymbols(for: "Q4-2025", from: ["AAPL", "SPY", "QQQ"])
        XCTAssertEqual(Set(missing), Set(["SPY", "QQQ"]))
    }

    func testGetMissingSymbols_whenQuarterNotInCache_returnsAll() async {
        let mockFS = MockFileSystem()
        let manager = QuarterlyCacheManager(
            fileSystem: mockFS,
            cacheDirectory: testCacheDirectory
        )

        await manager.setPrices(quarter: "Q4-2025", prices: ["AAPL": 254.23])

        let missing = await manager.getMissingSymbols(for: "Q3-2025", from: ["AAPL", "SPY"])
        XCTAssertEqual(Set(missing), Set(["AAPL", "SPY"]))
    }

    func testGetMissingSymbols_whenCacheEmpty_returnsAllSymbols() async {
        let mockFS = MockFileSystem()
        let manager = QuarterlyCacheManager(
            fileSystem: mockFS,
            cacheDirectory: testCacheDirectory
        )

        let missing = await manager.getMissingSymbols(for: "Q4-2025", from: ["AAPL", "SPY"])
        XCTAssertEqual(Set(missing), Set(["AAPL", "SPY"]))
    }

    // MARK: - PruneOldQuarters Tests

    func testPruneOldQuarters_removesNonActiveQuarters() async {
        let mockFS = MockFileSystem()
        let manager = QuarterlyCacheManager(
            fileSystem: mockFS,
            cacheDirectory: testCacheDirectory
        )

        await manager.setPrices(quarter: "Q4-2025", prices: ["AAPL": 254.23])
        await manager.setPrices(quarter: "Q3-2025", prices: ["AAPL": 220.00])
        await manager.setPrices(quarter: "Q4-2023", prices: ["AAPL": 180.00])

        await manager.pruneOldQuarters(keeping: ["Q4-2025", "Q3-2025"])

        let q4Price = await manager.getPrice(symbol: "AAPL", quarter: "Q4-2025")
        let q3Price = await manager.getPrice(symbol: "AAPL", quarter: "Q3-2025")
        let oldPrice = await manager.getPrice(symbol: "AAPL", quarter: "Q4-2023")

        XCTAssertEqual(q4Price, 254.23)
        XCTAssertEqual(q3Price, 220.00)
        XCTAssertNil(oldPrice)
    }

    func testPruneOldQuarters_whenCacheNil_doesNothing() async {
        let mockFS = MockFileSystem()
        let manager = QuarterlyCacheManager(
            fileSystem: mockFS,
            cacheDirectory: testCacheDirectory
        )

        // Should not crash
        await manager.pruneOldQuarters(keeping: ["Q4-2025"])

        let allPrices = await manager.getAllQuarterPrices()
        XCTAssertTrue(allPrices.isEmpty)
    }

    // MARK: - DateProvider Injection Tests

    func testSetPrices_withMockDateProvider_updatesLastUpdated() async {
        let mockFS = MockFileSystem()
        let mockDateProvider = MockDateProvider(year: 2026, month: 6, day: 15)

        let manager = QuarterlyCacheManager(
            fileSystem: mockFS,
            dateProvider: mockDateProvider,
            cacheDirectory: testCacheDirectory
        )

        await manager.setPrices(quarter: "Q4-2025", prices: ["AAPL": 254.23])
        await manager.save()

        let cacheURL = URL(fileURLWithPath: testCacheFile)
        if let writtenData = mockFS.writtenFiles[cacheURL] {
            let decoded = try! JSONDecoder().decode(QuarterlyCacheData.self, from: writtenData)
            XCTAssertTrue(decoded.lastUpdated.contains("2026"))
        } else {
            XCTFail("Cache was not written")
        }
    }
}
