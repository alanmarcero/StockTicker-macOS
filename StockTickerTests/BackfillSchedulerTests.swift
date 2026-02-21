import XCTest
@testable import StockTicker

// MARK: - Tracking Mock Stock Service

private final class TrackingMockStockService: StockServiceProtocol, @unchecked Sendable {
    var ytdPricesToReturn: [String: Double] = [:]
    var dailyAnalysisToReturn: [String: DailyAnalysisResult] = [:]
    var emaEntriesToReturn: [String: EMACacheEntry] = [:]
    var forwardPERatiosToReturn: [String: [String: Double]] = [:]
    var quarterEndPricesToReturn: [String: Double] = [:]

    // Track call order
    private let lock = NSLock()
    private var _callLog: [(method: String, symbol: String)] = []
    var callLog: [(method: String, symbol: String)] {
        lock.lock()
        defer { lock.unlock() }
        return _callLog
    }
    private func log(_ method: String, _ symbol: String) {
        lock.lock()
        _callLog.append((method, symbol))
        lock.unlock()
    }

    func updateFinnhubApiKey(_ key: String?) async {}
    func fetchQuote(symbol: String) async -> StockQuote? { nil }
    func fetchQuotes(symbols: [String]) async -> [String: StockQuote] { [:] }
    func fetchMarketState(symbol: String) async -> String? { nil }
    func fetchQuoteFields(symbols: [String]) async -> (marketCaps: [String: Double], forwardPEs: [String: Double]) { ([:], [:]) }

    func fetchYTDStartPrice(symbol: String) async -> Double? {
        log("ytd", symbol)
        return ytdPricesToReturn[symbol]
    }

    func batchFetchYTDPrices(symbols: [String]) async -> [String: Double] { [:] }

    func fetchQuarterEndPrice(symbol: String, period1: Int, period2: Int) async -> Double? {
        log("quarterly", symbol)
        return quarterEndPricesToReturn[symbol]
    }

    func batchFetchQuarterEndPrices(symbols: [String], period1: Int, period2: Int) async -> [String: Double] { [:] }
    func fetchHighestClose(symbol: String, period1: Int, period2: Int) async -> Double? { nil }
    func batchFetchHighestCloses(symbols: [String], period1: Int, period2: Int) async -> [String: Double] { [:] }

    func fetchForwardPERatios(symbol: String, period1: Int, period2: Int) async -> [String: Double]? {
        log("forwardPE", symbol)
        return forwardPERatiosToReturn[symbol]
    }

    func batchFetchForwardPERatios(symbols: [String], period1: Int, period2: Int) async -> [String: [String: Double]] { [:] }
    func fetchSwingLevels(symbol: String, period1: Int, period2: Int) async -> SwingLevelCacheEntry? { nil }
    func batchFetchSwingLevels(symbols: [String], period1: Int, period2: Int) async -> [String: SwingLevelCacheEntry] { [:] }
    func fetchRSI(symbol: String) async -> Double? { nil }
    func batchFetchRSIValues(symbols: [String]) async -> [String: Double] { [:] }
    func fetchDailyEMA(symbol: String) async -> Double? { nil }
    func fetchWeeklyEMA(symbol: String) async -> Double? { nil }
    func batchFetchEMAValues(symbols: [String]) async -> [String: EMACacheEntry] { [:] }
    func batchFetchEMAValues(symbols: [String], dailyEMAs: [String: Double]) async -> [String: EMACacheEntry] { [:] }

    func fetchEMAEntry(symbol: String, precomputedDailyEMA: Double?) async -> EMACacheEntry? {
        log("weeklyEMA", symbol)
        return emaEntriesToReturn[symbol]
    }

    func fetchDailyAnalysis(symbol: String, period1: Int, period2: Int) async -> DailyAnalysisResult? {
        log("dailyAnalysis", symbol)
        return dailyAnalysisToReturn[symbol]
    }

    func batchFetchDailyAnalysis(symbols: [String], period1: Int, period2: Int) async -> [String: DailyAnalysisResult] { [:] }
    func fetchFinnhubQuotes(symbols: [String]) async -> [String: StockQuote] { [:] }
}

// MARK: - Tests

final class BackfillSchedulerTests: XCTestCase {

    private func makeCaches() -> BackfillCaches {
        let fs = MockFileSystem()
        let dp = MockDateProvider(year: 2026, month: 2, day: 15)
        return BackfillCaches(
            ytd: YTDCacheManager(fileSystem: fs, dateProvider: dp),
            quarterly: QuarterlyCacheManager(fileSystem: fs, dateProvider: dp),
            highestClose: HighestCloseCacheManager(fileSystem: fs, dateProvider: dp),
            forwardPE: ForwardPECacheManager(fileSystem: fs, dateProvider: dp),
            swingLevel: SwingLevelCacheManager(fileSystem: fs, dateProvider: dp),
            rsi: RSICacheManager(fileSystem: fs, dateProvider: dp),
            ema: EMACacheManager(fileSystem: fs, dateProvider: dp)
        )
    }

    private func makeQuarterInfos() -> [QuarterInfo] {
        QuarterCalculation.lastNCompletedQuarters(
            from: MockDateProvider(year: 2026, month: 2, day: 15).now(),
            count: 13
        )
    }

    // MARK: - Phase Ordering

    func testPhasesExecuteInOrder() async {
        let service = TrackingMockStockService()
        service.ytdPricesToReturn = ["AAPL": 150.0]
        service.dailyAnalysisToReturn = ["AAPL": DailyAnalysisResult(
            highestClose: 200.0, swingLevelEntry: nil, rsi: 55.0, dailyEMA: 160.0
        )]
        service.emaEntriesToReturn = ["AAPL": EMACacheEntry(day: 160.0, week: 155.0, weekCrossoverWeeksBelow: nil, weekBelowCount: nil)]
        service.forwardPERatiosToReturn = ["AAPL": ["Q4-2025": 28.0]]
        service.quarterEndPricesToReturn = ["AAPL": 180.0]

        let caches = makeCaches()
        let scheduler = BackfillScheduler()

        var phasesNotified: [BackfillScheduler.Phase] = []
        let lock = NSLock()

        await scheduler.start(
            symbols: ["AAPL"],
            extraStatsSymbols: ["AAPL"],
            quarterInfos: makeQuarterInfos(),
            period1: 1000000,
            period2: 2000000,
            forwardPEPeriod1: 1000000,
            stockService: service,
            caches: caches,
            delayBetweenCalls: 0,
            onBatchComplete: { phase in
                lock.lock()
                phasesNotified.append(phase)
                lock.unlock()
            }
        )

        // Wait for completion
        try? await Task.sleep(nanoseconds: 500_000_000)

        let log = service.callLog
        guard !log.isEmpty else {
            XCTFail("No API calls were made")
            return
        }

        // Verify phase ordering: ytd before dailyAnalysis before weeklyEMA before forwardPE before quarterly
        let methodOrder = log.map { $0.method }
        let phaseOrder: [String] = ["ytd", "dailyAnalysis", "weeklyEMA", "forwardPE", "quarterly"]

        var lastIndex = -1
        for phase in phaseOrder {
            if let idx = methodOrder.firstIndex(of: phase) {
                XCTAssertGreaterThan(idx, lastIndex, "\(phase) should come after previous phases")
                lastIndex = idx
            }
        }
    }

    // MARK: - Cached Symbols Skipped

    func testSkipsCachedSymbols() async {
        let service = TrackingMockStockService()
        service.ytdPricesToReturn = ["MSFT": 300.0]

        let caches = makeCaches()

        // Pre-populate AAPL in YTD cache
        await caches.ytd.setStartPrice(for: "AAPL", price: 150.0)

        let scheduler = BackfillScheduler()

        await scheduler.start(
            symbols: ["AAPL", "MSFT"],
            extraStatsSymbols: ["AAPL", "MSFT"],
            quarterInfos: [],
            period1: 1000000,
            period2: 2000000,
            forwardPEPeriod1: 1000000,
            stockService: service,
            caches: caches,
            delayBetweenCalls: 0,
            onBatchComplete: { _ in }
        )

        try? await Task.sleep(nanoseconds: 500_000_000)

        let ytdCalls = service.callLog.filter { $0.method == "ytd" }
        let symbols = ytdCalls.map { $0.symbol }
        XCTAssertTrue(symbols.contains("MSFT"), "Should fetch missing MSFT")
        XCTAssertFalse(symbols.contains("AAPL"), "Should skip cached AAPL")
    }

    // MARK: - Cancellation

    func testCancellationStopsFetching() async {
        let service = TrackingMockStockService()
        // Return data for many symbols to ensure multiple calls needed
        for i in 0..<50 {
            service.ytdPricesToReturn["SYM\(i)"] = Double(i + 100)
        }

        let caches = makeCaches()
        let scheduler = BackfillScheduler()
        let symbols = (0..<50).map { "SYM\($0)" }

        await scheduler.start(
            symbols: symbols,
            extraStatsSymbols: symbols,
            quarterInfos: makeQuarterInfos(),
            period1: 1000000,
            period2: 2000000,
            forwardPEPeriod1: 1000000,
            stockService: service,
            caches: caches,
            delayBetweenCalls: 0,
            onBatchComplete: { _ in }
        )

        // Cancel after a brief moment
        try? await Task.sleep(nanoseconds: 500_000_000)
        await scheduler.cancel()

        let callCountAtCancel = service.callLog.count
        try? await Task.sleep(nanoseconds: 1_000_000_000)

        // No more calls after cancellation
        XCTAssertEqual(service.callLog.count, callCountAtCancel, "No more calls should happen after cancel")
        let isRunning = await scheduler.isRunning
        XCTAssertFalse(isRunning, "Scheduler should not be running after cancel")
    }

    // MARK: - Batch Notification

    func testBatchNotificationFires() async {
        let service = TrackingMockStockService()
        for i in 0..<15 {
            service.ytdPricesToReturn["SYM\(i)"] = Double(i + 100)
        }

        let caches = makeCaches()
        let scheduler = BackfillScheduler()
        let symbols = (0..<15).map { "SYM\($0)" }

        var notificationCount = 0
        let lock = NSLock()

        await scheduler.start(
            symbols: symbols,
            extraStatsSymbols: [],
            quarterInfos: [],
            period1: 1000000,
            period2: 2000000,
            forwardPEPeriod1: 1000000,
            stockService: service,
            caches: caches,
            delayBetweenCalls: 0,
            onBatchComplete: { phase in
                guard phase == .ytd else { return }
                lock.lock()
                notificationCount += 1
                lock.unlock()
            }
        )

        // Wait for YTD phase to complete (15 symbols × ~4s delay — but test won't actually sleep 4s due to Task.sleep)
        try? await Task.sleep(nanoseconds: 500_000_000)

        lock.lock()
        let count = notificationCount
        lock.unlock()

        // 15 symbols: batch notification at 10, then final notification = 2 notifications
        XCTAssertGreaterThanOrEqual(count, 1, "Should receive at least one batch notification")
    }

    // MARK: - Daily Analysis Distributes to Caches

    func testDailyAnalysisDistributesToCaches() async {
        let service = TrackingMockStockService()
        service.dailyAnalysisToReturn = ["AAPL": DailyAnalysisResult(
            highestClose: 250.0,
            swingLevelEntry: SwingLevelCacheEntry(breakoutPrice: 240.0, breakoutDate: "1/15/26", breakdownPrice: 180.0, breakdownDate: "6/15/25"),
            rsi: 62.5,
            dailyEMA: 195.0
        )]

        let caches = makeCaches()
        let scheduler = BackfillScheduler()

        await scheduler.start(
            symbols: ["AAPL"],
            extraStatsSymbols: [],
            quarterInfos: [],
            period1: 1000000,
            period2: 2000000,
            forwardPEPeriod1: 1000000,
            stockService: service,
            caches: caches,
            delayBetweenCalls: 0,
            onBatchComplete: { _ in }
        )

        try? await Task.sleep(nanoseconds: 500_000_000)

        let highest = await caches.highestClose.getHighestClose(for: "AAPL")
        XCTAssertEqual(highest, 250.0)

        let swing = await caches.swingLevel.getEntry(for: "AAPL")
        XCTAssertEqual(swing?.breakoutPrice, 240.0)

        let rsi = await caches.rsi.getRSI(for: "AAPL")
        XCTAssertEqual(rsi, 62.5)

        // Daily EMA stored as partial entry (week nil)
        let ema = await caches.ema.getEntry(for: "AAPL")
        XCTAssertEqual(ema?.day, 195.0)
        XCTAssertNil(ema?.week)
    }

    // MARK: - Weekly EMA Completes Partial Entries

    func testWeeklyEMACompletesPartialEntries() async {
        let service = TrackingMockStockService()
        service.emaEntriesToReturn = ["AAPL": EMACacheEntry(day: 195.0, week: 190.0, weekCrossoverWeeksBelow: nil, weekBelowCount: nil)]

        let caches = makeCaches()

        // Pre-populate partial daily EMA entry from daily analysis phase
        await caches.ema.setEntry(for: "AAPL", entry: EMACacheEntry(day: 195.0, week: nil, weekCrossoverWeeksBelow: nil, weekBelowCount: nil))

        let scheduler = BackfillScheduler()

        await scheduler.start(
            symbols: ["AAPL"],
            extraStatsSymbols: [],
            quarterInfos: [],
            period1: 1000000,
            period2: 2000000,
            forwardPEPeriod1: 1000000,
            stockService: service,
            caches: caches,
            delayBetweenCalls: 0,
            onBatchComplete: { _ in }
        )

        try? await Task.sleep(nanoseconds: 500_000_000)

        let ema = await caches.ema.getEntry(for: "AAPL")
        XCTAssertEqual(ema?.day, 195.0)
        XCTAssertEqual(ema?.week, 190.0)
    }

    // MARK: - Empty Symbols No-Op

    func testEmptySymbolsCompletesImmediately() async {
        let service = TrackingMockStockService()
        let caches = makeCaches()
        let scheduler = BackfillScheduler()

        await scheduler.start(
            symbols: [],
            extraStatsSymbols: [],
            quarterInfos: [],
            period1: 1000000,
            period2: 2000000,
            forwardPEPeriod1: 1000000,
            stockService: service,
            caches: caches,
            delayBetweenCalls: 0,
            onBatchComplete: { _ in }
        )

        try? await Task.sleep(nanoseconds: 500_000_000)
        XCTAssertTrue(service.callLog.isEmpty, "No API calls for empty symbols")
    }

    // MARK: - Restart Cancels Previous

    func testStartCancelsPrevious() async {
        let service = TrackingMockStockService()
        for i in 0..<50 {
            service.ytdPricesToReturn["SYM\(i)"] = Double(i + 100)
        }

        let caches = makeCaches()
        let scheduler = BackfillScheduler()
        let symbols = (0..<50).map { "SYM\($0)" }

        // Start first run
        await scheduler.start(
            symbols: symbols,
            extraStatsSymbols: [],
            quarterInfos: [],
            period1: 1000000,
            period2: 2000000,
            forwardPEPeriod1: 1000000,
            stockService: service,
            caches: caches,
            delayBetweenCalls: 0,
            onBatchComplete: { _ in }
        )

        try? await Task.sleep(nanoseconds: 200_000_000)

        // Start second run (should cancel first)
        await scheduler.start(
            symbols: ["ONLY"],
            extraStatsSymbols: [],
            quarterInfos: [],
            period1: 1000000,
            period2: 2000000,
            forwardPEPeriod1: 1000000,
            stockService: service,
            caches: caches,
            delayBetweenCalls: 0,
            onBatchComplete: { _ in }
        )

        let isRunning = await scheduler.isRunning
        XCTAssertTrue(isRunning, "Scheduler should be running with new task")
    }
}
