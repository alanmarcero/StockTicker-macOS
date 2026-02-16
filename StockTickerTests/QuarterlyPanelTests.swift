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
}
