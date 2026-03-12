import Foundation

// MARK: - Finnhub Quote API Response Model

struct FinnhubQuoteResponse: Codable {
    let c: Double   // current price
    let d: Double?  // change (null for unknown symbols)
    let dp: Double? // change percent
    let h: Double   // high
    let l: Double   // low
    let o: Double   // open
    let pc: Double  // previous close
    let t: Int      // timestamp

    var isValid: Bool { c > 0 && pc > 0 }
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

// MARK: - Yahoo Finance Quote API Response Models (v7)

struct YahooQuoteResponse: Codable {
    let quoteResponse: QuoteResponseData
}

struct QuoteResponseData: Codable {
    let result: [QuoteResult]
}

struct QuoteResult: Codable {
    let symbol: String
    let marketCap: Double?
    let quoteType: String?
    let forwardPE: Double?
}

// MARK: - Yahoo Finance Timeseries API Response Models

struct YahooTimeseriesResponse: Codable {
    let timeseries: TimeseriesResult
}

struct TimeseriesResult: Codable {
    let result: [TimeseriesData]?
}

struct TimeseriesData: Codable {
    let meta: TimeseriesMeta
    let quarterlyForwardPeRatio: [ForwardPeEntry]?
}

struct TimeseriesMeta: Codable {
    let symbol: [String]
    let type: [String]
}

struct ForwardPeEntry: Codable {
    let asOfDate: String
    let reportedValue: ReportedValue
}

struct ReportedValue: Codable {
    let raw: Double
    let fmt: String
}
