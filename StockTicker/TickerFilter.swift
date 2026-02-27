import Foundation

struct TickerFilter: OptionSet, Codable, Equatable {
    let rawValue: Int

    static let greenYTD  = TickerFilter(rawValue: 1 << 0)
    static let greenHigh = TickerFilter(rawValue: 1 << 1)
    static let greenLow  = TickerFilter(rawValue: 1 << 2)

    static let allOptions: [TickerFilter] = [.greenYTD, .greenHigh, .greenLow]

    var displayName: String {
        switch rawValue {
        case TickerFilter.greenYTD.rawValue: return "Green YTD"
        case TickerFilter.greenHigh.rawValue: return "Green High"
        case TickerFilter.greenLow.rawValue: return "Green Low"
        default: return "Filter"
        }
    }

    func matches(_ quote: StockQuote) -> Bool {
        if isEmpty { return true }
        if contains(.greenYTD) && !quote.isYTDGreen { return false }
        if contains(.greenHigh) && !quote.isHighGreen { return false }
        if contains(.greenLow) && !quote.isLowGreen { return false }
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
