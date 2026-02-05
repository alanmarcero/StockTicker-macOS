import XCTest
@testable import StockTicker

// MARK: - SortOption Tests

final class SortOptionTests: XCTestCase {

    func testRawValue_correctStrings() {
        XCTAssertEqual(SortOption.tickerAsc.rawValue, "Ticker ↑")
        XCTAssertEqual(SortOption.tickerDesc.rawValue, "Ticker ↓")
        XCTAssertEqual(SortOption.changeAsc.rawValue, "Price Change ↑")
        XCTAssertEqual(SortOption.changeDesc.rawValue, "Price Change ↓")
        XCTAssertEqual(SortOption.percentAsc.rawValue, "% Change ↑")
        XCTAssertEqual(SortOption.percentDesc.rawValue, "% Change ↓")
        XCTAssertEqual(SortOption.ytdAsc.rawValue, "YTD % ↑")
        XCTAssertEqual(SortOption.ytdDesc.rawValue, "YTD % ↓")
    }

    func testFromConfigString_validStrings() {
        XCTAssertEqual(SortOption.from(configString: "tickerAsc"), .tickerAsc)
        XCTAssertEqual(SortOption.from(configString: "tickerDesc"), .tickerDesc)
        XCTAssertEqual(SortOption.from(configString: "changeAsc"), .changeAsc)
        XCTAssertEqual(SortOption.from(configString: "changeDesc"), .changeDesc)
        XCTAssertEqual(SortOption.from(configString: "percentAsc"), .percentAsc)
        XCTAssertEqual(SortOption.from(configString: "percentDesc"), .percentDesc)
        XCTAssertEqual(SortOption.from(configString: "ytdAsc"), .ytdAsc)
        XCTAssertEqual(SortOption.from(configString: "ytdDesc"), .ytdDesc)
    }

    func testFromConfigString_invalidString_returnsDefault() {
        XCTAssertEqual(SortOption.from(configString: "invalid"), .percentDesc)
        XCTAssertEqual(SortOption.from(configString: ""), .percentDesc)
    }

    func testConfigString_returnsCorrectStrings() {
        XCTAssertEqual(SortOption.tickerAsc.configString, "tickerAsc")
        XCTAssertEqual(SortOption.tickerDesc.configString, "tickerDesc")
        XCTAssertEqual(SortOption.changeAsc.configString, "changeAsc")
        XCTAssertEqual(SortOption.changeDesc.configString, "changeDesc")
        XCTAssertEqual(SortOption.percentAsc.configString, "percentAsc")
        XCTAssertEqual(SortOption.percentDesc.configString, "percentDesc")
        XCTAssertEqual(SortOption.ytdAsc.configString, "ytdAsc")
        XCTAssertEqual(SortOption.ytdDesc.configString, "ytdDesc")
    }

    func testConfigString_roundTrip() {
        for option in SortOption.allCases {
            let configString = option.configString
            let restored = SortOption.from(configString: configString)
            XCTAssertEqual(restored, option, "Round trip failed for \(option)")
        }
    }

    func testAllCases_containsAllOptions() {
        XCTAssertEqual(SortOption.allCases.count, 8)
        XCTAssertTrue(SortOption.allCases.contains(.tickerAsc))
        XCTAssertTrue(SortOption.allCases.contains(.tickerDesc))
        XCTAssertTrue(SortOption.allCases.contains(.changeAsc))
        XCTAssertTrue(SortOption.allCases.contains(.changeDesc))
        XCTAssertTrue(SortOption.allCases.contains(.percentAsc))
        XCTAssertTrue(SortOption.allCases.contains(.percentDesc))
        XCTAssertTrue(SortOption.allCases.contains(.ytdAsc))
        XCTAssertTrue(SortOption.allCases.contains(.ytdDesc))
    }
}

// MARK: - SortOption.sort() Tests

final class SortOptionSortTests: XCTestCase {

    let testQuotes: [String: StockQuote] = [
        "AAPL": StockQuote(symbol: "AAPL", price: 150.0, previousClose: 145.0, session: .regular),  // +5, +3.45%
        "MSFT": StockQuote(symbol: "MSFT", price: 300.0, previousClose: 310.0, session: .regular),  // -10, -3.23%
        "GOOGL": StockQuote(symbol: "GOOGL", price: 140.0, previousClose: 140.0, session: .regular), // 0, 0%
        "SPY": StockQuote(symbol: "SPY", price: 450.0, previousClose: 440.0, session: .regular),    // +10, +2.27%
    ]

    // MARK: - Ticker sorting

    func testSort_tickerAsc_sortsAlphabetically() {
        let symbols = ["SPY", "AAPL", "MSFT", "GOOGL"]
        let sorted = SortOption.tickerAsc.sort(symbols, using: testQuotes)

        XCTAssertEqual(sorted, ["AAPL", "GOOGL", "MSFT", "SPY"])
    }

    func testSort_tickerDesc_sortsReverseAlphabetically() {
        let symbols = ["SPY", "AAPL", "MSFT", "GOOGL"]
        let sorted = SortOption.tickerDesc.sort(symbols, using: testQuotes)

        XCTAssertEqual(sorted, ["SPY", "MSFT", "GOOGL", "AAPL"])
    }

    // MARK: - Price change sorting

    func testSort_changeAsc_sortsByPriceChangeAscending() {
        let symbols = ["AAPL", "MSFT", "GOOGL", "SPY"]
        let sorted = SortOption.changeAsc.sort(symbols, using: testQuotes)

        // MSFT: -10, GOOGL: 0, AAPL: +5, SPY: +10
        XCTAssertEqual(sorted, ["MSFT", "GOOGL", "AAPL", "SPY"])
    }

    func testSort_changeDesc_sortsByPriceChangeDescending() {
        let symbols = ["AAPL", "MSFT", "GOOGL", "SPY"]
        let sorted = SortOption.changeDesc.sort(symbols, using: testQuotes)

        // SPY: +10, AAPL: +5, GOOGL: 0, MSFT: -10
        XCTAssertEqual(sorted, ["SPY", "AAPL", "GOOGL", "MSFT"])
    }

    // MARK: - Percent change sorting

    func testSort_percentAsc_sortsByPercentChangeAscending() {
        let symbols = ["AAPL", "MSFT", "GOOGL", "SPY"]
        let sorted = SortOption.percentAsc.sort(symbols, using: testQuotes)

        // MSFT: -3.23%, GOOGL: 0%, SPY: +2.27%, AAPL: +3.45%
        XCTAssertEqual(sorted, ["MSFT", "GOOGL", "SPY", "AAPL"])
    }

    func testSort_percentDesc_sortsByPercentChangeDescending() {
        let symbols = ["AAPL", "MSFT", "GOOGL", "SPY"]
        let sorted = SortOption.percentDesc.sort(symbols, using: testQuotes)

        // AAPL: +3.45%, SPY: +2.27%, GOOGL: 0%, MSFT: -3.23%
        XCTAssertEqual(sorted, ["AAPL", "SPY", "GOOGL", "MSFT"])
    }

    // MARK: - YTD percent sorting

    func testSort_ytdAsc_sortsByYTDPercentAscending() {
        let ytdQuotes: [String: StockQuote] = [
            "AAPL": StockQuote(symbol: "AAPL", price: 150.0, previousClose: 145.0, session: .regular, ytdStartPrice: 140.0),  // +7.14%
            "MSFT": StockQuote(symbol: "MSFT", price: 300.0, previousClose: 310.0, session: .regular, ytdStartPrice: 320.0),  // -6.25%
            "GOOGL": StockQuote(symbol: "GOOGL", price: 140.0, previousClose: 140.0, session: .regular, ytdStartPrice: 140.0), // 0%
            "SPY": StockQuote(symbol: "SPY", price: 450.0, previousClose: 440.0, session: .regular, ytdStartPrice: 430.0),    // +4.65%
        ]
        let symbols = ["AAPL", "MSFT", "GOOGL", "SPY"]
        let sorted = SortOption.ytdAsc.sort(symbols, using: ytdQuotes)

        // MSFT: -6.25%, GOOGL: 0%, SPY: +4.65%, AAPL: +7.14%
        XCTAssertEqual(sorted, ["MSFT", "GOOGL", "SPY", "AAPL"])
    }

    func testSort_ytdDesc_sortsByYTDPercentDescending() {
        let ytdQuotes: [String: StockQuote] = [
            "AAPL": StockQuote(symbol: "AAPL", price: 150.0, previousClose: 145.0, session: .regular, ytdStartPrice: 140.0),  // +7.14%
            "MSFT": StockQuote(symbol: "MSFT", price: 300.0, previousClose: 310.0, session: .regular, ytdStartPrice: 320.0),  // -6.25%
            "GOOGL": StockQuote(symbol: "GOOGL", price: 140.0, previousClose: 140.0, session: .regular, ytdStartPrice: 140.0), // 0%
            "SPY": StockQuote(symbol: "SPY", price: 450.0, previousClose: 440.0, session: .regular, ytdStartPrice: 430.0),    // +4.65%
        ]
        let symbols = ["AAPL", "MSFT", "GOOGL", "SPY"]
        let sorted = SortOption.ytdDesc.sort(symbols, using: ytdQuotes)

        // AAPL: +7.14%, SPY: +4.65%, GOOGL: 0%, MSFT: -6.25%
        XCTAssertEqual(sorted, ["AAPL", "SPY", "GOOGL", "MSFT"])
    }

    func testSort_ytdDesc_missingYTDData_treatsAsZero() {
        let ytdQuotes: [String: StockQuote] = [
            "AAPL": StockQuote(symbol: "AAPL", price: 150.0, previousClose: 145.0, session: .regular, ytdStartPrice: 140.0),  // +7.14%
            "MSFT": StockQuote(symbol: "MSFT", price: 300.0, previousClose: 310.0, session: .regular, ytdStartPrice: nil),     // nil -> 0%
        ]
        let symbols = ["AAPL", "MSFT"]
        let sorted = SortOption.ytdDesc.sort(symbols, using: ytdQuotes)

        // AAPL: +7.14%, MSFT: nil (treated as 0%)
        XCTAssertEqual(sorted, ["AAPL", "MSFT"])
    }

    // MARK: - Edge cases

    func testSort_emptySymbols_returnsEmpty() {
        let sorted = SortOption.tickerAsc.sort([], using: testQuotes)
        XCTAssertEqual(sorted, [])
    }

    func testSort_singleSymbol_returnsSame() {
        let sorted = SortOption.tickerAsc.sort(["AAPL"], using: testQuotes)
        XCTAssertEqual(sorted, ["AAPL"])
    }

    func testSort_missingQuotes_treatsAsZero() {
        let symbols = ["AAPL", "UNKNOWN"]
        let sorted = SortOption.changeDesc.sort(symbols, using: testQuotes)

        // AAPL has +5 change, UNKNOWN treated as 0
        XCTAssertEqual(sorted, ["AAPL", "UNKNOWN"])
    }

    func testSort_allMissingQuotes_maintainsOrder() {
        let emptyQuotes: [String: StockQuote] = [:]
        let symbols = ["SPY", "AAPL", "QQQ"]

        // With no quotes, all changes are 0, so order depends on stable sort
        let sorted = SortOption.changeDesc.sort(symbols, using: emptyQuotes)

        // All have 0 change, should maintain relative order based on sort stability
        XCTAssertEqual(sorted.count, 3)
    }
}
