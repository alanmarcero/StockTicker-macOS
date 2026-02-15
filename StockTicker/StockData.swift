import Foundation

// MARK: - Trading Hours Constants

/// NYSE trading hours in minutes from midnight ET (shared across codebase)
enum TradingHours {
    static let preMarketOpen = 4 * 60       // 4:00 AM
    static let marketOpen = 9 * 60 + 30     // 9:30 AM
    static let marketClose = 16 * 60        // 4:00 PM
    static let earlyClose = 13 * 60         // 1:00 PM
    static let afterHoursClose = 20 * 60    // 8:00 PM

    /// Threshold for treating floating point price changes as zero
    static let nearZeroThreshold = 0.005
    /// Threshold for detecting meaningful extended hours price differences
    static let extendedHoursPriceThreshold = 0.001
}

// MARK: - Yahoo Finance Chart API Response Models (v8)

struct YahooChartResponse: Codable {
    let chart: ChartResult
}

struct ChartResult: Codable {
    let result: [ChartData]?
    let error: ChartError?
}

struct ChartError: Codable {
    let code: String
    let description: String
}

struct ChartData: Codable {
    let meta: ChartMeta
    let timestamp: [Int]?
    let indicators: ChartIndicators?
}

struct ChartIndicators: Codable {
    let quote: [ChartQuote]?
}

struct ChartQuote: Codable {
    let close: [Double?]?
}

struct ChartMeta: Codable {
    let regularMarketPrice: Double?
    let chartPreviousClose: Double?
    let symbol: String
    let marketState: String?

    // Pre-market data
    let preMarketPrice: Double?
    let preMarketChange: Double?
    let preMarketChangePercent: Double?

    // After-hours (post-market) data
    let postMarketPrice: Double?
    let postMarketChange: Double?
    let postMarketChangePercent: Double?
}

// MARK: - Trading Session

enum TradingSession: Sendable {
    case preMarket
    case regular
    case afterHours
    case closed

    init(fromYahooState state: String?) {
        switch state?.uppercased() {
        case "PRE", "PREPRE":
            self = .preMarket
        case "REGULAR":
            self = .regular
        case "POST", "POSTPOST":
            self = .afterHours
        default:
            self = .closed
        }
    }

    var suffix: String {
        switch self {
        case .preMarket: return " (Pre)"
        case .afterHours: return " (After)"
        case .regular, .closed: return ""
        }
    }
}

// MARK: - App Display Models

struct StockQuote: Identifiable, Sendable {
    let id: UUID
    let symbol: String
    let price: Double
    let previousClose: Double
    let session: TradingSession

    // Pre-market data
    let preMarketPrice: Double?
    let preMarketChange: Double?
    let preMarketChangePercent: Double?

    // After-hours data
    let postMarketPrice: Double?
    let postMarketChange: Double?
    let postMarketChangePercent: Double?

    // YTD data (Dec 31 close price of previous year)
    let ytdStartPrice: Double?

    init(symbol: String, price: Double, previousClose: Double, session: TradingSession = .closed,
         preMarketPrice: Double? = nil, preMarketChange: Double? = nil, preMarketChangePercent: Double? = nil,
         postMarketPrice: Double? = nil, postMarketChange: Double? = nil, postMarketChangePercent: Double? = nil,
         ytdStartPrice: Double? = nil) {
        self.id = UUID()
        self.symbol = symbol
        self.price = price
        self.previousClose = previousClose
        self.session = session
        self.preMarketPrice = preMarketPrice
        self.preMarketChange = preMarketChange
        self.preMarketChangePercent = preMarketChangePercent
        self.postMarketPrice = postMarketPrice
        self.postMarketChange = postMarketChange
        self.postMarketChangePercent = postMarketChangePercent
        self.ytdStartPrice = ytdStartPrice
    }

    // Regular market change (always based on regular price)
    var change: Double {
        price - previousClose
    }

    var changePercent: Double {
        guard previousClose != 0 else { return 0 }
        return (change / previousClose) * 100
    }

    var isPositive: Bool {
        change >= 0
    }

    // MARK: - Display Properties (context-aware based on session)

    var isExtendedHours: Bool {
        switch session {
        case .preMarket: return preMarketPrice != nil
        case .afterHours: return postMarketPrice != nil
        case .regular, .closed: return false
        }
    }

    var displayPrice: Double {
        switch session {
        case .preMarket: return preMarketPrice ?? price
        case .afterHours: return postMarketPrice ?? price
        case .regular, .closed: return price
        }
    }

    var displayChange: Double {
        switch session {
        case .preMarket: return preMarketChange ?? change
        case .afterHours: return postMarketChange ?? change
        case .regular, .closed: return change
        }
    }

    var displayChangePercent: Double {
        switch session {
        case .preMarket: return preMarketChangePercent ?? changePercent
        case .afterHours: return postMarketChangePercent ?? changePercent
        case .regular, .closed: return changePercent
        }
    }

    var displayIsPositive: Bool {
        displayChange >= 0
    }

    var extendedHoursSuffix: String {
        isExtendedHours ? session.suffix : ""
    }

    var formattedPrice: String {
        Formatting.currency(price)
    }

    var formattedChange: String {
        Formatting.signedCurrency(change, isPositive: isPositive)
    }

    var formattedChangePercent: String {
        Formatting.signedPercent(changePercent, isPositive: isPositive)
    }

    // MARK: - Extended Hours Display

    /// Resolves the effective trading session, using time-based detection as fallback
    /// when Yahoo returns "CLOSED" during actual extended hours
    private var effectiveSession: TradingSession {
        if session != .closed { return session }
        return StockQuote.currentTimeBasedSession()
    }

    var hasExtendedHoursData: Bool {
        switch effectiveSession {
        case .preMarket: return preMarketChangePercent != nil
        case .afterHours: return postMarketChangePercent != nil
        case .regular, .closed: return false
        }
    }

    /// Returns true when we have extended hours data to display
    var shouldShowExtendedHours: Bool {
        let timeSession = StockQuote.currentTimeBasedSession()
        switch timeSession {
        case .preMarket: return preMarketChangePercent != nil
        case .afterHours: return postMarketChangePercent != nil
        case .regular, .closed: return false
        }
    }

    /// Returns true when current time is in pre-market or after-hours period
    /// (regardless of whether we have data for that period)
    var isInExtendedHoursPeriod: Bool {
        let timeSession = StockQuote.currentTimeBasedSession()
        switch timeSession {
        case .preMarket, .afterHours: return true
        case .regular, .closed: return false
        }
    }

    /// Returns the label for current extended hours period, or nil if not in extended hours
    var extendedHoursPeriodLabel: String? {
        let timeSession = StockQuote.currentTimeBasedSession()
        switch timeSession {
        case .preMarket: return "Pre"
        case .afterHours: return "AH"
        case .regular, .closed: return nil
        }
    }

    var extendedHoursChangePercent: Double? {
        switch effectiveSession {
        case .preMarket: return preMarketChangePercent
        case .afterHours: return postMarketChangePercent
        case .regular, .closed: return nil
        }
    }

    var formattedExtendedHoursChangePercent: String? {
        guard let percent = extendedHoursChangePercent else { return nil }
        return Formatting.signedPercent(percent, isPositive: percent >= 0)
    }

    var extendedHoursIsPositive: Bool {
        (extendedHoursChangePercent ?? 0) >= 0
    }

    var extendedHoursLabel: String {
        switch effectiveSession {
        case .preMarket where preMarketChangePercent != nil: return "Pre"
        case .afterHours where postMarketChangePercent != nil: return "AH"
        default: return ""
        }
    }

    // MARK: - Time-based Session Detection

    /// Determines the current trading session based on time (Eastern Time)
    /// Used as fallback when Yahoo API returns "CLOSED" but we're in extended hours
    static func currentTimeBasedSession(date: Date = Date()) -> TradingSession {
        var calendar = Calendar.current
        guard let eastern = TimeZone(identifier: "America/New_York") else { return .closed }
        calendar.timeZone = eastern

        let weekday = calendar.component(.weekday, from: date)
        guard weekday != 1, weekday != 7 else { return .closed } // Weekend

        let minutes = calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)

        switch minutes {
        case TradingHours.preMarketOpen..<TradingHours.marketOpen: return .preMarket
        case TradingHours.marketOpen..<TradingHours.marketClose: return .regular
        case TradingHours.marketClose..<TradingHours.afterHoursClose: return .afterHours
        default: return .closed
        }
    }

    var displayString: String {
        "\(symbol) \(formattedPrice) \(formattedChange) \(formattedChangePercent)\(extendedHoursSuffix)"
    }

    // MARK: - YTD (Year-to-Date) Properties

    /// YTD change in dollars (current regular market price - Dec 31 close)
    var ytdChange: Double? {
        guard let start = ytdStartPrice, start > 0 else { return nil }
        return price - start
    }

    /// YTD change as percentage
    var ytdChangePercent: Double? {
        guard let start = ytdStartPrice, start > 0 else { return nil }
        return ((price - start) / start) * 100
    }

    /// Formatted YTD percentage string (e.g., "+4.35%")
    var formattedYTDChangePercent: String? {
        guard let percent = ytdChangePercent else { return nil }
        return Formatting.signedPercent(percent, isPositive: percent >= 0)
    }

    /// YTD is positive or unchanged
    var ytdIsPositive: Bool {
        (ytdChangePercent ?? 0) >= 0
    }
}

// MARK: - Formatting Helpers

enum Formatting {
    private static let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "$"
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    static func currency(_ value: Double) -> String {
        currencyFormatter.string(from: NSNumber(value: value)) ?? String(format: "$%.2f", value)
    }

    static func signedCurrency(_ value: Double, isPositive: Bool) -> String {
        let sign = isPositive ? "+" : "-"
        let formatted = currencyFormatter.string(from: NSNumber(value: abs(value))) ?? String(format: "$%.2f", abs(value))
        return "\(sign)\(formatted)"
    }

    static func signedPercent(_ value: Double, isPositive: Bool) -> String {
        let sign = isPositive ? "+" : ""
        return String(format: "%@%.2f%%", sign, value)
    }
}

// MARK: - Placeholder

extension StockQuote {
    static func placeholder(symbol: String) -> StockQuote {
        StockQuote(symbol: symbol, price: 0, previousClose: 0, session: .closed, ytdStartPrice: nil)
    }

    var isPlaceholder: Bool {
        price == 0 && previousClose == 0
    }

    /// Returns a new StockQuote with the YTD start price set
    func withYTDStartPrice(_ ytdPrice: Double?) -> StockQuote {
        StockQuote(
            symbol: symbol,
            price: price,
            previousClose: previousClose,
            session: session,
            preMarketPrice: preMarketPrice,
            preMarketChange: preMarketChange,
            preMarketChangePercent: preMarketChangePercent,
            postMarketPrice: postMarketPrice,
            postMarketChange: postMarketChange,
            postMarketChangePercent: postMarketChangePercent,
            ytdStartPrice: ytdPrice
        )
    }
}
