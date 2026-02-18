import XCTest
@testable import StockTicker

// MARK: - Mock Stock Service

final class MockStockService: StockServiceProtocol, @unchecked Sendable {
    var quotesToReturn: [String: StockQuote] = [:]
    var marketStateToReturn: String? = "REGULAR"
    var marketCapsToReturn: [String: Double] = [:]
    var forwardPEsToReturn: [String: Double] = [:]
    var ytdPricesToReturn: [String: Double] = [:]
    var quarterEndPricesToReturn: [String: Double] = [:]
    var highestClosesToReturn: [String: Double] = [:]
    var forwardPERatiosToReturn: [String: [String: Double]] = [:]
    var swingLevelsToReturn: [String: SwingLevelCacheEntry] = [:]
    var rsiValuesToReturn: [String: Double] = [:]
    var emaEntriesToReturn: [String: EMACacheEntry] = [:]
    var dailyAnalysisToReturn: [String: DailyAnalysisResult] = [:]

    var fetchQuotesCalled: [[String]] = []
    var fetchMarketStateCalled: [String] = []

    func fetchQuote(symbol: String) async -> StockQuote? {
        quotesToReturn[symbol]
    }

    func fetchQuotes(symbols: [String]) async -> [String: StockQuote] {
        fetchQuotesCalled.append(symbols)
        return quotesToReturn.filter { symbols.contains($0.key) }
    }

    func fetchMarketState(symbol: String) async -> String? {
        fetchMarketStateCalled.append(symbol)
        return marketStateToReturn
    }

    func fetchQuoteFields(symbols: [String]) async -> (marketCaps: [String: Double], forwardPEs: [String: Double]) {
        let caps = marketCapsToReturn.filter { symbols.contains($0.key) }
        let pes = forwardPEsToReturn.filter { symbols.contains($0.key) }
        return (caps, pes)
    }

    func fetchYTDStartPrice(symbol: String) async -> Double? {
        ytdPricesToReturn[symbol]
    }

    func batchFetchYTDPrices(symbols: [String]) async -> [String: Double] {
        ytdPricesToReturn.filter { symbols.contains($0.key) }
    }

    func fetchQuarterEndPrice(symbol: String, period1: Int, period2: Int) async -> Double? {
        quarterEndPricesToReturn[symbol]
    }

    func batchFetchQuarterEndPrices(symbols: [String], period1: Int, period2: Int) async -> [String: Double] {
        quarterEndPricesToReturn.filter { symbols.contains($0.key) }
    }

    func fetchHighestClose(symbol: String, period1: Int, period2: Int) async -> Double? {
        highestClosesToReturn[symbol]
    }

    func batchFetchHighestCloses(symbols: [String], period1: Int, period2: Int) async -> [String: Double] {
        highestClosesToReturn.filter { symbols.contains($0.key) }
    }

    func fetchForwardPERatios(symbol: String, period1: Int, period2: Int) async -> [String: Double]? {
        forwardPERatiosToReturn[symbol]
    }

    func batchFetchForwardPERatios(symbols: [String], period1: Int, period2: Int) async -> [String: [String: Double]] {
        var result: [String: [String: Double]] = [:]
        for symbol in symbols {
            result[symbol] = forwardPERatiosToReturn[symbol] ?? [:]
        }
        return result
    }

    func fetchSwingLevels(symbol: String, period1: Int, period2: Int) async -> SwingLevelCacheEntry? {
        swingLevelsToReturn[symbol]
    }

    func batchFetchSwingLevels(symbols: [String], period1: Int, period2: Int) async -> [String: SwingLevelCacheEntry] {
        swingLevelsToReturn.filter { symbols.contains($0.key) }
    }

    func fetchRSI(symbol: String) async -> Double? {
        rsiValuesToReturn[symbol]
    }

    func batchFetchRSIValues(symbols: [String]) async -> [String: Double] {
        rsiValuesToReturn.filter { symbols.contains($0.key) }
    }

    func fetchDailyEMA(symbol: String) async -> Double? {
        emaEntriesToReturn[symbol]?.day
    }

    func fetchWeeklyEMA(symbol: String) async -> Double? {
        emaEntriesToReturn[symbol]?.week
    }

    func fetchMonthlyEMA(symbol: String) async -> Double? {
        emaEntriesToReturn[symbol]?.month
    }

    func batchFetchEMAValues(symbols: [String]) async -> [String: EMACacheEntry] {
        emaEntriesToReturn.filter { symbols.contains($0.key) }
    }

    func batchFetchEMAValues(symbols: [String], dailyEMAs: [String: Double]) async -> [String: EMACacheEntry] {
        emaEntriesToReturn.filter { symbols.contains($0.key) }
    }

    func fetchDailyAnalysis(symbol: String, period1: Int, period2: Int) async -> DailyAnalysisResult? {
        dailyAnalysisToReturn[symbol]
    }

    func batchFetchDailyAnalysis(symbols: [String], period1: Int, period2: Int) async -> [String: DailyAnalysisResult] {
        dailyAnalysisToReturn.filter { symbols.contains($0.key) }
    }
}

// MARK: - Tests

final class QuoteFetchCoordinatorTests: XCTestCase {

    // MARK: - ensureClosedMarketSymbol

    func testEnsureClosedMarketSymbol_addsWhenMissing() {
        let result = QuoteFetchCoordinator.ensureClosedMarketSymbol("BTC-USD", in: ["AAPL", "MSFT"])
        XCTAssertEqual(result, ["AAPL", "MSFT", "BTC-USD"])
    }

    func testEnsureClosedMarketSymbol_doesNotDuplicate() {
        let result = QuoteFetchCoordinator.ensureClosedMarketSymbol("AAPL", in: ["AAPL", "MSFT"])
        XCTAssertEqual(result, ["AAPL", "MSFT"])
    }

    // MARK: - fetchInitialLoad

    func testFetchInitialLoad_returnsAllData() async {
        let mock = MockStockService()
        let aapl = StockQuote(symbol: "AAPL", price: 150.0, previousClose: 145.0, yahooMarketState: "REGULAR")
        let spy = StockQuote(symbol: "SPY", price: 500.0, previousClose: 495.0, yahooMarketState: "REGULAR")
        let btc = StockQuote(symbol: "BTC-USD", price: 60000.0, previousClose: 59000.0)
        mock.quotesToReturn = ["AAPL": aapl, "SPY": spy, "BTC-USD": btc]

        let result = await QuoteFetchCoordinator.fetchInitialLoad(
            service: mock, watchlist: ["AAPL", "SPY"],
            indexSymbols: ["SPY"], alwaysOpenSymbols: ["BTC-USD"],
            closedMarketSymbol: "BTC-USD", isWeekend: false
        )

        XCTAssertNotNil(result.quotes["AAPL"])
        XCTAssertNotNil(result.indexQuotes["SPY"])
        XCTAssertNotNil(result.indexQuotes["BTC-USD"])
        XCTAssertEqual(result.yahooMarketState, "REGULAR")
        XCTAssertTrue(result.isInitialLoadComplete)
        XCTAssertFalse(result.shouldMergeQuotes)
    }

    func testFetchInitialLoad_weekendForcesClosed() async {
        let mock = MockStockService()
        let spy = StockQuote(symbol: "SPY", price: 500.0, previousClose: 495.0, yahooMarketState: "POST")
        mock.quotesToReturn = ["AAPL": StockQuote(symbol: "AAPL", price: 150.0, previousClose: 145.0), "SPY": spy]

        let result = await QuoteFetchCoordinator.fetchInitialLoad(
            service: mock, watchlist: ["AAPL", "SPY"],
            indexSymbols: [], alwaysOpenSymbols: [],
            closedMarketSymbol: "BTC-USD", isWeekend: true
        )

        XCTAssertEqual(result.yahooMarketState, "CLOSED")
    }

    func testFetchInitialLoad_ensuresClosedMarketSymbol() async {
        let mock = MockStockService()
        let btc = StockQuote(symbol: "BTC-USD", price: 60000.0, previousClose: 59000.0)
        mock.quotesToReturn = ["BTC-USD": btc]

        let result = await QuoteFetchCoordinator.fetchInitialLoad(
            service: mock, watchlist: ["AAPL"],
            indexSymbols: [], alwaysOpenSymbols: [],
            closedMarketSymbol: "BTC-USD", isWeekend: false
        )

        XCTAssertTrue(result.fetchedSymbols.contains("BTC-USD"))
        XCTAssertTrue(result.fetchedSymbols.contains("AAPL"))
    }

    // MARK: - fetchClosedMarket

    func testFetchClosedMarket_returnsMergeFlag() async {
        let mock = MockStockService()
        let btc = StockQuote(symbol: "BTC-USD", price: 60000.0, previousClose: 59000.0)
        mock.quotesToReturn = ["BTC-USD": btc]

        let result = await QuoteFetchCoordinator.fetchClosedMarket(
            service: mock, closedMarketSymbol: "BTC-USD",
            alwaysOpenSymbols: []
        )

        XCTAssertTrue(result.shouldMergeQuotes)
        XCTAssertEqual(result.yahooMarketState, "CLOSED")
        XCTAssertFalse(result.isInitialLoadComplete)
    }

    func testFetchClosedMarket_includesAlwaysOpenSymbols() async {
        let mock = MockStockService()
        let btc = StockQuote(symbol: "BTC-USD", price: 60000.0, previousClose: 59000.0)
        let eth = StockQuote(symbol: "ETH-USD", price: 3000.0, previousClose: 2900.0)
        mock.quotesToReturn = ["BTC-USD": btc, "ETH-USD": eth]

        let result = await QuoteFetchCoordinator.fetchClosedMarket(
            service: mock, closedMarketSymbol: "BTC-USD",
            alwaysOpenSymbols: ["ETH-USD"]
        )

        XCTAssertTrue(result.fetchedSymbols.contains("BTC-USD"))
        XCTAssertTrue(result.fetchedSymbols.contains("ETH-USD"))
        XCTAssertNotNil(result.quotes["ETH-USD"])
    }

    // MARK: - fetchRegularSession

    func testFetchRegularSession_returnsCorrectData() async {
        let mock = MockStockService()
        let aapl = StockQuote(symbol: "AAPL", price: 150.0, previousClose: 145.0)
        let spy = StockQuote(symbol: "SPY", price: 500.0, previousClose: 495.0, yahooMarketState: "REGULAR")
        mock.quotesToReturn = ["AAPL": aapl, "SPY": spy]

        let result = await QuoteFetchCoordinator.fetchRegularSession(
            service: mock, watchlist: ["AAPL", "SPY"],
            indexSymbols: ["SPY"], closedMarketSymbol: "BTC-USD"
        )

        XCTAssertNotNil(result.quotes["AAPL"])
        XCTAssertNotNil(result.indexQuotes["SPY"])
        XCTAssertEqual(result.yahooMarketState, "REGULAR")
        XCTAssertFalse(result.shouldMergeQuotes)
        XCTAssertFalse(result.isInitialLoadComplete)
    }

    // MARK: - fetchExtendedHours

    func testFetchExtendedHours_returnsCorrectData() async {
        let mock = MockStockService()
        let aapl = StockQuote(symbol: "AAPL", price: 150.0, previousClose: 145.0)
        let spy = StockQuote(symbol: "SPY", price: 500.0, previousClose: 495.0, yahooMarketState: "POST")
        let btc = StockQuote(symbol: "BTC-USD", price: 60000.0, previousClose: 59000.0)
        mock.quotesToReturn = ["AAPL": aapl, "SPY": spy, "BTC-USD": btc]

        let result = await QuoteFetchCoordinator.fetchExtendedHours(
            service: mock, watchlist: ["AAPL", "SPY"],
            alwaysOpenSymbols: ["BTC-USD"], closedMarketSymbol: "BTC-USD"
        )

        XCTAssertNotNil(result.quotes["AAPL"])
        XCTAssertNotNil(result.indexQuotes["BTC-USD"])
        XCTAssertEqual(result.yahooMarketState, "POST")
        XCTAssertFalse(result.shouldMergeQuotes)
        XCTAssertFalse(result.isInitialLoadComplete)
    }

    // MARK: - extractMarketState

    func testExtractMarketState_fromSPYQuote() {
        let spy = StockQuote(symbol: "SPY", price: 500.0, previousClose: 495.0, yahooMarketState: "REGULAR")
        let quotes: [String: StockQuote] = ["SPY": spy, "AAPL": StockQuote(symbol: "AAPL", price: 150.0, previousClose: 145.0)]

        XCTAssertEqual(QuoteFetchCoordinator.extractMarketState(from: quotes), "REGULAR")
    }

    func testExtractMarketState_nilWhenSPYMissing() {
        let quotes: [String: StockQuote] = ["AAPL": StockQuote(symbol: "AAPL", price: 150.0, previousClose: 145.0)]

        XCTAssertNil(QuoteFetchCoordinator.extractMarketState(from: quotes))
    }

    func testExtractMarketState_nilWhenNoYahooState() {
        let spy = StockQuote(symbol: "SPY", price: 500.0, previousClose: 495.0)
        let quotes: [String: StockQuote] = ["SPY": spy]

        XCTAssertNil(QuoteFetchCoordinator.extractMarketState(from: quotes))
    }

    func testFetchInitialLoad_fallsBackToIndexQuotesForMarketState() async {
        let mock = MockStockService()
        let aapl = StockQuote(symbol: "AAPL", price: 150.0, previousClose: 145.0)
        let spy = StockQuote(symbol: "SPY", price: 500.0, previousClose: 495.0, yahooMarketState: "REGULAR")
        mock.quotesToReturn = ["AAPL": aapl, "SPY": spy]

        let result = await QuoteFetchCoordinator.fetchInitialLoad(
            service: mock, watchlist: ["AAPL"],
            indexSymbols: ["SPY"], alwaysOpenSymbols: [],
            closedMarketSymbol: "BTC-USD", isWeekend: false
        )

        // SPY is in indexSymbols, not watchlist — market state should still be extracted
        XCTAssertEqual(result.yahooMarketState, "REGULAR")
    }
}
