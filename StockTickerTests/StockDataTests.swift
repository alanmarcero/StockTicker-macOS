import XCTest
@testable import StockTicker

// MARK: - TradingSession Tests

final class TradingSessionTests: XCTestCase {

    func testInit_regularState_returnsRegular() {
        XCTAssertEqual(TradingSession(fromYahooState: "REGULAR"), .regular)
    }

    func testInit_preState_returnsPreMarket() {
        XCTAssertEqual(TradingSession(fromYahooState: "PRE"), .preMarket)
    }

    func testInit_prepreState_returnsPreMarket() {
        XCTAssertEqual(TradingSession(fromYahooState: "PREPRE"), .preMarket)
    }

    func testInit_postState_returnsAfterHours() {
        XCTAssertEqual(TradingSession(fromYahooState: "POST"), .afterHours)
    }

    func testInit_postpostState_returnsAfterHours() {
        XCTAssertEqual(TradingSession(fromYahooState: "POSTPOST"), .afterHours)
    }

    func testInit_closedState_returnsClosed() {
        XCTAssertEqual(TradingSession(fromYahooState: "CLOSED"), .closed)
    }

    func testInit_nilState_returnsClosed() {
        XCTAssertEqual(TradingSession(fromYahooState: nil), .closed)
    }

    func testInit_unknownState_returnsClosed() {
        XCTAssertEqual(TradingSession(fromYahooState: "UNKNOWN"), .closed)
    }

    func testInit_caseInsensitive() {
        XCTAssertEqual(TradingSession(fromYahooState: "regular"), .regular)
        XCTAssertEqual(TradingSession(fromYahooState: "pre"), .preMarket)
        XCTAssertEqual(TradingSession(fromYahooState: "post"), .afterHours)
    }
}

// MARK: - StockQuote Tests

final class StockQuoteTests: XCTestCase {

    // MARK: - Basic properties

    func testChange_calculatedFromPriceAndPreviousClose() {
        let quote = StockQuote(
            symbol: "AAPL",
            price: 150.0,
            previousClose: 148.0,
            session: .regular
        )
        XCTAssertEqual(quote.change, 2.0, accuracy: 0.001)
    }

    func testChangePercent_calculatedCorrectly() {
        let quote = StockQuote(
            symbol: "AAPL",
            price: 150.0,
            previousClose: 100.0,
            session: .regular
        )
        XCTAssertEqual(quote.changePercent, 50.0, accuracy: 0.001)
    }

    func testChangePercent_negativeChange() {
        let quote = StockQuote(
            symbol: "AAPL",
            price: 90.0,
            previousClose: 100.0,
            session: .regular
        )
        XCTAssertEqual(quote.changePercent, -10.0, accuracy: 0.001)
    }

    func testIsPositive_positiveChange_returnsTrue() {
        let quote = StockQuote(
            symbol: "AAPL",
            price: 150.0,
            previousClose: 148.0,
            session: .regular
        )
        XCTAssertTrue(quote.isPositive)
    }

    func testIsPositive_negativeChange_returnsFalse() {
        let quote = StockQuote(
            symbol: "AAPL",
            price: 145.0,
            previousClose: 148.0,
            session: .regular
        )
        XCTAssertFalse(quote.isPositive)
    }

    func testIsPositive_noChange_returnsTrue() {
        let quote = StockQuote(
            symbol: "AAPL",
            price: 148.0,
            previousClose: 148.0,
            session: .regular
        )
        XCTAssertTrue(quote.isPositive)
    }

    // MARK: - Placeholder

    func testPlaceholder_hasCorrectValues() {
        let placeholder = StockQuote.placeholder(symbol: "AAPL")
        XCTAssertEqual(placeholder.symbol, "AAPL")
        XCTAssertEqual(placeholder.price, 0)
        XCTAssertEqual(placeholder.previousClose, 0)
        XCTAssertTrue(placeholder.isPlaceholder)
    }

    func testIsPlaceholder_regularQuote_returnsFalse() {
        let quote = StockQuote(
            symbol: "AAPL",
            price: 150.0,
            previousClose: 148.0,
            session: .regular
        )
        XCTAssertFalse(quote.isPlaceholder)
    }

    // MARK: - Extended hours

    func testExtendedHoursSuffix_regularSession_isEmpty() {
        let quote = StockQuote(
            symbol: "AAPL",
            price: 150.0,
            previousClose: 148.0,
            session: .regular
        )
        XCTAssertEqual(quote.extendedHoursSuffix, "")
    }

    func testExtendedHoursSuffix_preMarketWithPrice_returnsPre() {
        let quote = StockQuote(
            symbol: "AAPL",
            price: 150.0,
            previousClose: 148.0,
            session: .preMarket,
            preMarketPrice: 151.0
        )
        XCTAssertEqual(quote.extendedHoursSuffix, " (Pre)")
    }

    func testExtendedHoursSuffix_afterHoursWithPrice_returnsAfter() {
        let quote = StockQuote(
            symbol: "AAPL",
            price: 150.0,
            previousClose: 148.0,
            session: .afterHours,
            postMarketPrice: 152.0
        )
        XCTAssertEqual(quote.extendedHoursSuffix, " (After)")
    }

    func testExtendedHoursSuffix_preMarketWithoutPrice_isEmpty() {
        let quote = StockQuote(
            symbol: "AAPL",
            price: 150.0,
            previousClose: 148.0,
            session: .preMarket
        )
        XCTAssertEqual(quote.extendedHoursSuffix, "")
    }

    // MARK: - Display values for extended hours

    func testDisplayChange_preMarket_usesPreMarketChange() {
        let quote = StockQuote(
            symbol: "AAPL",
            price: 150.0,
            previousClose: 148.0,
            session: .preMarket,
            preMarketPrice: 151.0,
            preMarketChange: 3.0,
            preMarketChangePercent: 2.0
        )
        XCTAssertEqual(quote.displayChange, 3.0)
        XCTAssertEqual(quote.displayChangePercent, 2.0)
    }

    func testDisplayChange_afterHours_usesPostMarketChange() {
        let quote = StockQuote(
            symbol: "AAPL",
            price: 150.0,
            previousClose: 148.0,
            session: .afterHours,
            postMarketPrice: 152.0,
            postMarketChange: 4.0,
            postMarketChangePercent: 2.67
        )
        XCTAssertEqual(quote.displayChange, 4.0)
        XCTAssertEqual(quote.displayChangePercent, 2.67)
    }

    func testDisplayChange_regularSession_usesRegularChange() {
        let quote = StockQuote(
            symbol: "AAPL",
            price: 150.0,
            previousClose: 148.0,
            session: .regular
        )
        XCTAssertEqual(quote.displayChange, 2.0, accuracy: 0.001)
        XCTAssertEqual(quote.displayChangePercent, 1.351, accuracy: 0.001)
    }

    // MARK: - Formatting

    func testFormattedPrice_formatsCurrency() {
        let quote = StockQuote(
            symbol: "AAPL",
            price: 150.50,
            previousClose: 148.0,
            session: .regular
        )
        XCTAssertEqual(quote.formattedPrice, "$150.50")
    }

    func testFormattedChange_positiveChange_includesPlus() {
        let quote = StockQuote(
            symbol: "AAPL",
            price: 150.0,
            previousClose: 148.0,
            session: .regular
        )
        XCTAssertTrue(quote.formattedChange.hasPrefix("+"))
    }

    func testFormattedChange_negativeChange_includesMinus() {
        let quote = StockQuote(
            symbol: "AAPL",
            price: 145.0,
            previousClose: 148.0,
            session: .regular
        )
        XCTAssertTrue(quote.formattedChange.hasPrefix("-"))
    }

    func testFormattedChangePercent_includesPercentSign() {
        let quote = StockQuote(
            symbol: "AAPL",
            price: 150.0,
            previousClose: 148.0,
            session: .regular
        )
        XCTAssertTrue(quote.formattedChangePercent.hasSuffix("%"))
    }

    // MARK: - Market Cap

    func testFormattedMarketCap_withValue_formatsAbbreviated() {
        let quote = StockQuote(
            symbol: "AAPL",
            price: 150.0,
            previousClose: 148.0,
            session: .regular,
            marketCap: 3_760_000_000_000
        )
        XCTAssertEqual(quote.formattedMarketCap, "$3.8T")
    }

    func testFormattedMarketCap_nilValue_returnsDash() {
        let quote = StockQuote(
            symbol: "AAPL",
            price: 150.0,
            previousClose: 148.0,
            session: .regular
        )
        XCTAssertEqual(quote.formattedMarketCap, "--")
    }

    func testWithMarketCap_preservesOtherFields() {
        let quote = StockQuote(
            symbol: "AAPL",
            price: 150.0,
            previousClose: 148.0,
            session: .regular,
            ytdStartPrice: 140.0,
            highestClose: 160.0
        )
        let updated = quote.withMarketCap(3_000_000_000_000)
        XCTAssertEqual(updated.symbol, "AAPL")
        XCTAssertEqual(updated.price, 150.0)
        XCTAssertEqual(updated.ytdStartPrice, 140.0)
        XCTAssertEqual(updated.marketCap, 3_000_000_000_000)
        XCTAssertEqual(updated.highestClose, 160.0)
    }

    func testWithYTDStartPrice_preservesMarketCap() {
        let quote = StockQuote(
            symbol: "AAPL",
            price: 150.0,
            previousClose: 148.0,
            session: .regular,
            marketCap: 3_000_000_000_000,
            highestClose: 160.0
        )
        let updated = quote.withYTDStartPrice(140.0)
        XCTAssertEqual(updated.ytdStartPrice, 140.0)
        XCTAssertEqual(updated.marketCap, 3_000_000_000_000)
        XCTAssertEqual(updated.highestClose, 160.0)
    }

    // MARK: - Highest Close Properties

    func testHighestCloseChangePercent_correctPercent() {
        let quote = StockQuote(symbol: "AAPL", price: 150.0, previousClose: 148.0, highestClose: 200.0)
        // (150-200)/200 * 100 = -25%
        XCTAssertEqual(quote.highestCloseChangePercent!, -25.0, accuracy: 0.01)
    }

    func testHighestCloseChangePercent_nilWhenMissing() {
        let quote = StockQuote(symbol: "AAPL", price: 150.0, previousClose: 148.0)
        XCTAssertNil(quote.highestCloseChangePercent)
    }

    func testHighestCloseChangePercent_zeroAtHigh() {
        let quote = StockQuote(symbol: "AAPL", price: 200.0, previousClose: 195.0, highestClose: 200.0)
        XCTAssertEqual(quote.highestCloseChangePercent!, 0.0, accuracy: 0.01)
    }

    func testHighestCloseChangePercent_positiveAboveHigh() {
        let quote = StockQuote(symbol: "AAPL", price: 220.0, previousClose: 210.0, highestClose: 200.0)
        // (220-200)/200 * 100 = 10%
        XCTAssertEqual(quote.highestCloseChangePercent!, 10.0, accuracy: 0.01)
    }

    func testFormattedHighestCloseChangePercent_formatting() {
        let quote = StockQuote(symbol: "AAPL", price: 150.0, previousClose: 148.0, highestClose: 200.0)
        XCTAssertEqual(quote.formattedHighestCloseChangePercent, "-25.00%")
    }

    func testFormattedHighestCloseChangePercent_nilWhenMissing() {
        let quote = StockQuote(symbol: "AAPL", price: 150.0, previousClose: 148.0)
        XCTAssertNil(quote.formattedHighestCloseChangePercent)
    }

    func testHighestCloseIsPositive_positive() {
        let quote = StockQuote(symbol: "AAPL", price: 220.0, previousClose: 210.0, highestClose: 200.0)
        XCTAssertTrue(quote.highestCloseIsPositive)
    }

    func testHighestCloseIsPositive_negative() {
        let quote = StockQuote(symbol: "AAPL", price: 150.0, previousClose: 148.0, highestClose: 200.0)
        XCTAssertFalse(quote.highestCloseIsPositive)
    }

    func testWithHighestClose_preservesOtherFields() {
        let quote = StockQuote(
            symbol: "AAPL",
            price: 150.0,
            previousClose: 148.0,
            session: .regular,
            ytdStartPrice: 140.0,
            marketCap: 3_000_000_000_000
        )
        let updated = quote.withHighestClose(200.0)
        XCTAssertEqual(updated.symbol, "AAPL")
        XCTAssertEqual(updated.price, 150.0)
        XCTAssertEqual(updated.ytdStartPrice, 140.0)
        XCTAssertEqual(updated.marketCap, 3_000_000_000_000)
        XCTAssertEqual(updated.highestClose, 200.0)
    }

    // MARK: - Extended hours with CLOSED session (time-based fallback)

    func testHasExtendedHoursData_closedSessionWithPostMarketData_usesTimeBased() {
        // When session is CLOSED but we have post market data, the time-based
        // detection should determine if we show it
        let quote = StockQuote(
            symbol: "AAPL",
            price: 150.0,
            previousClose: 148.0,
            session: .closed,
            postMarketPrice: 151.0,
            postMarketChange: 1.0,
            postMarketChangePercent: 0.67
        )
        // This will depend on current time, so we just verify the logic doesn't crash
        _ = quote.hasExtendedHoursData
        _ = quote.extendedHoursLabel
    }

    func testExtendedHoursLabel_afterHoursSession_returnsAH() {
        let quote = StockQuote(
            symbol: "AAPL",
            price: 150.0,
            previousClose: 148.0,
            session: .afterHours,
            postMarketChangePercent: 1.5
        )
        XCTAssertEqual(quote.extendedHoursLabel, "AH")
    }

    func testExtendedHoursLabel_preMarketSession_returnsPre() {
        let quote = StockQuote(
            symbol: "AAPL",
            price: 150.0,
            previousClose: 148.0,
            session: .preMarket,
            preMarketChangePercent: 0.5
        )
        XCTAssertEqual(quote.extendedHoursLabel, "Pre")
    }

    // MARK: - Time-based session detection

    func testCurrentTimeBasedSession_weekendReturnsClose() {
        // Create a date that's definitely a Saturday
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(identifier: "America/New_York")!

        var components = DateComponents()
        components.year = 2025
        components.month = 1
        components.day = 25  // Saturday
        components.hour = 12
        components.minute = 0
        components.timeZone = TimeZone(identifier: "America/New_York")!

        if let saturday = calendar.date(from: components) {
            let session = StockQuote.currentTimeBasedSession(date: saturday)
            XCTAssertEqual(session, .closed)
        }
    }

    func testCurrentTimeBasedSession_preMarketTime() {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(identifier: "America/New_York")!

        var components = DateComponents()
        components.year = 2025
        components.month = 1
        components.day = 27  // Monday
        components.hour = 6
        components.minute = 0
        components.timeZone = TimeZone(identifier: "America/New_York")!

        if let preMarketTime = calendar.date(from: components) {
            let session = StockQuote.currentTimeBasedSession(date: preMarketTime)
            XCTAssertEqual(session, .preMarket)
        }
    }

    func testCurrentTimeBasedSession_regularMarketTime() {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(identifier: "America/New_York")!

        var components = DateComponents()
        components.year = 2025
        components.month = 1
        components.day = 27  // Monday
        components.hour = 12
        components.minute = 0
        components.timeZone = TimeZone(identifier: "America/New_York")!

        if let regularTime = calendar.date(from: components) {
            let session = StockQuote.currentTimeBasedSession(date: regularTime)
            XCTAssertEqual(session, .regular)
        }
    }

    func testCurrentTimeBasedSession_afterHoursTime() {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(identifier: "America/New_York")!

        var components = DateComponents()
        components.year = 2025
        components.month = 1
        components.day = 27  // Monday
        components.hour = 17
        components.minute = 0
        components.timeZone = TimeZone(identifier: "America/New_York")!

        if let afterHoursTime = calendar.date(from: components) {
            let session = StockQuote.currentTimeBasedSession(date: afterHoursTime)
            XCTAssertEqual(session, .afterHours)
        }
    }

    func testCurrentTimeBasedSession_lateNightClosed() {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(identifier: "America/New_York")!

        var components = DateComponents()
        components.year = 2025
        components.month = 1
        components.day = 27  // Monday
        components.hour = 22
        components.minute = 0
        components.timeZone = TimeZone(identifier: "America/New_York")!

        if let lateNight = calendar.date(from: components) {
            let session = StockQuote.currentTimeBasedSession(date: lateNight)
            XCTAssertEqual(session, .closed)
        }
    }

    func testCurrentTimeBasedSession_holidayReturnsClosed() {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(identifier: "America/New_York")!

        // Presidents' Day 2026 (3rd Monday of February) at 5 PM — would be after-hours on a normal day
        var components = DateComponents()
        components.year = 2026
        components.month = 2
        components.day = 16
        components.hour = 17
        components.minute = 0
        components.timeZone = TimeZone(identifier: "America/New_York")!

        if let holiday = calendar.date(from: components) {
            let session = StockQuote.currentTimeBasedSession(date: holiday)
            XCTAssertEqual(session, .closed)
        }
    }

    func testCurrentTimeBasedSession_earlyCloseHolidayAllowsExtendedHours() {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(identifier: "America/New_York")!

        // Day after Thanksgiving 2026 (early close) at 5 PM — should be after-hours
        var components = DateComponents()
        components.year = 2026
        components.month = 11
        components.day = 27
        components.hour = 17
        components.minute = 0
        components.timeZone = TimeZone(identifier: "America/New_York")!

        if let earlyCloseDay = calendar.date(from: components) {
            let session = StockQuote.currentTimeBasedSession(date: earlyCloseDay)
            XCTAssertEqual(session, .afterHours)
        }
    }

    // MARK: - Extended hours period detection

    func testIsInExtendedHoursPeriod_dependsOnCurrentTime() {
        // This property uses currentTimeBasedSession internally
        // so results depend on when the test runs
        let quote = StockQuote(
            symbol: "AAPL",
            price: 150.0,
            previousClose: 148.0,
            session: .regular
        )
        // Just verify it returns a bool and doesn't crash
        _ = quote.isInExtendedHoursPeriod
    }

    func testExtendedHoursPeriodLabel_dependsOnCurrentTime() {
        // This property uses currentTimeBasedSession internally
        let quote = StockQuote(
            symbol: "AAPL",
            price: 150.0,
            previousClose: 148.0,
            session: .regular
        )
        // Just verify it returns expected type and doesn't crash
        let label = quote.extendedHoursPeriodLabel
        if label != nil {
            XCTAssertTrue(label == "Pre" || label == "AH")
        }
    }

    func testShouldShowExtendedHours_noDataDuringExtendedPeriod_returnsFalse() {
        // Even if we're in extended hours period, shouldShowExtendedHours
        // should return false when no extended hours data is available
        let quote = StockQuote(
            symbol: "AAPL",
            price: 150.0,
            previousClose: 148.0,
            session: .closed  // No extended hours data
        )
        // shouldShowExtendedHours requires both:
        // 1. Current time is in extended hours period
        // 2. Extended hours data is available
        // Without data, this should return false regardless of time
        XCTAssertFalse(quote.shouldShowExtendedHours)
    }
}

// MARK: - Formatting Helper Tests

final class FormattingTests: XCTestCase {

    func testCurrency_formatsWithCommas() {
        XCTAssertEqual(Formatting.currency(150.50), "$150.50")
        XCTAssertEqual(Formatting.currency(1234.56), "$1,234.56")
        XCTAssertEqual(Formatting.currency(0.99), "$0.99")
        XCTAssertEqual(Formatting.currency(10000.00), "$10,000.00")
    }

    func testSignedCurrency_positiveValue() {
        XCTAssertEqual(Formatting.signedCurrency(2.50, isPositive: true), "+$2.50")
    }

    func testSignedCurrency_negativeValue() {
        XCTAssertEqual(Formatting.signedCurrency(-2.50, isPositive: false), "-$2.50")
    }

    func testSignedCurrency_largeValue_hasCommas() {
        XCTAssertEqual(Formatting.signedCurrency(1234.56, isPositive: true), "+$1,234.56")
    }

    func testSignedPercent_positiveValue() {
        XCTAssertEqual(Formatting.signedPercent(5.25, isPositive: true), "+5.25%")
    }

    func testSignedPercent_negativeValue() {
        XCTAssertEqual(Formatting.signedPercent(-5.25, isPositive: false), "-5.25%")
    }

    func testSignedPercent_zero() {
        XCTAssertEqual(Formatting.signedPercent(0, isPositive: true), "+0.00%")
    }

    // MARK: - Market Cap Formatting

    func testMarketCap_trillions_oneDecimal() {
        XCTAssertEqual(Formatting.marketCap(3_760_000_000_000), "$3.8T")
        XCTAssertEqual(Formatting.marketCap(1_100_000_000_000), "$1.1T")
    }

    func testMarketCap_trillions_largeNoDecimal() {
        XCTAssertEqual(Formatting.marketCap(100_000_000_000_000), "$100T")
    }

    func testMarketCap_billions_threeDigitNoDecimal() {
        XCTAssertEqual(Formatting.marketCap(131_000_000_000), "$131B")
        XCTAssertEqual(Formatting.marketCap(626_000_000_000), "$626B")
    }

    func testMarketCap_billions_rounded() {
        XCTAssertEqual(Formatting.marketCap(12_300_000_000), "$12B")
        XCTAssertEqual(Formatting.marketCap(3_800_000_000), "$4B")
    }

    func testMarketCap_millions() {
        XCTAssertEqual(Formatting.marketCap(115_000_000), "$115M")
        XCTAssertEqual(Formatting.marketCap(17_400_000), "$17M")
        XCTAssertEqual(Formatting.marketCap(1_500_000), "$2M")
    }

    func testMarketCap_belowMillion() {
        XCTAssertEqual(Formatting.marketCap(500_000), "$500000")
    }
}

// MARK: - Yahoo Timeseries Response Tests

final class YahooTimeseriesResponseTests: XCTestCase {

    func testDecoding_validJSON_decodesResponse() throws {
        let json = """
        {
            "timeseries": {
                "result": [{
                    "meta": {
                        "symbol": ["AAPL"],
                        "type": ["quarterlyForwardPeRatio"]
                    },
                    "quarterlyForwardPeRatio": [
                        {"asOfDate": "2025-06-30", "reportedValue": {"raw": 28.5, "fmt": "28.50"}},
                        {"asOfDate": "2025-12-31", "reportedValue": {"raw": 27.8, "fmt": "27.80"}}
                    ]
                }]
            }
        }
        """
        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(YahooTimeseriesResponse.self, from: data)

        XCTAssertNotNil(decoded.timeseries.result)
        XCTAssertEqual(decoded.timeseries.result?.count, 1)

        let first = decoded.timeseries.result!.first!
        XCTAssertEqual(first.meta.symbol, ["AAPL"])
        XCTAssertEqual(first.meta.type, ["quarterlyForwardPeRatio"])
        XCTAssertEqual(first.quarterlyForwardPeRatio?.count, 2)
    }

    func testForwardPeEntry_decodesAsOfDateAndValue() throws {
        let json = """
        {"asOfDate": "2025-09-30", "reportedValue": {"raw": 30.2, "fmt": "30.20"}}
        """
        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(ForwardPeEntry.self, from: data)

        XCTAssertEqual(decoded.asOfDate, "2025-09-30")
        XCTAssertEqual(decoded.reportedValue.raw, 30.2)
        XCTAssertEqual(decoded.reportedValue.fmt, "30.20")
    }

    func testQuoteResult_decodesForwardPE() throws {
        let json = """
        {
            "quoteResponse": {
                "result": [
                    {"symbol": "AAPL", "marketCap": 3759435415552, "quoteType": "EQUITY", "forwardPE": 28.5},
                    {"symbol": "SPY", "marketCap": 625697882112, "quoteType": "ETF"}
                ]
            }
        }
        """
        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(YahooQuoteResponse.self, from: data)

        XCTAssertEqual(decoded.quoteResponse.result[0].forwardPE, 28.5)
        XCTAssertNil(decoded.quoteResponse.result[1].forwardPE)
    }
}
