import Foundation

// MARK: - Sort Option

enum SortOption: String, CaseIterable {
    case tickerAsc = "Ticker ↑"
    case tickerDesc = "Ticker ↓"
    case changeAsc = "Price Change ↑"
    case changeDesc = "Price Change ↓"
    case percentAsc = "% Change ↑"
    case percentDesc = "% Change ↓"
    case ytdAsc = "YTD % ↑"
    case ytdDesc = "YTD % ↓"

    static func from(configString: String) -> SortOption {
        switch configString {
        case "tickerAsc": return .tickerAsc
        case "tickerDesc": return .tickerDesc
        case "changeAsc": return .changeAsc
        case "changeDesc": return .changeDesc
        case "percentAsc": return .percentAsc
        case "percentDesc": return .percentDesc
        case "ytdAsc": return .ytdAsc
        case "ytdDesc": return .ytdDesc
        default: return .percentDesc
        }
    }

    var configString: String {
        switch self {
        case .tickerAsc: return "tickerAsc"
        case .tickerDesc: return "tickerDesc"
        case .changeAsc: return "changeAsc"
        case .changeDesc: return "changeDesc"
        case .percentAsc: return "percentAsc"
        case .percentDesc: return "percentDesc"
        case .ytdAsc: return "ytdAsc"
        case .ytdDesc: return "ytdDesc"
        }
    }

    func sort(_ symbols: [String], using quotes: [String: StockQuote]) -> [String] {
        switch self {
        case .tickerAsc: return symbols.sorted { $0 < $1 }
        case .tickerDesc: return symbols.sorted { $0 > $1 }
        case .changeAsc: return symbols.sorted { (quotes[$0]?.change ?? 0) < (quotes[$1]?.change ?? 0) }
        case .changeDesc: return symbols.sorted { (quotes[$0]?.change ?? 0) > (quotes[$1]?.change ?? 0) }
        case .percentAsc: return symbols.sorted { (quotes[$0]?.changePercent ?? 0) < (quotes[$1]?.changePercent ?? 0) }
        case .percentDesc: return symbols.sorted { (quotes[$0]?.changePercent ?? 0) > (quotes[$1]?.changePercent ?? 0) }
        case .ytdAsc: return symbols.sorted {
            (quotes[$0]?.ytdChangePercent ?? 0) < (quotes[$1]?.ytdChangePercent ?? 0)
        }
        case .ytdDesc: return symbols.sorted {
            (quotes[$0]?.ytdChangePercent ?? 0) > (quotes[$1]?.ytdChangePercent ?? 0)
        }
        }
    }
}
