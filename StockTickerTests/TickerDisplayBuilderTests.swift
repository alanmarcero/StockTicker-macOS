import XCTest
@testable import StockTicker

final class TickerDisplayBuilderTests: XCTestCase {

    // MARK: - Menu Bar Title

    func testMenuBarTitle_regularQuote() {
        let quote = StockQuote(symbol: "AAPL", price: 150.0, previousClose: 145.0)
        let result = TickerDisplayBuilder.menuBarTitle(for: quote)

        XCTAssertTrue(result.string.contains("AAPL"))
        XCTAssertTrue(result.string.contains(quote.formattedChangePercent))
    }

    func testMenuBarTitle_extendedHours() {
        let quote = StockQuote(
            symbol: "AAPL", price: 150.0, previousClose: 145.0, session: .afterHours,
            postMarketPrice: 152.0, postMarketChange: 2.0, postMarketChangePercent: 1.33
        )
        let result = TickerDisplayBuilder.menuBarTitle(for: quote, showExtendedHours: true)

        XCTAssertTrue(result.string.contains("AAPL"))
        XCTAssertTrue(result.string.contains(quote.formattedExtendedHoursChangePercent ?? ""))
    }

    func testMenuBarTitle_extendedHoursNoData_fallsBackToRegular() {
        let quote = StockQuote(symbol: "AAPL", price: 150.0, previousClose: 145.0)
        let result = TickerDisplayBuilder.menuBarTitle(for: quote, showExtendedHours: true)

        XCTAssertTrue(result.string.contains(quote.formattedChangePercent))
    }

    // MARK: - Ticker Title

    func testTickerTitle_basicQuote() {
        let quote = StockQuote(symbol: "AAPL", price: 150.0, previousClose: 145.0)
        let highlight = HighlightConfig(
            isPingHighlighted: false, pingBackgroundColor: nil,
            isPersistentHighlighted: false, persistentHighlightColor: .yellow, persistentHighlightOpacity: 0.25
        )

        let result = TickerDisplayBuilder.tickerTitle(quote: quote, highlight: highlight)
        XCTAssertTrue(result.string.contains("AAPL"))
        XCTAssertTrue(result.string.contains(quote.formattedPrice))
    }

    func testTickerTitle_persistentHighlight() {
        let quote = StockQuote(symbol: "SPY", price: 500.0, previousClose: 495.0)
        let highlight = HighlightConfig(
            isPingHighlighted: false, pingBackgroundColor: nil,
            isPersistentHighlighted: true, persistentHighlightColor: .systemYellow, persistentHighlightOpacity: 0.25
        )

        let result = TickerDisplayBuilder.tickerTitle(quote: quote, highlight: highlight)

        // Verify background color is applied
        var range = NSRange()
        let attrs = result.attributes(at: 0, effectiveRange: &range)
        XCTAssertNotNil(attrs[.backgroundColor])
    }

    func testTickerTitle_pingHighlight() {
        let quote = StockQuote(symbol: "MSFT", price: 400.0, previousClose: 395.0)
        let highlight = HighlightConfig(
            isPingHighlighted: true, pingBackgroundColor: .systemGreen.withAlphaComponent(0.6),
            isPersistentHighlighted: false, persistentHighlightColor: .yellow, persistentHighlightOpacity: 0.25
        )

        let result = TickerDisplayBuilder.tickerTitle(quote: quote, highlight: highlight)

        var range = NSRange()
        let attrs = result.attributes(at: 0, effectiveRange: &range)
        let fgColor = attrs[.foregroundColor] as? NSColor
        XCTAssertEqual(fgColor, .white)
    }

    // MARK: - YTD Section

    func testAppendYTDSection_withYTDData() {
        let quote = StockQuote(symbol: "AAPL", price: 150.0, previousClose: 145.0, ytdStartPrice: 130.0)
        let highlight = HighlightConfig(
            isPingHighlighted: false, pingBackgroundColor: nil,
            isPersistentHighlighted: false, persistentHighlightColor: .yellow, persistentHighlightOpacity: 0.25
        )

        let result = NSMutableAttributedString()
        TickerDisplayBuilder.appendYTDSection(to: result, quote: quote, highlight: highlight)

        XCTAssertTrue(result.string.contains("YTD:"))
    }

    func testAppendYTDSection_noYTDData_appendsNothing() {
        let quote = StockQuote(symbol: "AAPL", price: 150.0, previousClose: 145.0)
        let highlight = HighlightConfig(
            isPingHighlighted: false, pingBackgroundColor: nil,
            isPersistentHighlighted: false, persistentHighlightColor: .yellow, persistentHighlightOpacity: 0.25
        )

        let result = NSMutableAttributedString()
        TickerDisplayBuilder.appendYTDSection(to: result, quote: quote, highlight: highlight)

        XCTAssertEqual(result.string, "")
    }

    // MARK: - Highest Close Section

    func testAppendHighestCloseSection_withData() {
        let quote = StockQuote(symbol: "AAPL", price: 150.0, previousClose: 145.0, highestClose: 200.0)
        let highlight = HighlightConfig(
            isPingHighlighted: false, pingBackgroundColor: nil,
            isPersistentHighlighted: false, persistentHighlightColor: .yellow, persistentHighlightOpacity: 0.25
        )

        let result = NSMutableAttributedString()
        TickerDisplayBuilder.appendHighestCloseSection(to: result, quote: quote, highlight: highlight)

        XCTAssertTrue(result.string.contains("High:"))
    }

    func testAppendHighestCloseSection_noData_appendsNothing() {
        let quote = StockQuote(symbol: "AAPL", price: 150.0, previousClose: 145.0)
        let highlight = HighlightConfig(
            isPingHighlighted: false, pingBackgroundColor: nil,
            isPersistentHighlighted: false, persistentHighlightColor: .yellow, persistentHighlightOpacity: 0.25
        )

        let result = NSMutableAttributedString()
        TickerDisplayBuilder.appendHighestCloseSection(to: result, quote: quote, highlight: highlight)

        XCTAssertEqual(result.string, "")
    }

    func testTickerTitle_includesHighestCloseSection() {
        let quote = StockQuote(symbol: "AAPL", price: 150.0, previousClose: 145.0, ytdStartPrice: 130.0, highestClose: 200.0)
        let highlight = HighlightConfig(
            isPingHighlighted: false, pingBackgroundColor: nil,
            isPersistentHighlighted: false, persistentHighlightColor: .yellow, persistentHighlightOpacity: 0.25
        )

        let result = TickerDisplayBuilder.tickerTitle(quote: quote, highlight: highlight)
        XCTAssertTrue(result.string.contains("High:"))
        XCTAssertTrue(result.string.contains("YTD:"))
    }

    // MARK: - Extended Hours Section

    func testAppendExtendedHoursSection_noExtendedHours_appendsNothing() {
        let quote = StockQuote(symbol: "AAPL", price: 150.0, previousClose: 145.0, session: .closed)
        let highlight = HighlightConfig(
            isPingHighlighted: false, pingBackgroundColor: nil,
            isPersistentHighlighted: false, persistentHighlightColor: .yellow, persistentHighlightOpacity: 0.25
        )

        let result = NSMutableAttributedString()
        TickerDisplayBuilder.appendExtendedHoursSection(to: result, quote: quote, highlight: highlight)

        XCTAssertEqual(result.string, "")
    }

    // MARK: - Color Helpers

    func testPriceChangeColor_positive() {
        let color = priceChangeColor(5.0, neutral: .gray)
        XCTAssertEqual(color, .systemGreen)
    }

    func testPriceChangeColor_negative() {
        let color = priceChangeColor(-3.0, neutral: .gray)
        XCTAssertEqual(color, .systemRed)
    }

    func testPriceChangeColor_nearZero() {
        let color = priceChangeColor(0.001, neutral: .gray)
        XCTAssertEqual(color, .gray)
    }

    // MARK: - HighlightConfig

    func testHighlightConfig_resolve_defaultColor() {
        let config = HighlightConfig(
            isPingHighlighted: false, pingBackgroundColor: nil,
            isPersistentHighlighted: false, persistentHighlightColor: .yellow, persistentHighlightOpacity: 0.25
        )
        let (fg, bg) = config.resolve(defaultColor: .systemGreen)
        XCTAssertEqual(fg, .systemGreen)
        XCTAssertNil(bg)
    }

    func testHighlightConfig_resolve_pingHighlighted() {
        let config = HighlightConfig(
            isPingHighlighted: true, pingBackgroundColor: .systemGreen,
            isPersistentHighlighted: false, persistentHighlightColor: .yellow, persistentHighlightOpacity: 0.25
        )
        let (fg, bg) = config.resolve(defaultColor: .systemRed)
        XCTAssertEqual(fg, .white)
        XCTAssertEqual(bg, .systemGreen)
    }

    func testHighestCloseColor_negative() {
        let quote = StockQuote(symbol: "AAPL", price: 150.0, previousClose: 145.0, highestClose: 200.0)
        XCTAssertEqual(quote.highestCloseColor, .systemRed)
    }

    func testHighestCloseColor_positive() {
        let quote = StockQuote(symbol: "AAPL", price: 220.0, previousClose: 210.0, highestClose: 200.0)
        XCTAssertEqual(quote.highestCloseColor, .systemGreen)
    }

    func testHighestCloseColor_nil() {
        let quote = StockQuote(symbol: "AAPL", price: 150.0, previousClose: 145.0)
        XCTAssertEqual(quote.highestCloseColor, .secondaryLabelColor)
    }

    func testHighestCloseColor_nearZero() {
        let quote = StockQuote(symbol: "AAPL", price: 200.0, previousClose: 195.0, highestClose: 200.0)
        XCTAssertEqual(quote.highestCloseColor, .labelColor)
    }

    func testHighlightConfig_withPingDisabled() {
        let config = HighlightConfig(
            isPingHighlighted: true, pingBackgroundColor: .systemGreen,
            isPersistentHighlighted: true, persistentHighlightColor: .yellow, persistentHighlightOpacity: 0.25
        )
        let disabled = config.withPingDisabled()
        XCTAssertFalse(disabled.isPingHighlighted)
        XCTAssertNil(disabled.pingBackgroundColor)
        XCTAssertTrue(disabled.isPersistentHighlighted)
    }
}
