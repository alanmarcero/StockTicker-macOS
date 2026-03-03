import Foundation

struct TickerFilter: OptionSet, Codable, Equatable {
    let rawValue: Int

    static let greenYTD  = TickerFilter(rawValue: 1 << 0)
    static let greenHigh = TickerFilter(rawValue: 1 << 1)
    static let greenLow  = TickerFilter(rawValue: 1 << 2)
    static let etf       = TickerFilter(rawValue: 1 << 3)
    static let asset     = TickerFilter(rawValue: 1 << 4)

    static let greenOptions: [TickerFilter] = [.greenYTD, .greenHigh, .greenLow]
    static let typeOptions: [TickerFilter] = [.etf, .asset]
    static let allOptions: [TickerFilter] = greenOptions + typeOptions

    var displayName: String {
        switch rawValue {
        case TickerFilter.greenYTD.rawValue: return "Green YTD"
        case TickerFilter.greenHigh.rawValue: return "Green High"
        case TickerFilter.greenLow.rawValue: return "Green Low"
        case TickerFilter.etf.rawValue: return "ETFs"
        case TickerFilter.asset.rawValue: return "Assets"
        default: return "Filter"
        }
    }

    func matches(_ quote: StockQuote) -> Bool {
        if isEmpty { return true }
        if contains(.greenYTD) && !quote.isYTDGreen { return false }
        if contains(.greenHigh) && !quote.isHighGreen { return false }
        if contains(.greenLow) && !quote.isLowGreen { return false }
        if contains(.etf) && !quote.isETF { return false }
        if contains(.asset) && !quote.isAsset { return false }
        return true
    }

    func filter(_ symbols: [String], using quotes: [String: StockQuote]) -> [String] {
        if isEmpty { return symbols }
        return symbols.filter { symbol in
            guard let quote = quotes[symbol] else { return false }
            return matches(quote)
        }
    }
}
