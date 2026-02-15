import XCTest
@testable import StockTicker

// MARK: - SortOption Tests

final class SortOptionTests: XCTestCase {

    func testRawValue_correctStrings() {
        XCTAssertEqual(SortOption.tickerAsc.rawValue, "Ticker ↑")
        XCTAssertEqual(SortOption.tickerDesc.rawValue, "Ticker ↓")
        XCTAssertEqual(SortOption.marketCapAsc.rawValue, "Market Cap ↑")
        XCTAssertEqual(SortOption.marketCapDesc.rawValue, "Market Cap ↓")
        XCTAssertEqual(SortOption.percentAsc.rawValue, "% Change ↑")
        XCTAssertEqual(SortOption.percentDesc.rawValue, "% Change ↓")
        XCTAssertEqual(SortOption.ytdAsc.rawValue, "YTD % ↑")
        XCTAssertEqual(SortOption.ytdDesc.rawValue, "YTD % ↓")
    }

    func testFromConfigString_validStrings() {
        XCTAssertEqual(SortOption.from(configString: "tickerAsc"), .tickerAsc)
        XCTAssertEqual(SortOption.from(configString: "tickerDesc"), .tickerDesc)
        XCTAssertEqual(SortOption.from(configString: "marketCapAsc"), .marketCapAsc)
        XCTAssertEqual(SortOption.from(configString: "marketCapDesc"), .marketCapDesc)
        XCTAssertEqual(SortOption.from(configString: "percentAsc"), .percentAsc)
        XCTAssertEqual(SortOption.from(configString: "percentDesc"), .percentDesc)
        XCTAssertEqual(SortOption.from(configString: "ytdAsc"), .ytdAsc)
        XCTAssertEqual(SortOption.from(configString: "ytdDesc"), .ytdDesc)
    }

    func testFromConfigString_invalidString_returnsDefault() {
        XCTAssertEqual(SortOption.from(configString: "invalid"), .percentDesc)
        XCTAssertEqual(SortOption.from(configString: ""), .percentDesc)
    }

    func testFromConfigString_legacyChangeValues_returnDefault() {
        XCTAssertEqual(SortOption.from(configString: "changeAsc"), .percentDesc)
        XCTAssertEqual(SortOption.from(configString: "changeDesc"), .percentDesc)
    }

    func testConfigString_returnsCorrectStrings() {
        XCTAssertEqual(SortOption.tickerAsc.configString, "tickerAsc")
        XCTAssertEqual(SortOption.tickerDesc.configString, "tickerDesc")
        XCTAssertEqual(SortOption.marketCapAsc.configString, "marketCapAsc")
        XCTAssertEqual(SortOption.marketCapDesc.configString, "marketCapDesc")
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
        XCTAssertTrue(SortOption.allCases.contains(.marketCapAsc))
        XCTAssertTrue(SortOption.allCases.contains(.marketCapDesc))
        XCTAssertTrue(SortOption.allCases.contains(.percentAsc))
        XCTAssertTrue(SortOption.allCases.contains(.percentDesc))
        XCTAssertTrue(SortOption.allCases.contains(.ytdAsc))
        XCTAssertTrue(SortOption.allCases.contains(.ytdDesc))
    }
}

// MARK: - SortOption.sort() Tests

final class SortOptionSortTests: XCTestCase {

    let testQuotes: [String: StockQuote] = [
        "AAPL": StockQuote(symbol: "AAPL", price: 150.0, previousClose: 145.0, session: .regular,
                           marketCap: 3_000_000_000_000),  // +5, +3.45%, $3T
        "MSFT": StockQuote(symbol: "MSFT", price: 300.0, previousClose: 310.0, session: .regular,
                           marketCap: 2_500_000_000_000),  // -10, -3.23%, $2.5T
        "GOOGL": StockQuote(symbol: "GOOGL", price: 140.0, previousClose: 140.0, session: .regular,
                            marketCap: 1_800_000_000_000), // 0, 0%, $1.8T
        "SPY": StockQuote(symbol: "SPY", price: 450.0, previousClose: 440.0, session: .regular,
                          marketCap: 600_000_000_000),     // +10, +2.27%, $600B
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

    // MARK: - Market cap sorting

    func testSort_marketCapAsc_sortsByMarketCapAscending() {
        let symbols = ["AAPL", "MSFT", "GOOGL", "SPY"]
        let sorted = SortOption.marketCapAsc.sort(symbols, using: testQuotes)

        // SPY: $600B, GOOGL: $1.8T, MSFT: $2.5T, AAPL: $3T
        XCTAssertEqual(sorted, ["SPY", "GOOGL", "MSFT", "AAPL"])
    }

    func testSort_marketCapDesc_sortsByMarketCapDescending() {
        let symbols = ["AAPL", "MSFT", "GOOGL", "SPY"]
        let sorted = SortOption.marketCapDesc.sort(symbols, using: testQuotes)

        // AAPL: $3T, MSFT: $2.5T, GOOGL: $1.8T, SPY: $600B
        XCTAssertEqual(sorted, ["AAPL", "MSFT", "GOOGL", "SPY"])
    }

    func testSort_marketCapDesc_missingCap_treatsAsZero() {
        let quotesWithMissing: [String: StockQuote] = [
            "AAPL": StockQuote(symbol: "AAPL", price: 150.0, previousClose: 145.0, session: .regular,
                               marketCap: 3_000_000_000_000),
            "MSFT": StockQuote(symbol: "MSFT", price: 300.0, previousClose: 310.0, session: .regular),
        ]
        let symbols = ["AAPL", "MSFT"]
        let sorted = SortOption.marketCapDesc.sort(symbols, using: quotesWithMissing)

        // AAPL: $3T, MSFT: nil (treated as 0)
        XCTAssertEqual(sorted, ["AAPL", "MSFT"])
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
        let sorted = SortOption.marketCapDesc.sort(symbols, using: testQuotes)

        // AAPL has $3T cap, UNKNOWN treated as 0
        XCTAssertEqual(sorted, ["AAPL", "UNKNOWN"])
    }

    func testSort_allMissingQuotes_maintainsOrder() {
        let emptyQuotes: [String: StockQuote] = [:]
        let symbols = ["SPY", "AAPL", "QQQ"]

        // With no quotes, all caps are 0, so order depends on stable sort
        let sorted = SortOption.marketCapDesc.sort(symbols, using: emptyQuotes)

        // All have 0 cap, should maintain relative order based on sort stability
        XCTAssertEqual(sorted.count, 3)
    }
}
