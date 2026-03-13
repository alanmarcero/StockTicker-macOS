import Foundation

struct TickerFilter: OptionSet, Codable, Equatable {
    let rawValue: Int

    static let greenYTD  = TickerFilter(rawValue: 1 << 0)
    static let greenHigh = TickerFilter(rawValue: 1 << 1)
    static let greenLow  = TickerFilter(rawValue: 1 << 2)
    static let etf       = TickerFilter(rawValue: 1 << 3)
    static let asset     = TickerFilter(rawValue: 1 << 4)
    static let redYTD    = TickerFilter(rawValue: 1 << 5)
    static let redHigh   = TickerFilter(rawValue: 1 << 6)
    static let redLow    = TickerFilter(rawValue: 1 << 7)

    static let greenOptions: [TickerFilter] = [.greenYTD, .greenHigh, .greenLow]
    static let redOptions: [TickerFilter] = [.redYTD, .redHigh, .redLow]
    static let typeOptions: [TickerFilter] = [.etf, .asset]
    static let allOptions: [TickerFilter] = greenOptions + redOptions + typeOptions

    var displayName: String {
        switch rawValue {
        case TickerFilter.greenYTD.rawValue: return "Green YTD"
        case TickerFilter.greenHigh.rawValue: return "Green High"
        case TickerFilter.greenLow.rawValue: return "Green Low"
        case TickerFilter.redYTD.rawValue: return "Red YTD"
        case TickerFilter.redHigh.rawValue: return "Red High"
        case TickerFilter.redLow.rawValue: return "Red Low"
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
        if contains(.redYTD) && !quote.isYTDRed { return false }
        if contains(.redHigh) && !quote.isHighRed { return false }
        if contains(.redLow) && !quote.isLowRed { return false }

        let typeFilters = self.intersection([.etf, .asset])
        if !typeFilters.isEmpty {
            let matchesType = (typeFilters.contains(.etf) && quote.isETF)
                || (typeFilters.contains(.asset) && quote.isAsset)
            if !matchesType { return false }
        }
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
