import AppKit

// MARK: - Color Helpers

func priceChangeColor(_ change: Double, neutral: NSColor) -> NSColor {
    if abs(change) < TradingHours.nearZeroThreshold { return neutral }
    return change > 0 ? .systemGreen : .systemRed
}

extension StockQuote {
    var displayColor: NSColor { priceChangeColor(change, neutral: .secondaryLabelColor) }
    var highlightColor: NSColor { priceChangeColor(change, neutral: .systemGray) }
    var extendedHoursColor: NSColor { priceChangeColor(extendedHoursChangePercent ?? 0, neutral: .secondaryLabelColor) }
    var extendedHoursHighlightColor: NSColor { priceChangeColor(extendedHoursChangePercent ?? 0, neutral: .systemGray) }
    var ytdColor: NSColor {
        guard let pct = ytdChangePercent else { return .secondaryLabelColor }
        if abs(pct) < TradingHours.nearZeroThreshold { return .labelColor }
        return pct >= 0 ? .systemGreen : .systemRed
    }
    var highestCloseColor: NSColor {
        guard let pct = highestCloseChangePercent else { return .secondaryLabelColor }
        if abs(pct) < TradingHours.nearZeroThreshold { return .labelColor }
        return pct >= -5.0 ? .systemGreen : .systemRed
    }
}

// MARK: - Attributed String Helpers

extension NSAttributedString {
    static func styled(
        _ string: String, font: NSFont, color: NSColor? = nil, backgroundColor: NSColor? = nil
    ) -> NSAttributedString {
        var attributes: [Key: Any] = [.font: font]
        if let color = color { attributes[.foregroundColor] = color }
        if let backgroundColor = backgroundColor { attributes[.backgroundColor] = backgroundColor }
        return NSAttributedString(string: string, attributes: attributes)
    }
}

extension NSMutableAttributedString {
    func append(_ string: String, font: NSFont, color: NSColor? = nil) {
        append(.styled(string, font: font, color: color))
    }
}

// MARK: - Highlight Configuration

struct HighlightConfig {
    let isPingHighlighted: Bool
    let pingBackgroundColor: NSColor?
    let isPersistentHighlighted: Bool
    let persistentHighlightColor: NSColor
    let persistentHighlightOpacity: Double

    func resolve(defaultColor: NSColor) -> (foreground: NSColor, background: NSColor?) {
        if isPingHighlighted {
            return (.white, pingBackgroundColor)
        }
        if isPersistentHighlighted {
            return (defaultColor, persistentHighlightColor.withAlphaComponent(persistentHighlightOpacity))
        }
        return (defaultColor, nil)
    }

    func withPingBackground(_ color: NSColor?) -> HighlightConfig {
        HighlightConfig(
            isPingHighlighted: isPingHighlighted,
            pingBackgroundColor: color,
            isPersistentHighlighted: isPersistentHighlighted,
            persistentHighlightColor: persistentHighlightColor,
            persistentHighlightOpacity: persistentHighlightOpacity
        )
    }

    func withPingDisabled() -> HighlightConfig {
        HighlightConfig(
            isPingHighlighted: false,
            pingBackgroundColor: nil,
            isPersistentHighlighted: isPersistentHighlighted,
            persistentHighlightColor: persistentHighlightColor,
            persistentHighlightOpacity: persistentHighlightOpacity
        )
    }
}

// MARK: - Ticker Display Builder

enum TickerDisplayBuilder {

    static func menuBarTitle(
        for quote: StockQuote, showExtendedHours: Bool = false
    ) -> NSAttributedString {
        let result = NSMutableAttributedString()
        result.append("\(quote.symbol) ", font: MenuItemFactory.monoFontMedium)

        if showExtendedHours, let extPercent = quote.formattedExtendedHoursChangePercent {
            let color = quote.extendedHoursIsPositive ? NSColor.systemGreen : NSColor.systemRed
            result.append(extPercent, font: MenuItemFactory.monoFontMedium, color: color)
            result.append(" (\(quote.extendedHoursLabel))", font: MenuItemFactory.monoFontMedium, color: .white)
        } else {
            result.append(quote.formattedChangePercent, font: MenuItemFactory.monoFontMedium, color: quote.displayColor)
        }

        return result
    }

    static func tickerTitle(quote: StockQuote, highlight: HighlightConfig, date: Date = Date()) -> NSAttributedString {
        let result = NSMutableAttributedString()

        let symbolStr = quote.symbol.padding(toLength: LayoutConfig.Ticker.symbolWidth, withPad: " ", startingAt: 0)
        let marketCapStr = quote.formattedMarketCap.padding(toLength: LayoutConfig.Ticker.marketCapWidth, withPad: " ", startingAt: 0)
        let percentStr = quote.formattedChangePercent.padding(
            toLength: LayoutConfig.Ticker.percentWidth, withPad: " ", startingAt: 0
        )

        let mainHighlight = quote.isInExtendedHoursPeriod(at: date)
            ? highlight.withPingDisabled()
            : highlight
        let (mainColor, mainBgColor) = mainHighlight.resolve(defaultColor: quote.displayColor)

        result.append(.styled("\(symbolStr) \(marketCapStr) \(percentStr)",
                              font: MenuItemFactory.monoFont, color: mainColor, backgroundColor: mainBgColor))

        appendYTDSection(to: result, quote: quote, highlight: highlight)
        appendHighestCloseSection(to: result, quote: quote, highlight: highlight)
        appendExtendedHoursSection(to: result, quote: quote, highlight: highlight, date: date)

        return result
    }

    static func appendYTDSection(to result: NSMutableAttributedString, quote: StockQuote, highlight: HighlightConfig) {
        guard let ytdPercent = quote.formattedYTDChangePercent else { return }
        let ytdContent = "YTD: \(ytdPercent)"
        let paddedContent = ytdContent.count >= LayoutConfig.Ticker.ytdWidth
            ? ytdContent
            : ytdContent.padding(toLength: LayoutConfig.Ticker.ytdWidth, withPad: " ", startingAt: 0)
        let (ytdColor, ytdBgColor) = highlight.resolve(defaultColor: quote.ytdColor)
        result.append(.styled("  \(paddedContent)",
                              font: MenuItemFactory.monoFont, color: ytdColor, backgroundColor: ytdBgColor))
    }

    static func appendHighestCloseSection(to result: NSMutableAttributedString, quote: StockQuote, highlight: HighlightConfig) {
        guard let highPercent = quote.formattedHighestCloseChangePercent else { return }
        let highContent = "High: \(highPercent)"
        let paddedContent = highContent.count >= LayoutConfig.Ticker.highWidth
            ? highContent
            : highContent.padding(toLength: LayoutConfig.Ticker.highWidth, withPad: " ", startingAt: 0)
        let (highColor, highBgColor) = highlight.resolve(defaultColor: quote.highestCloseColor)
        result.append(.styled("  \(paddedContent)",
                              font: MenuItemFactory.monoFont, color: highColor, backgroundColor: highBgColor))
    }

    static func appendExtendedHoursSection(
        to result: NSMutableAttributedString, quote: StockQuote, highlight: HighlightConfig, date: Date = Date()
    ) {
        guard quote.isInExtendedHoursPeriod(at: date), let periodLabel = quote.extendedHoursPeriodLabel(at: date) else { return }

        if quote.formattedYTDChangePercent == nil {
            let emptyPadding = String(repeating: " ", count: LayoutConfig.Ticker.ytdWidth + 2)
            result.append(.styled(emptyPadding, font: MenuItemFactory.monoFont))
        }
        if quote.formattedHighestCloseChangePercent == nil {
            let emptyPadding = String(repeating: " ", count: LayoutConfig.Ticker.highWidth + 2)
            result.append(.styled(emptyPadding, font: MenuItemFactory.monoFont))
        }

        if quote.shouldShowExtendedHours(at: date), let extPercent = quote.formattedExtendedHoursChangePercent {
            let extPingBgColor = quote.extendedHoursHighlightColor.withAlphaComponent(
                highlight.pingBackgroundColor?.alphaComponent ?? 0
            )
            let extHighlight = highlight.withPingBackground(extPingBgColor)
            let (extColor, extBgColor) = extHighlight.resolve(defaultColor: quote.extendedHoursColor)
            result.append(.styled("  \(periodLabel): \(extPercent)",
                                  font: MenuItemFactory.monoFont, color: extColor, backgroundColor: extBgColor))
        } else {
            let (extColor, extBgColor) = highlight.withPingDisabled().resolve(defaultColor: .secondaryLabelColor)
            result.append(.styled("  \(periodLabel): --",
                                  font: MenuItemFactory.monoFont, color: extColor, backgroundColor: extBgColor))
        }
    }
}
