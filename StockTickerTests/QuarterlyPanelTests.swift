import XCTest
@testable import StockTicker

// MARK: - Quarterly Panel View Model Tests

@MainActor
final class QuarterlyPanelViewModelTests: XCTestCase {

    private let testQuarters = [
        QuarterInfo(identifier: "Q4-2025", displayLabel: "Q4'25", year: 2025, quarter: 4),
        QuarterInfo(identifier: "Q3-2025", displayLabel: "Q3'25", year: 2025, quarter: 3),
        QuarterInfo(identifier: "Q2-2025", displayLabel: "Q2'25", year: 2025, quarter: 2),
    ]

    private func makeQuote(symbol: String, price: Double) -> StockQuote {
        StockQuote(symbol: symbol, price: price, previousClose: price * 0.99)
    }

    // MARK: - Row Computation

    func testUpdate_computesPercentChanges() {
        let vm = QuarterlyPanelViewModel()

        let quotes: [String: StockQuote] = [
            "AAPL": makeQuote(symbol: "AAPL", price: 200.0)
        ]
        let quarterPrices: [String: [String: Double]] = [
            "Q4-2025": ["AAPL": 180.0],  // (200-180)/180 * 100 = 11.11%
            "Q3-2025": ["AAPL": 160.0],  // (200-160)/160 * 100 = 25.0%
            "Q2-2025": ["AAPL": 200.0],  // (200-200)/200 * 100 = 0.0%
        ]

        vm.update(watchlist: ["AAPL"], quotes: quotes, quarterPrices: quarterPrices, quarterInfos: testQuarters)

        XCTAssertEqual(vm.rows.count, 1)

        let row = vm.rows[0]
        XCTAssertEqual(row.symbol, "AAPL")

        let q4Change = row.quarterChanges["Q4-2025"] ?? nil
        XCTAssertNotNil(q4Change)
        XCTAssertEqual(q4Change!, 11.11, accuracy: 0.01)

        let q3Change = row.quarterChanges["Q3-2025"] ?? nil
        XCTAssertNotNil(q3Change)
        XCTAssertEqual(q3Change!, 25.0, accuracy: 0.01)

        let q2Change = row.quarterChanges["Q2-2025"] ?? nil
        XCTAssertNotNil(q2Change)
        XCTAssertEqual(q2Change!, 0.0, accuracy: 0.01)
    }

    func testUpdate_missingQuarterPrice_showsNil() {
        let vm = QuarterlyPanelViewModel()

        let quotes: [String: StockQuote] = [
            "NEW": makeQuote(symbol: "NEW", price: 50.0)
        ]
        let quarterPrices: [String: [String: Double]] = [
            "Q4-2025": [:],  // No price for NEW
        ]

        vm.update(watchlist: ["NEW"], quotes: quotes, quarterPrices: quarterPrices, quarterInfos: testQuarters)

        let row = vm.rows[0]
        let q4Change = row.quarterChanges["Q4-2025"] ?? nil
        XCTAssertNil(q4Change)
    }

    func testUpdate_missingQuote_showsNil() {
        let vm = QuarterlyPanelViewModel()

        let quotes: [String: StockQuote] = [:]  // No quotes at all
        let quarterPrices: [String: [String: Double]] = [
            "Q4-2025": ["MISSING": 100.0],
        ]

        vm.update(watchlist: ["MISSING"], quotes: quotes, quarterPrices: quarterPrices, quarterInfos: testQuarters)

        let row = vm.rows[0]
        let q4Change = row.quarterChanges["Q4-2025"] ?? nil
        XCTAssertNil(q4Change)
    }

    func testUpdate_placeholderQuote_showsNil() {
        let vm = QuarterlyPanelViewModel()

        let quotes: [String: StockQuote] = [
            "BAD": StockQuote.placeholder(symbol: "BAD")
        ]
        let quarterPrices: [String: [String: Double]] = [
            "Q4-2025": ["BAD": 100.0],
        ]

        vm.update(watchlist: ["BAD"], quotes: quotes, quarterPrices: quarterPrices, quarterInfos: testQuarters)

        let row = vm.rows[0]
        let q4Change = row.quarterChanges["Q4-2025"] ?? nil
        XCTAssertNil(q4Change)
    }

    func testUpdate_multipleSymbols_createsRows() {
        let vm = QuarterlyPanelViewModel()

        let quotes: [String: StockQuote] = [
            "AAPL": makeQuote(symbol: "AAPL", price: 200.0),
            "SPY": makeQuote(symbol: "SPY", price: 500.0),
        ]
        let quarterPrices: [String: [String: Double]] = [
            "Q4-2025": ["AAPL": 180.0, "SPY": 450.0],
        ]

        vm.update(watchlist: ["AAPL", "SPY"], quotes: quotes, quarterPrices: quarterPrices, quarterInfos: testQuarters)

        XCTAssertEqual(vm.rows.count, 2)
    }

    // MARK: - Sorting

    func testSort_bySymbol_defaultAscending() {
        let vm = QuarterlyPanelViewModel()

        let quotes: [String: StockQuote] = [
            "AAPL": makeQuote(symbol: "AAPL", price: 200.0),
            "SPY": makeQuote(symbol: "SPY", price: 500.0),
            "MSFT": makeQuote(symbol: "MSFT", price: 400.0),
        ]
        let quarterPrices: [String: [String: Double]] = [:]

        // Default sort is .symbol ascending — applied during update()
        vm.update(watchlist: ["SPY", "AAPL", "MSFT"], quotes: quotes, quarterPrices: quarterPrices, quarterInfos: testQuarters)

        XCTAssertEqual(vm.rows[0].symbol, "AAPL")
        XCTAssertEqual(vm.rows[1].symbol, "MSFT")
        XCTAssertEqual(vm.rows[2].symbol, "SPY")
        XCTAssertTrue(vm.sortAscending)
    }

    func testSort_bySymbol_togglesDirection() {
        let vm = QuarterlyPanelViewModel()

        let quotes: [String: StockQuote] = [
            "AAPL": makeQuote(symbol: "AAPL", price: 200.0),
            "SPY": makeQuote(symbol: "SPY", price: 500.0),
        ]

        vm.update(watchlist: ["AAPL", "SPY"], quotes: quotes, quarterPrices: [:], quarterInfos: testQuarters)

        // Default is .symbol ascending; first click toggles to descending
        vm.sort(by: .symbol)
        XCTAssertFalse(vm.sortAscending)
        XCTAssertEqual(vm.rows[0].symbol, "SPY")
        XCTAssertEqual(vm.rows[1].symbol, "AAPL")

        // Second click toggles back to ascending
        vm.sort(by: .symbol)
        XCTAssertTrue(vm.sortAscending)
        XCTAssertEqual(vm.rows[0].symbol, "AAPL")
        XCTAssertEqual(vm.rows[1].symbol, "SPY")
    }

    func testSort_byQuarterColumn() {
        let vm = QuarterlyPanelViewModel()

        let quotes: [String: StockQuote] = [
            "AAPL": makeQuote(symbol: "AAPL", price: 200.0),
            "SPY": makeQuote(symbol: "SPY", price: 500.0),
        ]
        let quarterPrices: [String: [String: Double]] = [
            "Q4-2025": ["AAPL": 180.0, "SPY": 550.0],  // AAPL +11.11%, SPY -9.09%
        ]

        vm.update(watchlist: ["AAPL", "SPY"], quotes: quotes, quarterPrices: quarterPrices, quarterInfos: testQuarters)

        vm.sort(by: .quarter("Q4-2025"))

        // Ascending: SPY (-9.09%) < AAPL (+11.11%)
        XCTAssertEqual(vm.rows[0].symbol, "SPY")
        XCTAssertEqual(vm.rows[1].symbol, "AAPL")
    }

    func testSort_switchingColumn_resetsToAscending() {
        let vm = QuarterlyPanelViewModel()

        let quotes: [String: StockQuote] = [
            "AAPL": makeQuote(symbol: "AAPL", price: 200.0),
            "SPY": makeQuote(symbol: "SPY", price: 500.0),
        ]

        vm.update(watchlist: ["AAPL", "SPY"], quotes: quotes, quarterPrices: [:], quarterInfos: testQuarters)

        // Default is .symbol ascending; first click toggles to descending
        vm.sort(by: .symbol)
        XCTAssertFalse(vm.sortAscending)

        // Switching to a different column resets to ascending
        vm.sort(by: .quarter("Q4-2025"))
        XCTAssertTrue(vm.sortAscending)
    }

    func testSort_nilValues_sortFirst() {
        let vm = QuarterlyPanelViewModel()

        let quotes: [String: StockQuote] = [
            "AAPL": makeQuote(symbol: "AAPL", price: 200.0),
            "NEW": makeQuote(symbol: "NEW", price: 50.0),
        ]
        let quarterPrices: [String: [String: Double]] = [
            "Q4-2025": ["AAPL": 180.0],  // NEW has no Q4 price
        ]

        vm.update(watchlist: ["AAPL", "NEW"], quotes: quotes, quarterPrices: quarterPrices, quarterInfos: testQuarters)

        vm.sort(by: .quarter("Q4-2025"))

        // nil sorts before any value in ascending
        XCTAssertEqual(vm.rows[0].symbol, "NEW")
        XCTAssertEqual(vm.rows[1].symbol, "AAPL")
    }

    // MARK: - Highest Close in Rows

    func testUpdate_includesHighestCloseChangePercent() {
        let vm = QuarterlyPanelViewModel()

        let quotes: [String: StockQuote] = [
            "AAPL": makeQuote(symbol: "AAPL", price: 150.0),
        ]
        let highestClosePrices: [String: Double] = ["AAPL": 200.0]

        vm.update(watchlist: ["AAPL"], quotes: quotes, quarterPrices: [:], quarterInfos: testQuarters, highestClosePrices: highestClosePrices)

        let row = vm.rows[0]
        // (150-200)/200 * 100 = -25%
        XCTAssertNotNil(row.highestCloseChangePercent)
        XCTAssertEqual(row.highestCloseChangePercent!, -25.0, accuracy: 0.01)
    }

    func testUpdate_highestCloseNilWhenMissing() {
        let vm = QuarterlyPanelViewModel()

        let quotes: [String: StockQuote] = [
            "AAPL": makeQuote(symbol: "AAPL", price: 150.0),
        ]

        vm.update(watchlist: ["AAPL"], quotes: quotes, quarterPrices: [:], quarterInfos: testQuarters)

        let row = vm.rows[0]
        XCTAssertNil(row.highestCloseChangePercent)
    }

    func testSort_byHighestClose() {
        let vm = QuarterlyPanelViewModel()

        let quotes: [String: StockQuote] = [
            "AAPL": makeQuote(symbol: "AAPL", price: 150.0),
            "SPY": makeQuote(symbol: "SPY", price: 500.0),
        ]
        // AAPL: (150-200)/200 = -25%, SPY: (500-450)/450 = +11.11%
        let highestClosePrices: [String: Double] = ["AAPL": 200.0, "SPY": 450.0]

        vm.update(watchlist: ["AAPL", "SPY"], quotes: quotes, quarterPrices: [:], quarterInfos: testQuarters, highestClosePrices: highestClosePrices)

        vm.sort(by: .highestClose)

        // Ascending: AAPL (-25%) < SPY (+11.11%)
        XCTAssertEqual(vm.rows[0].symbol, "AAPL")
        XCTAssertEqual(vm.rows[1].symbol, "SPY")

        // Toggle descending
        vm.sort(by: .highestClose)
        XCTAssertEqual(vm.rows[0].symbol, "SPY")
        XCTAssertEqual(vm.rows[1].symbol, "AAPL")
    }

    func testSort_byHighestClose_nilSortsFirst() {
        let vm = QuarterlyPanelViewModel()

        let quotes: [String: StockQuote] = [
            "AAPL": makeQuote(symbol: "AAPL", price: 150.0),
            "NEW": makeQuote(symbol: "NEW", price: 50.0),
        ]
        let highestClosePrices: [String: Double] = ["AAPL": 200.0]

        vm.update(watchlist: ["AAPL", "NEW"], quotes: quotes, quarterPrices: [:], quarterInfos: testQuarters, highestClosePrices: highestClosePrices)

        vm.sort(by: .highestClose)

        // nil sorts before any value in ascending
        XCTAssertEqual(vm.rows[0].symbol, "NEW")
        XCTAssertEqual(vm.rows[1].symbol, "AAPL")
    }

    func testRefresh_threadsHighestClosePrices() {
        let vm = QuarterlyPanelViewModel()

        let quotes: [String: StockQuote] = [
            "AAPL": makeQuote(symbol: "AAPL", price: 150.0),
        ]
        let highestClosePrices: [String: Double] = ["AAPL": 200.0]

        vm.update(watchlist: ["AAPL"], quotes: quotes, quarterPrices: [:], quarterInfos: testQuarters, highestClosePrices: highestClosePrices)

        // Refresh with updated prices
        let updatedQuotes: [String: StockQuote] = [
            "AAPL": makeQuote(symbol: "AAPL", price: 180.0),
        ]
        vm.refresh(quotes: updatedQuotes, quarterPrices: [:], highestClosePrices: highestClosePrices)

        let row = vm.rows[0]
        // (180-200)/200 * 100 = -10%
        XCTAssertNotNil(row.highestCloseChangePercent)
        XCTAssertEqual(row.highestCloseChangePercent!, -10.0, accuracy: 0.01)
    }

    // MARK: - Refresh

    func testRefresh_updatesWithNewQuotes() {
        let vm = QuarterlyPanelViewModel()

        let initialQuotes: [String: StockQuote] = [
            "AAPL": makeQuote(symbol: "AAPL", price: 200.0),
        ]
        let quarterPrices: [String: [String: Double]] = [
            "Q4-2025": ["AAPL": 180.0],
        ]

        vm.update(watchlist: ["AAPL"], quotes: initialQuotes, quarterPrices: quarterPrices, quarterInfos: testQuarters)

        let initialChange = vm.rows[0].quarterChanges["Q4-2025"] ?? nil
        XCTAssertEqual(initialChange!, 11.11, accuracy: 0.01)

        // Price increased to 220
        let updatedQuotes: [String: StockQuote] = [
            "AAPL": makeQuote(symbol: "AAPL", price: 220.0),
        ]

        vm.refresh(quotes: updatedQuotes, quarterPrices: quarterPrices)

        let updatedChange = vm.rows[0].quarterChanges["Q4-2025"] ?? nil
        // (220-180)/180 * 100 = 22.22%
        XCTAssertEqual(updatedChange!, 22.22, accuracy: 0.01)
    }

    func testRefresh_whenNoQuarters_doesNothing() {
        let vm = QuarterlyPanelViewModel()
        // No update() called, quarters is empty

        vm.refresh(quotes: [:], quarterPrices: [:])

        XCTAssertTrue(vm.rows.isEmpty)
    }

    // MARK: - Empty Watchlist

    func testUpdate_emptyWatchlist_producesNoRows() {
        let vm = QuarterlyPanelViewModel()

        vm.update(watchlist: [], quotes: [:], quarterPrices: [:], quarterInfos: testQuarters)

        XCTAssertTrue(vm.rows.isEmpty)
    }

    // MARK: - Highlighting

    func testToggleHighlight_addsSymbol() {
        let vm = QuarterlyPanelViewModel()

        vm.toggleHighlight(for: "AAPL")

        XCTAssertTrue(vm.highlightedSymbols.contains("AAPL"))
    }

    func testToggleHighlight_removesSymbol() {
        let vm = QuarterlyPanelViewModel()
        vm.highlightedSymbols = ["AAPL"]

        vm.toggleHighlight(for: "AAPL")

        XCTAssertFalse(vm.highlightedSymbols.contains("AAPL"))
    }

    func testHighlightedSymbols_initializedFromConfig() {
        let vm = QuarterlyPanelViewModel()

        vm.setupHighlights(symbols: ["SPY", "AAPL"], color: "yellow", opacity: 0.25)

        XCTAssertTrue(vm.highlightedSymbols.contains("SPY"))
        XCTAssertTrue(vm.highlightedSymbols.contains("AAPL"))
    }

    func testToggleHighlight_configSymbol_staysHighlighted() {
        let vm = QuarterlyPanelViewModel()
        vm.setupHighlights(symbols: ["SPY"], color: "yellow", opacity: 0.25)

        vm.toggleHighlight(for: "SPY")

        XCTAssertTrue(vm.highlightedSymbols.contains("SPY"))
    }

    // MARK: - View Mode

    func testViewMode_defaultIsSinceQuarter() {
        let vm = QuarterlyPanelViewModel()

        XCTAssertEqual(vm.viewMode, .sinceQuarter)
    }

    func testSwitchMode_toDuringQuarter_recomputesRows() {
        let vm = QuarterlyPanelViewModel()

        let quotes: [String: StockQuote] = [
            "AAPL": makeQuote(symbol: "AAPL", price: 200.0),
        ]
        let quarterPrices: [String: [String: Double]] = [
            "Q4-2025": ["AAPL": 200.0],  // during: (200-180)/180 = 11.11%
            "Q3-2025": ["AAPL": 180.0],  // during: (180-150)/150 = 20.0%
            "Q2-2025": ["AAPL": 150.0],  // oldest, no prior → nil
        ]

        vm.update(watchlist: ["AAPL"], quotes: quotes, quarterPrices: quarterPrices, quarterInfos: testQuarters)

        // Since-quarter mode: (200-200)/200 = 0%
        let sinceQ4 = vm.rows[0].quarterChanges["Q4-2025"] ?? nil
        XCTAssertEqual(sinceQ4!, 0.0, accuracy: 0.01)

        vm.switchMode(.duringQuarter)

        XCTAssertEqual(vm.viewMode, .duringQuarter)

        let duringQ4 = vm.rows[0].quarterChanges["Q4-2025"] ?? nil
        XCTAssertNotNil(duringQ4)
        XCTAssertEqual(duringQ4!, 11.11, accuracy: 0.01)

        let duringQ3 = vm.rows[0].quarterChanges["Q3-2025"] ?? nil
        XCTAssertNotNil(duringQ3)
        XCTAssertEqual(duringQ3!, 20.0, accuracy: 0.01)
    }

    func testDuringQuarter_computesCorrectPercent() {
        let vm = QuarterlyPanelViewModel()

        let quotes: [String: StockQuote] = [
            "SPY": makeQuote(symbol: "SPY", price: 500.0),
        ]
        // Q4 end=200, Q3 end=180 → (200-180)/180 = +11.11%
        let quarterPrices: [String: [String: Double]] = [
            "Q4-2025": ["SPY": 200.0],
            "Q3-2025": ["SPY": 180.0],
            "Q2-2025": ["SPY": 160.0],
        ]

        vm.update(watchlist: ["SPY"], quotes: quotes, quarterPrices: quarterPrices, quarterInfos: testQuarters)
        vm.switchMode(.duringQuarter)

        let q4Change = vm.rows[0].quarterChanges["Q4-2025"] ?? nil
        XCTAssertNotNil(q4Change)
        XCTAssertEqual(q4Change!, 11.11, accuracy: 0.01)

        let q3Change = vm.rows[0].quarterChanges["Q3-2025"] ?? nil
        XCTAssertNotNil(q3Change)
        XCTAssertEqual(q3Change!, 12.5, accuracy: 0.01)
    }

    func testDuringQuarter_oldestQuarter_computesWithPriorData() {
        let vm = QuarterlyPanelViewModel()

        let quotes: [String: StockQuote] = [
            "AAPL": makeQuote(symbol: "AAPL", price: 200.0),
        ]
        // Q1-2025 is the prior quarter for Q2-2025 — fetched as the 13th quarter
        let quarterPrices: [String: [String: Double]] = [
            "Q4-2025": ["AAPL": 200.0],
            "Q3-2025": ["AAPL": 180.0],
            "Q2-2025": ["AAPL": 150.0],
            "Q1-2025": ["AAPL": 120.0],  // prior quarter data
        ]

        vm.update(watchlist: ["AAPL"], quotes: quotes, quarterPrices: quarterPrices, quarterInfos: testQuarters)
        vm.switchMode(.duringQuarter)

        // Q2-2025 during: (150-120)/120 = 25.0%
        let q2Change = vm.rows[0].quarterChanges["Q2-2025"] ?? nil
        XCTAssertNotNil(q2Change)
        XCTAssertEqual(q2Change!, 25.0, accuracy: 0.01)
    }

    func testDuringQuarter_oldestQuarter_missingPriorData_showsNil() {
        let vm = QuarterlyPanelViewModel()

        let quotes: [String: StockQuote] = [
            "AAPL": makeQuote(symbol: "AAPL", price: 200.0),
        ]
        // No Q1-2025 data — oldest quarter has no prior reference
        let quarterPrices: [String: [String: Double]] = [
            "Q4-2025": ["AAPL": 200.0],
            "Q3-2025": ["AAPL": 180.0],
            "Q2-2025": ["AAPL": 150.0],
        ]

        vm.update(watchlist: ["AAPL"], quotes: quotes, quarterPrices: quarterPrices, quarterInfos: testQuarters)
        vm.switchMode(.duringQuarter)

        // Oldest quarter (Q2-2025) has no prior quarter data → nil
        let q2Change = vm.rows[0].quarterChanges["Q2-2025"] ?? nil
        XCTAssertNil(q2Change)
    }

    // MARK: - Forward P/E Mode

    func testBuildForwardPERows_filtersSymbolsWithoutData() {
        let vm = QuarterlyPanelViewModel()

        let quotes: [String: StockQuote] = [
            "AAPL": makeQuote(symbol: "AAPL", price: 200.0),
            "BTC-USD": makeQuote(symbol: "BTC-USD", price: 60000.0),
        ]
        let forwardPEData: [String: [String: Double]] = [
            "AAPL": ["Q4-2025": 28.5, "Q3-2025": 30.2],
            "BTC-USD": [:]  // No P/E data for crypto
        ]

        vm.update(watchlist: ["AAPL", "BTC-USD"], quotes: quotes, quarterPrices: [:], quarterInfos: testQuarters, forwardPEData: forwardPEData)
        vm.switchMode(.forwardPE)

        // BTC-USD filtered out because empty dict
        XCTAssertEqual(vm.rows.count, 1)
        XCTAssertEqual(vm.rows[0].symbol, "AAPL")
    }

    func testBuildForwardPERows_mapsQuarterPEValues() {
        let vm = QuarterlyPanelViewModel()

        let forwardPEData: [String: [String: Double]] = [
            "AAPL": ["Q4-2025": 28.5, "Q3-2025": 30.2, "Q2-2025": 26.0]
        ]

        vm.update(watchlist: ["AAPL"], quotes: [:], quarterPrices: [:], quarterInfos: testQuarters, forwardPEData: forwardPEData)
        vm.switchMode(.forwardPE)

        let row = vm.rows[0]
        let q4 = row.quarterChanges["Q4-2025"] ?? nil
        let q3 = row.quarterChanges["Q3-2025"] ?? nil
        let q2 = row.quarterChanges["Q2-2025"] ?? nil
        XCTAssertEqual(q4, 28.5)
        XCTAssertEqual(q3, 30.2)
        XCTAssertEqual(q2, 26.0)
    }

    func testBuildForwardPERows_includesCurrentForwardPE() {
        let vm = QuarterlyPanelViewModel()

        let forwardPEData: [String: [String: Double]] = [
            "AAPL": ["Q4-2025": 28.5]
        ]
        let currentForwardPEs: [String: Double] = ["AAPL": 27.3]

        vm.update(watchlist: ["AAPL"], quotes: [:], quarterPrices: [:], quarterInfos: testQuarters, forwardPEData: forwardPEData, currentForwardPEs: currentForwardPEs)
        vm.switchMode(.forwardPE)

        XCTAssertEqual(vm.rows[0].currentForwardPE, 27.3)
    }

    func testBuildForwardPERows_missingQuarter_showsNil() {
        let vm = QuarterlyPanelViewModel()

        let forwardPEData: [String: [String: Double]] = [
            "AAPL": ["Q4-2025": 28.5]  // Only Q4 has data
        ]

        vm.update(watchlist: ["AAPL"], quotes: [:], quarterPrices: [:], quarterInfos: testQuarters, forwardPEData: forwardPEData)
        vm.switchMode(.forwardPE)

        let row = vm.rows[0]
        let q3 = row.quarterChanges["Q3-2025"] ?? nil
        XCTAssertNil(q3)
    }

    func testSwitchMode_toForwardPE_rebuildsRows() {
        let vm = QuarterlyPanelViewModel()

        let quotes: [String: StockQuote] = [
            "AAPL": makeQuote(symbol: "AAPL", price: 200.0),
        ]
        let quarterPrices: [String: [String: Double]] = [
            "Q4-2025": ["AAPL": 180.0],
        ]
        let forwardPEData: [String: [String: Double]] = [
            "AAPL": ["Q4-2025": 28.5]
        ]

        vm.update(watchlist: ["AAPL"], quotes: quotes, quarterPrices: quarterPrices, quarterInfos: testQuarters, forwardPEData: forwardPEData)

        // In sinceQuarter mode, quarterChanges has percent values
        let sinceQ4 = vm.rows[0].quarterChanges["Q4-2025"] ?? nil
        XCTAssertEqual(sinceQ4!, 11.11, accuracy: 0.01)

        vm.switchMode(.forwardPE)

        // In forwardPE mode, quarterChanges has P/E ratio values
        let peQ4 = vm.rows[0].quarterChanges["Q4-2025"] ?? nil
        XCTAssertEqual(peQ4, 28.5)
    }

    func testForwardPEMode_highestCloseIsNil() {
        let vm = QuarterlyPanelViewModel()

        let forwardPEData: [String: [String: Double]] = [
            "AAPL": ["Q4-2025": 28.5]
        ]
        let highestClosePrices: [String: Double] = ["AAPL": 200.0]

        vm.update(watchlist: ["AAPL"], quotes: ["AAPL": makeQuote(symbol: "AAPL", price: 150.0)], quarterPrices: [:], quarterInfos: testQuarters, highestClosePrices: highestClosePrices, forwardPEData: forwardPEData)
        vm.switchMode(.forwardPE)

        XCTAssertNil(vm.rows[0].highestCloseChangePercent)
    }

    func testSort_byCurrentPE() {
        let vm = QuarterlyPanelViewModel()

        let forwardPEData: [String: [String: Double]] = [
            "AAPL": ["Q4-2025": 28.5],
            "MSFT": ["Q4-2025": 32.1],
        ]
        let currentForwardPEs: [String: Double] = ["AAPL": 28.5, "MSFT": 32.1]

        vm.update(watchlist: ["AAPL", "MSFT"], quotes: [:], quarterPrices: [:], quarterInfos: testQuarters, forwardPEData: forwardPEData, currentForwardPEs: currentForwardPEs)
        vm.switchMode(.forwardPE)

        vm.sort(by: .currentPE)

        // Ascending: AAPL (28.5) < MSFT (32.1)
        XCTAssertEqual(vm.rows[0].symbol, "AAPL")
        XCTAssertEqual(vm.rows[1].symbol, "MSFT")

        // Toggle descending
        vm.sort(by: .currentPE)
        XCTAssertEqual(vm.rows[0].symbol, "MSFT")
        XCTAssertEqual(vm.rows[1].symbol, "AAPL")
    }

    func testSort_byQuarterColumn_inForwardPEMode() {
        let vm = QuarterlyPanelViewModel()

        let forwardPEData: [String: [String: Double]] = [
            "AAPL": ["Q4-2025": 28.5],
            "MSFT": ["Q4-2025": 32.1],
        ]

        vm.update(watchlist: ["AAPL", "MSFT"], quotes: [:], quarterPrices: [:], quarterInfos: testQuarters, forwardPEData: forwardPEData)
        vm.switchMode(.forwardPE)

        vm.sort(by: .quarter("Q4-2025"))

        // Ascending: AAPL (28.5) < MSFT (32.1)
        XCTAssertEqual(vm.rows[0].symbol, "AAPL")
        XCTAssertEqual(vm.rows[1].symbol, "MSFT")
    }

    func testSwitchMode_backToSinceQuarter_restoresOriginal() {
        let vm = QuarterlyPanelViewModel()

        let quotes: [String: StockQuote] = [
            "AAPL": makeQuote(symbol: "AAPL", price: 200.0),
        ]
        let quarterPrices: [String: [String: Double]] = [
            "Q4-2025": ["AAPL": 180.0],
            "Q3-2025": ["AAPL": 160.0],
            "Q2-2025": ["AAPL": 150.0],
        ]

        vm.update(watchlist: ["AAPL"], quotes: quotes, quarterPrices: quarterPrices, quarterInfos: testQuarters)

        let originalQ4 = vm.rows[0].quarterChanges["Q4-2025"] ?? nil
        XCTAssertEqual(originalQ4!, 11.11, accuracy: 0.01)

        vm.switchMode(.duringQuarter)
        vm.switchMode(.sinceQuarter)

        XCTAssertEqual(vm.viewMode, .sinceQuarter)
        let restoredQ4 = vm.rows[0].quarterChanges["Q4-2025"] ?? nil
        XCTAssertEqual(restoredQ4!, 11.11, accuracy: 0.01)
    }

    // MARK: - Price Breaks Mode (Breakout)

    func testPriceBreaks_breakoutRows_positivePercent() {
        let vm = QuarterlyPanelViewModel()

        let quotes: [String: StockQuote] = [
            "AAPL": makeQuote(symbol: "AAPL", price: 220.0),
        ]
        let swingEntries: [String: SwingLevelCacheEntry] = [
            "AAPL": SwingLevelCacheEntry(breakoutPrice: 200.0, breakoutDate: "1/15/25", breakdownPrice: nil, breakdownDate: nil),
        ]

        vm.update(watchlist: ["AAPL"], quotes: quotes, quarterPrices: [:], quarterInfos: testQuarters, swingLevelEntries: swingEntries)
        vm.switchMode(.priceBreaks)

        XCTAssertEqual(vm.breakoutRows.count, 1)
        XCTAssertEqual(vm.breakoutRows[0].breakoutPercent!, 10.0, accuracy: 0.01)
        XCTAssertEqual(vm.breakoutRows[0].breakoutDate, "1/15/25")
        XCTAssertTrue(vm.breakdownRows.isEmpty)
    }

    func testPriceBreaks_breakoutRows_belowBreakout_filtered() {
        let vm = QuarterlyPanelViewModel()

        let quotes: [String: StockQuote] = [
            "AAPL": makeQuote(symbol: "AAPL", price: 180.0),
        ]
        let swingEntries: [String: SwingLevelCacheEntry] = [
            "AAPL": SwingLevelCacheEntry(breakoutPrice: 200.0, breakoutDate: "1/15/25", breakdownPrice: nil, breakdownDate: nil),
        ]

        vm.update(watchlist: ["AAPL"], quotes: quotes, quarterPrices: [:], quarterInfos: testQuarters, swingLevelEntries: swingEntries)
        vm.switchMode(.priceBreaks)

        XCTAssertTrue(vm.breakoutRows.isEmpty)
    }

    func testPriceBreaks_noSwingData_emptyRows() {
        let vm = QuarterlyPanelViewModel()

        let quotes: [String: StockQuote] = [
            "AAPL": makeQuote(symbol: "AAPL", price: 220.0),
        ]

        vm.update(watchlist: ["AAPL"], quotes: quotes, quarterPrices: [:], quarterInfos: testQuarters)
        vm.switchMode(.priceBreaks)

        XCTAssertTrue(vm.breakoutRows.isEmpty)
        XCTAssertTrue(vm.breakdownRows.isEmpty)
    }

    // MARK: - Price Breaks Mode (Breakdown)

    func testPriceBreaks_breakdownRows_negativePercent() {
        let vm = QuarterlyPanelViewModel()

        let quotes: [String: StockQuote] = [
            "AAPL": makeQuote(symbol: "AAPL", price: 90.0),
        ]
        let swingEntries: [String: SwingLevelCacheEntry] = [
            "AAPL": SwingLevelCacheEntry(breakoutPrice: nil, breakoutDate: nil, breakdownPrice: 100.0, breakdownDate: "6/10/24"),
        ]

        vm.update(watchlist: ["AAPL"], quotes: quotes, quarterPrices: [:], quarterInfos: testQuarters, swingLevelEntries: swingEntries)
        vm.switchMode(.priceBreaks)

        XCTAssertTrue(vm.breakoutRows.isEmpty)
        XCTAssertEqual(vm.breakdownRows.count, 1)
        XCTAssertEqual(vm.breakdownRows[0].breakdownPercent!, -10.0, accuracy: 0.01)
        XCTAssertEqual(vm.breakdownRows[0].breakdownDate, "6/10/24")
    }

    func testPriceBreaks_breakdownRows_aboveBreakdown_filtered() {
        let vm = QuarterlyPanelViewModel()

        let quotes: [String: StockQuote] = [
            "AAPL": makeQuote(symbol: "AAPL", price: 120.0),
        ]
        let swingEntries: [String: SwingLevelCacheEntry] = [
            "AAPL": SwingLevelCacheEntry(breakoutPrice: nil, breakoutDate: nil, breakdownPrice: 100.0, breakdownDate: "6/10/24"),
        ]

        vm.update(watchlist: ["AAPL"], quotes: quotes, quarterPrices: [:], quarterInfos: testQuarters, swingLevelEntries: swingEntries)
        vm.switchMode(.priceBreaks)

        XCTAssertTrue(vm.breakdownRows.isEmpty)
    }

    // MARK: - Price Breaks: Both Breakout and Breakdown

    func testPriceBreaks_symbolWithBoth_appearsInBothArrays() {
        let vm = QuarterlyPanelViewModel()

        let quotes: [String: StockQuote] = [
            "AAPL": makeQuote(symbol: "AAPL", price: 220.0),
        ]
        let swingEntries: [String: SwingLevelCacheEntry] = [
            "AAPL": SwingLevelCacheEntry(breakoutPrice: 200.0, breakoutDate: "1/15/25", breakdownPrice: 250.0, breakdownDate: "6/10/24"),
        ]

        vm.update(watchlist: ["AAPL"], quotes: quotes, quarterPrices: [:], quarterInfos: testQuarters, swingLevelEntries: swingEntries)
        vm.switchMode(.priceBreaks)

        XCTAssertEqual(vm.breakoutRows.count, 1)
        XCTAssertEqual(vm.breakdownRows.count, 1)
        XCTAssertEqual(vm.breakoutRows[0].symbol, "AAPL")
        XCTAssertEqual(vm.breakdownRows[0].symbol, "AAPL")
        // Unique IDs
        XCTAssertEqual(vm.breakoutRows[0].id, "AAPL-breakout")
        XCTAssertEqual(vm.breakdownRows[0].id, "AAPL-breakdown")
    }

    // MARK: - Sorting Price Breaks

    func testSort_byPriceBreakPercent_breakoutRows() {
        let vm = QuarterlyPanelViewModel()

        let quotes: [String: StockQuote] = [
            "AAPL": makeQuote(symbol: "AAPL", price: 220.0),
            "MSFT": makeQuote(symbol: "MSFT", price: 360.0),
        ]
        let swingEntries: [String: SwingLevelCacheEntry] = [
            "AAPL": SwingLevelCacheEntry(breakoutPrice: 200.0, breakoutDate: "1/15/25", breakdownPrice: nil, breakdownDate: nil),  // +10%
            "MSFT": SwingLevelCacheEntry(breakoutPrice: 300.0, breakoutDate: "2/20/25", breakdownPrice: nil, breakdownDate: nil),  // +20%
        ]

        vm.update(watchlist: ["AAPL", "MSFT"], quotes: quotes, quarterPrices: [:], quarterInfos: testQuarters, swingLevelEntries: swingEntries)
        vm.switchMode(.priceBreaks)
        vm.sort(by: .priceBreakPercent)

        // Ascending: AAPL (10%) < MSFT (20%)
        XCTAssertEqual(vm.breakoutRows[0].symbol, "AAPL")
        XCTAssertEqual(vm.breakoutRows[1].symbol, "MSFT")

        // Toggle descending
        vm.sort(by: .priceBreakPercent)
        XCTAssertEqual(vm.breakoutRows[0].symbol, "MSFT")
        XCTAssertEqual(vm.breakoutRows[1].symbol, "AAPL")
    }

    func testSort_byPriceBreakPercent_breakdownRows() {
        let vm = QuarterlyPanelViewModel()

        let quotes: [String: StockQuote] = [
            "AAPL": makeQuote(symbol: "AAPL", price: 90.0),
            "MSFT": makeQuote(symbol: "MSFT", price: 80.0),
        ]
        let swingEntries: [String: SwingLevelCacheEntry] = [
            "AAPL": SwingLevelCacheEntry(breakoutPrice: nil, breakoutDate: nil, breakdownPrice: 100.0, breakdownDate: "6/10/24"),  // -10%
            "MSFT": SwingLevelCacheEntry(breakoutPrice: nil, breakoutDate: nil, breakdownPrice: 100.0, breakdownDate: "6/10/24"),  // -20%
        ]

        vm.update(watchlist: ["AAPL", "MSFT"], quotes: quotes, quarterPrices: [:], quarterInfos: testQuarters, swingLevelEntries: swingEntries)
        vm.switchMode(.priceBreaks)
        vm.sort(by: .priceBreakPercent)

        // Ascending: MSFT (-20%) < AAPL (-10%)
        XCTAssertEqual(vm.breakdownRows[0].symbol, "MSFT")
        XCTAssertEqual(vm.breakdownRows[1].symbol, "AAPL")

        // Toggle descending
        vm.sort(by: .priceBreakPercent)
        XCTAssertEqual(vm.breakdownRows[0].symbol, "AAPL")
        XCTAssertEqual(vm.breakdownRows[1].symbol, "MSFT")
    }

    func testSort_byDate_ordersCorrectly() {
        let vm = QuarterlyPanelViewModel()

        let quotes: [String: StockQuote] = [
            "AAPL": makeQuote(symbol: "AAPL", price: 220.0),
            "MSFT": makeQuote(symbol: "MSFT", price: 360.0),
        ]
        let swingEntries: [String: SwingLevelCacheEntry] = [
            "AAPL": SwingLevelCacheEntry(breakoutPrice: 200.0, breakoutDate: "1/15/25", breakdownPrice: nil, breakdownDate: nil),
            "MSFT": SwingLevelCacheEntry(breakoutPrice: 300.0, breakoutDate: "6/20/24", breakdownPrice: nil, breakdownDate: nil),
        ]

        vm.update(watchlist: ["AAPL", "MSFT"], quotes: quotes, quarterPrices: [:], quarterInfos: testQuarters, swingLevelEntries: swingEntries)
        vm.switchMode(.priceBreaks)
        vm.sort(by: .date)

        // Ascending: MSFT (6/20/24) < AAPL (1/15/25)
        XCTAssertEqual(vm.breakoutRows[0].symbol, "MSFT")
        XCTAssertEqual(vm.breakoutRows[1].symbol, "AAPL")

        // Toggle descending
        vm.sort(by: .date)
        XCTAssertEqual(vm.breakoutRows[0].symbol, "AAPL")
        XCTAssertEqual(vm.breakoutRows[1].symbol, "MSFT")
    }

    // MARK: - isPriceBreaksMode

    func testIsPriceBreaksMode_priceBreaks_true() {
        let vm = QuarterlyPanelViewModel()
        vm.update(watchlist: [], quotes: [:], quarterPrices: [:], quarterInfos: testQuarters)
        vm.switchMode(.priceBreaks)
        XCTAssertTrue(vm.isPriceBreaksMode)
    }

    func testIsPriceBreaksMode_sinceQuarter_false() {
        let vm = QuarterlyPanelViewModel()
        vm.update(watchlist: [], quotes: [:], quarterPrices: [:], quarterInfos: testQuarters)
        XCTAssertFalse(vm.isPriceBreaksMode)
    }

    func testIsPriceBreaksMode_forwardPE_false() {
        let vm = QuarterlyPanelViewModel()
        vm.update(watchlist: [], quotes: [:], quarterPrices: [:], quarterInfos: testQuarters)
        vm.switchMode(.forwardPE)
        XCTAssertFalse(vm.isPriceBreaksMode)
    }

    // MARK: - Price Breaks RSI Column

    func testPriceBreaks_breakoutRows_includeRSI() {
        let vm = QuarterlyPanelViewModel()

        let quotes: [String: StockQuote] = [
            "AAPL": makeQuote(symbol: "AAPL", price: 220.0),
        ]
        let swingEntries: [String: SwingLevelCacheEntry] = [
            "AAPL": SwingLevelCacheEntry(breakoutPrice: 200.0, breakoutDate: "1/15/25", breakdownPrice: nil, breakdownDate: nil),
        ]
        let rsiValues: [String: Double] = ["AAPL": 65.2]

        vm.update(watchlist: ["AAPL"], quotes: quotes, quarterPrices: [:], quarterInfos: testQuarters, swingLevelEntries: swingEntries, rsiValues: rsiValues)
        vm.switchMode(.priceBreaks)

        XCTAssertEqual(vm.breakoutRows.count, 1)
        XCTAssertEqual(vm.breakoutRows[0].rsi, 65.2)
    }

    func testPriceBreaks_breakdownRows_includeRSI() {
        let vm = QuarterlyPanelViewModel()

        let quotes: [String: StockQuote] = [
            "AAPL": makeQuote(symbol: "AAPL", price: 90.0),
        ]
        let swingEntries: [String: SwingLevelCacheEntry] = [
            "AAPL": SwingLevelCacheEntry(breakoutPrice: nil, breakoutDate: nil, breakdownPrice: 100.0, breakdownDate: "6/10/24"),
        ]
        let rsiValues: [String: Double] = ["AAPL": 28.5]

        vm.update(watchlist: ["AAPL"], quotes: quotes, quarterPrices: [:], quarterInfos: testQuarters, swingLevelEntries: swingEntries, rsiValues: rsiValues)
        vm.switchMode(.priceBreaks)

        XCTAssertEqual(vm.breakdownRows.count, 1)
        XCTAssertEqual(vm.breakdownRows[0].rsi, 28.5)
    }

    func testPriceBreaks_noRSIData_rowHasNilRSI() {
        let vm = QuarterlyPanelViewModel()

        let quotes: [String: StockQuote] = [
            "AAPL": makeQuote(symbol: "AAPL", price: 220.0),
        ]
        let swingEntries: [String: SwingLevelCacheEntry] = [
            "AAPL": SwingLevelCacheEntry(breakoutPrice: 200.0, breakoutDate: "1/15/25", breakdownPrice: nil, breakdownDate: nil),
        ]

        vm.update(watchlist: ["AAPL"], quotes: quotes, quarterPrices: [:], quarterInfos: testQuarters, swingLevelEntries: swingEntries)
        vm.switchMode(.priceBreaks)

        XCTAssertEqual(vm.breakoutRows.count, 1)
        XCTAssertNil(vm.breakoutRows[0].rsi)
    }

    // MARK: - Misc Stats Mode

    func testMiscStats_percentWithin5PercentOfHigh_allWithin() {
        let vm = QuarterlyPanelViewModel()

        let quotes: [String: StockQuote] = [
            "AAPL": makeQuote(symbol: "AAPL", price: 198.0),
            "SPY": makeQuote(symbol: "SPY", price: 500.0),
        ]
        // AAPL: (198-200)/200 = -1%, SPY: (500-500)/500 = 0% — both within 5%
        let highestClosePrices: [String: Double] = ["AAPL": 200.0, "SPY": 500.0]

        vm.update(watchlist: ["AAPL", "SPY"], quotes: quotes, quarterPrices: [:], quarterInfos: testQuarters, highestClosePrices: highestClosePrices)
        vm.switchMode(.miscStats)

        XCTAssertEqual(vm.miscStats.count, 8)
        XCTAssertEqual(vm.miscStats[0].id, "within5pctOfHigh")
        XCTAssertEqual(vm.miscStats[0].value, "100%")
        // SPY is an index, within 5%
        XCTAssertEqual(vm.miscStats[1].id, "indexesWithin5pctOfHigh")
        XCTAssertEqual(vm.miscStats[1].value, "100%")
    }

    func testMiscStats_percentWithin5PercentOfHigh_noneWithin() {
        let vm = QuarterlyPanelViewModel()

        let quotes: [String: StockQuote] = [
            "AAPL": makeQuote(symbol: "AAPL", price: 100.0),
            "SPY": makeQuote(symbol: "SPY", price: 300.0),
        ]
        // AAPL: (100-200)/200 = -50%, SPY: (300-500)/500 = -40%
        let highestClosePrices: [String: Double] = ["AAPL": 200.0, "SPY": 500.0]

        vm.update(watchlist: ["AAPL", "SPY"], quotes: quotes, quarterPrices: [:], quarterInfos: testQuarters, highestClosePrices: highestClosePrices)
        vm.switchMode(.miscStats)

        XCTAssertEqual(vm.miscStats[0].value, "0%")
    }

    func testMiscStats_percentWithin5PercentOfHigh_partial() {
        let vm = QuarterlyPanelViewModel()

        let quotes: [String: StockQuote] = [
            "AAPL": makeQuote(symbol: "AAPL", price: 198.0),  // -1% from high
            "SPY": makeQuote(symbol: "SPY", price: 300.0),    // -40% from high
        ]
        let highestClosePrices: [String: Double] = ["AAPL": 200.0, "SPY": 500.0]

        vm.update(watchlist: ["AAPL", "SPY"], quotes: quotes, quarterPrices: [:], quarterInfos: testQuarters, highestClosePrices: highestClosePrices)
        vm.switchMode(.miscStats)

        // 1 out of 2 = 50%
        XCTAssertEqual(vm.miscStats[0].value, "50%")
    }

    func testMiscStats_percentWithin5PercentOfHigh_noData() {
        let vm = QuarterlyPanelViewModel()

        vm.update(watchlist: ["AAPL"], quotes: [:], quarterPrices: [:], quarterInfos: testQuarters)
        vm.switchMode(.miscStats)

        XCTAssertEqual(vm.miscStats[0].value, "--")
    }

    func testMiscStats_rowsAreEmpty() {
        let vm = QuarterlyPanelViewModel()

        vm.update(watchlist: ["AAPL"], quotes: [:], quarterPrices: [:], quarterInfos: testQuarters)
        vm.switchMode(.miscStats)

        // Misc stats mode returns empty rows array
        XCTAssertTrue(vm.rows.isEmpty)
    }

    func testMiscStats_indexesWithin5Percent_partial() {
        let vm = QuarterlyPanelViewModel()

        let quotes: [String: StockQuote] = [
            "SPY": makeQuote(symbol: "SPY", price: 498.0),  // -0.4% from high
            "QQQ": makeQuote(symbol: "QQQ", price: 300.0),  // -25% from high
            "DIA": makeQuote(symbol: "DIA", price: 390.0),  // -2.5% from high
            "IWM": makeQuote(symbol: "IWM", price: 150.0),  // -25% from high
        ]
        let highestClosePrices: [String: Double] = ["SPY": 500.0, "QQQ": 400.0, "DIA": 400.0, "IWM": 200.0]

        vm.update(watchlist: ["SPY", "QQQ", "DIA", "IWM"], quotes: quotes, quarterPrices: [:], quarterInfos: testQuarters, highestClosePrices: highestClosePrices)
        vm.switchMode(.miscStats)

        // 2 of 4 indexes within 5%
        XCTAssertEqual(vm.miscStats[1].id, "indexesWithin5pctOfHigh")
        XCTAssertEqual(vm.miscStats[1].value, "50%")
    }

    func testMiscStats_indexesWithin5Percent_noIndexesInWatchlist() {
        let vm = QuarterlyPanelViewModel()

        let quotes: [String: StockQuote] = [
            "AAPL": makeQuote(symbol: "AAPL", price: 198.0),
        ]
        let highestClosePrices: [String: Double] = ["AAPL": 200.0]

        vm.update(watchlist: ["AAPL"], quotes: quotes, quarterPrices: [:], quarterInfos: testQuarters, highestClosePrices: highestClosePrices)
        vm.switchMode(.miscStats)

        XCTAssertEqual(vm.miscStats[1].id, "indexesWithin5pctOfHigh")
        XCTAssertEqual(vm.miscStats[1].value, "--")
    }

    func testMiscStats_sectorsWithin5Percent_partial() {
        let vm = QuarterlyPanelViewModel()

        let quotes: [String: StockQuote] = [
            "XLK": makeQuote(symbol: "XLK", price: 198.0),  // -1% from high
            "XLF": makeQuote(symbol: "XLF", price: 50.0),   // -50% from high
            "SMH": makeQuote(symbol: "SMH", price: 290.0),  // -3.3% from high
        ]
        let highestClosePrices: [String: Double] = ["XLK": 200.0, "XLF": 100.0, "SMH": 300.0]

        vm.update(watchlist: ["XLK", "XLF", "SMH"], quotes: quotes, quarterPrices: [:], quarterInfos: testQuarters, highestClosePrices: highestClosePrices)
        vm.switchMode(.miscStats)

        // 2 of 3 sectors within 5%
        XCTAssertEqual(vm.miscStats[2].id, "sectorsWithin5pctOfHigh")
        XCTAssertEqual(vm.miscStats[2].value, "67%")
    }

    func testMiscStats_sectorsWithin5Percent_noSectorsInWatchlist() {
        let vm = QuarterlyPanelViewModel()

        let quotes: [String: StockQuote] = [
            "AAPL": makeQuote(symbol: "AAPL", price: 198.0),
        ]
        let highestClosePrices: [String: Double] = ["AAPL": 200.0]

        vm.update(watchlist: ["AAPL"], quotes: quotes, quarterPrices: [:], quarterInfos: testQuarters, highestClosePrices: highestClosePrices)
        vm.switchMode(.miscStats)

        XCTAssertEqual(vm.miscStats[2].id, "sectorsWithin5pctOfHigh")
        XCTAssertEqual(vm.miscStats[2].value, "--")
    }

    // MARK: - Misc Stats: YTD

    func testMiscStats_averageYTDChange() {
        let vm = QuarterlyPanelViewModel()

        var q1 = makeQuote(symbol: "AAPL", price: 220.0)
        q1 = q1.withYTDStartPrice(200.0)  // +10%
        var q2 = makeQuote(symbol: "SPY", price: 450.0)
        q2 = q2.withYTDStartPrice(500.0)  // -10%

        vm.update(watchlist: ["AAPL", "SPY"], quotes: ["AAPL": q1, "SPY": q2], quarterPrices: [:], quarterInfos: testQuarters)
        vm.switchMode(.miscStats)

        // Average of +10% and -10% = 0%
        XCTAssertEqual(vm.miscStats[3].id, "avgYTDChange")
        XCTAssertEqual(vm.miscStats[3].value, "+0.00%")
    }

    func testMiscStats_averageYTDChange_noData() {
        let vm = QuarterlyPanelViewModel()

        let quotes: [String: StockQuote] = [
            "AAPL": makeQuote(symbol: "AAPL", price: 200.0),  // no YTD start price
        ]

        vm.update(watchlist: ["AAPL"], quotes: quotes, quarterPrices: [:], quarterInfos: testQuarters)
        vm.switchMode(.miscStats)

        XCTAssertEqual(vm.miscStats[3].value, "--")
    }

    func testMiscStats_percentPositiveYTD() {
        let vm = QuarterlyPanelViewModel()

        var q1 = makeQuote(symbol: "AAPL", price: 220.0)
        q1 = q1.withYTDStartPrice(200.0)  // +10%
        var q2 = makeQuote(symbol: "SPY", price: 450.0)
        q2 = q2.withYTDStartPrice(500.0)  // -10%
        var q3 = makeQuote(symbol: "MSFT", price: 350.0)
        q3 = q3.withYTDStartPrice(300.0)  // +16.7%

        vm.update(watchlist: ["AAPL", "SPY", "MSFT"], quotes: ["AAPL": q1, "SPY": q2, "MSFT": q3], quarterPrices: [:], quarterInfos: testQuarters)
        vm.switchMode(.miscStats)

        // 2 of 3 positive
        XCTAssertEqual(vm.miscStats[4].id, "pctPositiveYTD")
        XCTAssertEqual(vm.miscStats[4].value, "67%")
    }

    func testMiscStats_percentPositiveYTD_noData() {
        let vm = QuarterlyPanelViewModel()

        vm.update(watchlist: ["AAPL"], quotes: [:], quarterPrices: [:], quarterInfos: testQuarters)
        vm.switchMode(.miscStats)

        XCTAssertEqual(vm.miscStats[4].value, "--")
    }

    func testMiscStats_sectorsPositiveYTD() {
        let vm = QuarterlyPanelViewModel()

        var q1 = makeQuote(symbol: "XLK", price: 220.0)
        q1 = q1.withYTDStartPrice(200.0)  // +10%
        var q2 = makeQuote(symbol: "XLF", price: 90.0)
        q2 = q2.withYTDStartPrice(100.0)  // -10%
        var q3 = makeQuote(symbol: "XLV", price: 110.0)
        q3 = q3.withYTDStartPrice(100.0)  // +10%

        vm.update(watchlist: ["XLK", "XLF", "XLV"], quotes: ["XLK": q1, "XLF": q2, "XLV": q3], quarterPrices: [:], quarterInfos: testQuarters)
        vm.switchMode(.miscStats)

        // 2 of 3 sectors positive
        XCTAssertEqual(vm.miscStats[5].id, "sectorsPositiveYTD")
        XCTAssertEqual(vm.miscStats[5].value, "67%")
    }

    func testMiscStats_sectorsPositiveYTD_noSectors() {
        let vm = QuarterlyPanelViewModel()

        var q1 = makeQuote(symbol: "AAPL", price: 220.0)
        q1 = q1.withYTDStartPrice(200.0)

        vm.update(watchlist: ["AAPL"], quotes: ["AAPL": q1], quarterPrices: [:], quarterInfos: testQuarters)
        vm.switchMode(.miscStats)

        XCTAssertEqual(vm.miscStats[5].id, "sectorsPositiveYTD")
        XCTAssertEqual(vm.miscStats[5].value, "--")
    }

    // MARK: - Misc Stats: Forward P/E

    func testMiscStats_averageForwardPE() {
        let vm = QuarterlyPanelViewModel()

        let currentForwardPEs: [String: Double] = ["AAPL": 30.0, "MSFT": 40.0]

        vm.update(watchlist: ["AAPL", "MSFT"], quotes: [:], quarterPrices: [:], quarterInfos: testQuarters, currentForwardPEs: currentForwardPEs)
        vm.switchMode(.miscStats)

        XCTAssertEqual(vm.miscStats[6].id, "avgForwardPE")
        XCTAssertEqual(vm.miscStats[6].value, "35.0")
    }

    func testMiscStats_averageForwardPE_excludesNegative() {
        let vm = QuarterlyPanelViewModel()

        let currentForwardPEs: [String: Double] = ["AAPL": 30.0, "MSFT": 40.0, "BAD": -500.0]

        vm.update(watchlist: ["AAPL", "MSFT", "BAD"], quotes: [:], quarterPrices: [:], quarterInfos: testQuarters, currentForwardPEs: currentForwardPEs)
        vm.switchMode(.miscStats)

        // Negative P/E excluded, average of 30 and 40
        XCTAssertEqual(vm.miscStats[6].value, "35.0")
    }

    func testMiscStats_averageForwardPE_noData() {
        let vm = QuarterlyPanelViewModel()

        vm.update(watchlist: ["BTC-USD"], quotes: [:], quarterPrices: [:], quarterInfos: testQuarters)
        vm.switchMode(.miscStats)

        XCTAssertEqual(vm.miscStats[7].value, "--")
    }

    func testMiscStats_medianForwardPE_oddCount() {
        let vm = QuarterlyPanelViewModel()

        let currentForwardPEs: [String: Double] = ["AAPL": 20.0, "MSFT": 40.0, "GOOGL": 30.0]

        vm.update(watchlist: ["AAPL", "MSFT", "GOOGL"], quotes: [:], quarterPrices: [:], quarterInfos: testQuarters, currentForwardPEs: currentForwardPEs)
        vm.switchMode(.miscStats)

        XCTAssertEqual(vm.miscStats[7].id, "medianForwardPE")
        XCTAssertEqual(vm.miscStats[7].value, "30.0")
    }

    func testMiscStats_medianForwardPE_evenCount() {
        let vm = QuarterlyPanelViewModel()

        let currentForwardPEs: [String: Double] = ["AAPL": 20.0, "MSFT": 40.0, "GOOGL": 30.0, "META": 25.0]

        vm.update(watchlist: ["AAPL", "MSFT", "GOOGL", "META"], quotes: [:], quarterPrices: [:], quarterInfos: testQuarters, currentForwardPEs: currentForwardPEs)
        vm.switchMode(.miscStats)

        // Sorted: 20, 25, 30, 40 → median = (25+30)/2 = 27.5
        XCTAssertEqual(vm.miscStats[7].value, "27.5")
    }

    func testMiscStats_medianForwardPE_noData() {
        let vm = QuarterlyPanelViewModel()

        vm.update(watchlist: ["BTC-USD"], quotes: [:], quarterPrices: [:], quarterInfos: testQuarters)
        vm.switchMode(.miscStats)

        XCTAssertEqual(vm.miscStats[7].value, "--")
    }

    func testIsMiscStatsMode() {
        let vm = QuarterlyPanelViewModel()
        vm.update(watchlist: [], quotes: [:], quarterPrices: [:], quarterInfos: testQuarters)

        XCTAssertFalse(vm.isMiscStatsMode)
        vm.switchMode(.miscStats)
        XCTAssertTrue(vm.isMiscStatsMode)
    }

    func testSort_byRSI_breakoutRows() {
        let vm = QuarterlyPanelViewModel()

        let quotes: [String: StockQuote] = [
            "AAPL": makeQuote(symbol: "AAPL", price: 220.0),
            "MSFT": makeQuote(symbol: "MSFT", price: 360.0),
        ]
        let swingEntries: [String: SwingLevelCacheEntry] = [
            "AAPL": SwingLevelCacheEntry(breakoutPrice: 200.0, breakoutDate: "1/15/25", breakdownPrice: nil, breakdownDate: nil),
            "MSFT": SwingLevelCacheEntry(breakoutPrice: 300.0, breakoutDate: "2/20/25", breakdownPrice: nil, breakdownDate: nil),
        ]
        let rsiValues: [String: Double] = ["AAPL": 72.0, "MSFT": 45.0]

        vm.update(watchlist: ["AAPL", "MSFT"], quotes: quotes, quarterPrices: [:], quarterInfos: testQuarters, swingLevelEntries: swingEntries, rsiValues: rsiValues)
        vm.switchMode(.priceBreaks)

        vm.sort(by: .rsi)
        XCTAssertEqual(vm.breakoutRows[0].symbol, "MSFT")
        XCTAssertEqual(vm.breakoutRows[1].symbol, "AAPL")

        vm.sort(by: .rsi)
        XCTAssertEqual(vm.breakoutRows[0].symbol, "AAPL")
        XCTAssertEqual(vm.breakoutRows[1].symbol, "MSFT")
    }

    // MARK: - 5 EMAs Mode

    func testEMAs_dayRows_aboveEMA() {
        let vm = QuarterlyPanelViewModel()

        let quotes: [String: StockQuote] = [
            "AAPL": makeQuote(symbol: "AAPL", price: 220.0),
        ]
        let emaEntries: [String: EMACacheEntry] = [
            "AAPL": EMACacheEntry(day: 200.0, week: nil, month: nil, weekCrossoverWeeksBelow: nil),
        ]

        vm.update(watchlist: ["AAPL"], quotes: quotes, quarterPrices: [:], quarterInfos: testQuarters, emaEntries: emaEntries)
        vm.switchMode(.emas)

        XCTAssertEqual(vm.emaDayRows.count, 1)
        XCTAssertEqual(vm.emaDayRows[0].breakoutPercent!, 10.0, accuracy: 0.01)
        XCTAssertTrue(vm.emaWeekRows.isEmpty)
        XCTAssertTrue(vm.emaMonthRows.isEmpty)
    }

    func testEMAs_belowEMA_filtered() {
        let vm = QuarterlyPanelViewModel()

        let quotes: [String: StockQuote] = [
            "AAPL": makeQuote(symbol: "AAPL", price: 180.0),
        ]
        let emaEntries: [String: EMACacheEntry] = [
            "AAPL": EMACacheEntry(day: 200.0, week: 200.0, month: 200.0, weekCrossoverWeeksBelow: nil),
        ]

        vm.update(watchlist: ["AAPL"], quotes: quotes, quarterPrices: [:], quarterInfos: testQuarters, emaEntries: emaEntries)
        vm.switchMode(.emas)

        XCTAssertTrue(vm.emaDayRows.isEmpty)
        XCTAssertTrue(vm.emaWeekRows.isEmpty)
        XCTAssertTrue(vm.emaMonthRows.isEmpty)
    }

    func testEMAs_noData_emptyRows() {
        let vm = QuarterlyPanelViewModel()

        let quotes: [String: StockQuote] = [
            "AAPL": makeQuote(symbol: "AAPL", price: 220.0),
        ]

        vm.update(watchlist: ["AAPL"], quotes: quotes, quarterPrices: [:], quarterInfos: testQuarters)
        vm.switchMode(.emas)

        XCTAssertTrue(vm.emaDayRows.isEmpty)
        XCTAssertTrue(vm.emaWeekRows.isEmpty)
        XCTAssertTrue(vm.emaMonthRows.isEmpty)
    }

    func testEMAs_nilValues_skipped() {
        let vm = QuarterlyPanelViewModel()

        let quotes: [String: StockQuote] = [
            "AAPL": makeQuote(symbol: "AAPL", price: 220.0),
        ]
        let emaEntries: [String: EMACacheEntry] = [
            "AAPL": EMACacheEntry(day: nil, week: nil, month: nil, weekCrossoverWeeksBelow: nil),
        ]

        vm.update(watchlist: ["AAPL"], quotes: quotes, quarterPrices: [:], quarterInfos: testQuarters, emaEntries: emaEntries)
        vm.switchMode(.emas)

        XCTAssertTrue(vm.emaDayRows.isEmpty)
        XCTAssertTrue(vm.emaWeekRows.isEmpty)
        XCTAssertTrue(vm.emaMonthRows.isEmpty)
    }

    func testEMAs_symbolInMultipleTables() {
        let vm = QuarterlyPanelViewModel()

        let quotes: [String: StockQuote] = [
            "AAPL": makeQuote(symbol: "AAPL", price: 220.0),
        ]
        let emaEntries: [String: EMACacheEntry] = [
            "AAPL": EMACacheEntry(day: 200.0, week: 210.0, month: 215.0, weekCrossoverWeeksBelow: nil),
        ]

        vm.update(watchlist: ["AAPL"], quotes: quotes, quarterPrices: [:], quarterInfos: testQuarters, emaEntries: emaEntries)
        vm.switchMode(.emas)

        XCTAssertEqual(vm.emaDayRows.count, 1)
        XCTAssertEqual(vm.emaWeekRows.count, 1)
        XCTAssertEqual(vm.emaMonthRows.count, 1)
        XCTAssertEqual(vm.emaAllRows.count, 1)
    }

    func testEMAs_uniqueIDs() {
        let vm = QuarterlyPanelViewModel()

        let quotes: [String: StockQuote] = [
            "AAPL": makeQuote(symbol: "AAPL", price: 220.0),
        ]
        let emaEntries: [String: EMACacheEntry] = [
            "AAPL": EMACacheEntry(day: 200.0, week: 210.0, month: 215.0, weekCrossoverWeeksBelow: nil),
        ]

        vm.update(watchlist: ["AAPL"], quotes: quotes, quarterPrices: [:], quarterInfos: testQuarters, emaEntries: emaEntries)
        vm.switchMode(.emas)

        XCTAssertEqual(vm.emaDayRows[0].id, "AAPL-ema-day")
        XCTAssertEqual(vm.emaWeekRows[0].id, "AAPL-ema-week")
        XCTAssertEqual(vm.emaMonthRows[0].id, "AAPL-ema-month")
    }

    func testEMAs_percentCalculation() {
        let vm = QuarterlyPanelViewModel()

        let quotes: [String: StockQuote] = [
            "AAPL": makeQuote(symbol: "AAPL", price: 110.0),
        ]
        let emaEntries: [String: EMACacheEntry] = [
            "AAPL": EMACacheEntry(day: 100.0, week: nil, month: nil, weekCrossoverWeeksBelow: nil),
        ]

        vm.update(watchlist: ["AAPL"], quotes: quotes, quarterPrices: [:], quarterInfos: testQuarters, emaEntries: emaEntries)
        vm.switchMode(.emas)

        XCTAssertEqual(vm.emaDayRows[0].breakoutPercent!, 10.0, accuracy: 0.01)
    }

    func testIsEMAsMode_emas_true() {
        let vm = QuarterlyPanelViewModel()
        vm.update(watchlist: [], quotes: [:], quarterPrices: [:], quarterInfos: testQuarters)
        vm.switchMode(.emas)
        XCTAssertTrue(vm.isEMAsMode)
    }

    func testIsEMAsMode_sinceQuarter_false() {
        let vm = QuarterlyPanelViewModel()
        vm.update(watchlist: [], quotes: [:], quarterPrices: [:], quarterInfos: testQuarters)
        XCTAssertFalse(vm.isEMAsMode)
    }

    func testEMAs_weekRows_aboveEMA() {
        let vm = QuarterlyPanelViewModel()

        let quotes: [String: StockQuote] = [
            "AAPL": makeQuote(symbol: "AAPL", price: 220.0),
        ]
        let emaEntries: [String: EMACacheEntry] = [
            "AAPL": EMACacheEntry(day: nil, week: 200.0, month: nil, weekCrossoverWeeksBelow: nil),
        ]

        vm.update(watchlist: ["AAPL"], quotes: quotes, quarterPrices: [:], quarterInfos: testQuarters, emaEntries: emaEntries)
        vm.switchMode(.emas)

        XCTAssertTrue(vm.emaDayRows.isEmpty)
        XCTAssertEqual(vm.emaWeekRows.count, 1)
        XCTAssertTrue(vm.emaMonthRows.isEmpty)
    }

    func testEMAs_monthRows_aboveEMA() {
        let vm = QuarterlyPanelViewModel()

        let quotes: [String: StockQuote] = [
            "AAPL": makeQuote(symbol: "AAPL", price: 220.0),
        ]
        let emaEntries: [String: EMACacheEntry] = [
            "AAPL": EMACacheEntry(day: nil, week: nil, month: 200.0, weekCrossoverWeeksBelow: nil),
        ]

        vm.update(watchlist: ["AAPL"], quotes: quotes, quarterPrices: [:], quarterInfos: testQuarters, emaEntries: emaEntries)
        vm.switchMode(.emas)

        XCTAssertTrue(vm.emaDayRows.isEmpty)
        XCTAssertTrue(vm.emaWeekRows.isEmpty)
        XCTAssertEqual(vm.emaMonthRows.count, 1)
        XCTAssertTrue(vm.emaAllRows.isEmpty)
    }

    func testEMAs_allRows_symbolInAllThree() {
        let vm = QuarterlyPanelViewModel()

        let quotes: [String: StockQuote] = [
            "AAPL": makeQuote(symbol: "AAPL", price: 220.0),
            "MSFT": makeQuote(symbol: "MSFT", price: 400.0),
        ]
        let emaEntries: [String: EMACacheEntry] = [
            "AAPL": EMACacheEntry(day: 200.0, week: 210.0, month: 215.0, weekCrossoverWeeksBelow: nil),
            "MSFT": EMACacheEntry(day: 380.0, week: nil, month: 390.0, weekCrossoverWeeksBelow: nil),
        ]

        vm.update(watchlist: ["AAPL", "MSFT"], quotes: quotes, quarterPrices: [:], quarterInfos: testQuarters, emaEntries: emaEntries)
        vm.switchMode(.emas)

        XCTAssertEqual(vm.emaAllRows.count, 1)
        XCTAssertEqual(vm.emaAllRows[0].symbol, "AAPL")
        XCTAssertEqual(vm.emaAllRows[0].id, "AAPL-ema-all")
    }

    func testEMAs_allRows_emptyWhenNotInAll() {
        let vm = QuarterlyPanelViewModel()

        let quotes: [String: StockQuote] = [
            "AAPL": makeQuote(symbol: "AAPL", price: 220.0),
        ]
        let emaEntries: [String: EMACacheEntry] = [
            "AAPL": EMACacheEntry(day: 200.0, week: 200.0, month: nil, weekCrossoverWeeksBelow: nil),
        ]

        vm.update(watchlist: ["AAPL"], quotes: quotes, quarterPrices: [:], quarterInfos: testQuarters, emaEntries: emaEntries)
        vm.switchMode(.emas)

        XCTAssertEqual(vm.emaDayRows.count, 1)
        XCTAssertEqual(vm.emaWeekRows.count, 1)
        XCTAssertTrue(vm.emaMonthRows.isEmpty)
        XCTAssertTrue(vm.emaAllRows.isEmpty)
    }

    func testEMAs_allRows_showForwardPE() {
        let vm = QuarterlyPanelViewModel()

        let quotes: [String: StockQuote] = [
            "AAPL": makeQuote(symbol: "AAPL", price: 220.0),
        ]
        let emaEntries: [String: EMACacheEntry] = [
            "AAPL": EMACacheEntry(day: 200.0, week: 210.0, month: 215.0, weekCrossoverWeeksBelow: nil),
        ]
        let currentForwardPEs: [String: Double] = ["AAPL": 28.5]

        vm.update(watchlist: ["AAPL"], quotes: quotes, quarterPrices: [:], quarterInfos: testQuarters, currentForwardPEs: currentForwardPEs, emaEntries: emaEntries)
        vm.switchMode(.emas)

        XCTAssertEqual(vm.emaAllRows[0].currentForwardPE, 28.5)
        XCTAssertNil(vm.emaAllRows[0].breakoutPercent)
    }

    func testEMAs_allRows_noForwardPE_showsNil() {
        let vm = QuarterlyPanelViewModel()

        let quotes: [String: StockQuote] = [
            "AAPL": makeQuote(symbol: "AAPL", price: 220.0),
        ]
        let emaEntries: [String: EMACacheEntry] = [
            "AAPL": EMACacheEntry(day: 200.0, week: 210.0, month: 215.0, weekCrossoverWeeksBelow: nil),
        ]

        vm.update(watchlist: ["AAPL"], quotes: quotes, quarterPrices: [:], quarterInfos: testQuarters, emaEntries: emaEntries)
        vm.switchMode(.emas)

        XCTAssertNil(vm.emaAllRows[0].currentForwardPE)
    }

    // MARK: - 5W Cross (Weekly Crossover)

    func testEMAs_crossRows_withCrossover() {
        let vm = QuarterlyPanelViewModel()

        let quotes: [String: StockQuote] = [
            "AAPL": makeQuote(symbol: "AAPL", price: 220.0),
        ]
        let emaEntries: [String: EMACacheEntry] = [
            "AAPL": EMACacheEntry(day: 200.0, week: 210.0, month: 215.0, weekCrossoverWeeksBelow: 3),
        ]

        vm.update(watchlist: ["AAPL"], quotes: quotes, quarterPrices: [:], quarterInfos: testQuarters, emaEntries: emaEntries)
        vm.switchMode(.emas)

        XCTAssertEqual(vm.emaCrossRows.count, 1)
        XCTAssertEqual(vm.emaCrossRows[0].symbol, "AAPL")
        XCTAssertEqual(vm.emaCrossRows[0].id, "AAPL-ema-cross")
        XCTAssertEqual(vm.emaCrossRows[0].breakoutPercent!, 3.0, accuracy: 0.01)
    }

    func testEMAs_crossRows_noCrossover() {
        let vm = QuarterlyPanelViewModel()

        let quotes: [String: StockQuote] = [
            "AAPL": makeQuote(symbol: "AAPL", price: 220.0),
        ]
        let emaEntries: [String: EMACacheEntry] = [
            "AAPL": EMACacheEntry(day: 200.0, week: 210.0, month: 215.0, weekCrossoverWeeksBelow: nil),
        ]

        vm.update(watchlist: ["AAPL"], quotes: quotes, quarterPrices: [:], quarterInfos: testQuarters, emaEntries: emaEntries)
        vm.switchMode(.emas)

        XCTAssertTrue(vm.emaCrossRows.isEmpty)
    }

    func testEMAs_crossRows_multipleSymbols() {
        let vm = QuarterlyPanelViewModel()

        let quotes: [String: StockQuote] = [
            "AAPL": makeQuote(symbol: "AAPL", price: 220.0),
            "MSFT": makeQuote(symbol: "MSFT", price: 400.0),
        ]
        let emaEntries: [String: EMACacheEntry] = [
            "AAPL": EMACacheEntry(day: 200.0, week: 210.0, month: nil, weekCrossoverWeeksBelow: 2),
            "MSFT": EMACacheEntry(day: 380.0, week: nil, month: nil, weekCrossoverWeeksBelow: nil),
        ]

        vm.update(watchlist: ["AAPL", "MSFT"], quotes: quotes, quarterPrices: [:], quarterInfos: testQuarters, emaEntries: emaEntries)
        vm.switchMode(.emas)

        XCTAssertEqual(vm.emaCrossRows.count, 1)
        XCTAssertEqual(vm.emaCrossRows[0].symbol, "AAPL")
    }
}

// MARK: - QuarterlySortColumn Equality Tests

final class QuarterlySortColumnTests: XCTestCase {

    func testEquality_symbol() {
        XCTAssertEqual(QuarterlySortColumn.symbol, QuarterlySortColumn.symbol)
    }

    func testEquality_sameQuarter() {
        XCTAssertEqual(QuarterlySortColumn.quarter("Q4-2025"), QuarterlySortColumn.quarter("Q4-2025"))
    }

    func testInequality_differentQuarters() {
        XCTAssertNotEqual(QuarterlySortColumn.quarter("Q4-2025"), QuarterlySortColumn.quarter("Q3-2025"))
    }

    func testInequality_symbolVsQuarter() {
        XCTAssertNotEqual(QuarterlySortColumn.symbol, QuarterlySortColumn.quarter("Q4-2025"))
    }

    func testEquality_date() {
        XCTAssertEqual(QuarterlySortColumn.date, QuarterlySortColumn.date)
    }

    func testEquality_priceBreakPercent() {
        XCTAssertEqual(QuarterlySortColumn.priceBreakPercent, QuarterlySortColumn.priceBreakPercent)
    }

    func testInequality_dateVsPriceBreakPercent() {
        XCTAssertNotEqual(QuarterlySortColumn.date, QuarterlySortColumn.priceBreakPercent)
    }

    func testEquality_rsi() {
        XCTAssertEqual(QuarterlySortColumn.rsi, QuarterlySortColumn.rsi)
    }
}
