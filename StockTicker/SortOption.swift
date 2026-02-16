import Foundation

// MARK: - Sort Option

enum SortOption: String, CaseIterable {
    case tickerAsc = "Ticker ↑"
    case tickerDesc = "Ticker ↓"
    case marketCapAsc = "Market Cap ↑"
    case marketCapDesc = "Market Cap ↓"
    case percentAsc = "% Change ↑"
    case percentDesc = "% Change ↓"
    case ytdAsc = "YTD % ↑"
    case ytdDesc = "YTD % ↓"
    case highAsc = "High % ↑"
    case highDesc = "High % ↓"

    static func from(configString: String) -> SortOption {
        switch configString {
        case "tickerAsc": return .tickerAsc
        case "tickerDesc": return .tickerDesc
        case "marketCapAsc": return .marketCapAsc
        case "marketCapDesc": return .marketCapDesc
        case "percentAsc": return .percentAsc
        case "percentDesc": return .percentDesc
        case "ytdAsc": return .ytdAsc
        case "ytdDesc": return .ytdDesc
        case "highAsc": return .highAsc
        case "highDesc": return .highDesc
        default: return .percentDesc
        }
    }

    var configString: String {
        switch self {
        case .tickerAsc: return "tickerAsc"
        case .tickerDesc: return "tickerDesc"
        case .marketCapAsc: return "marketCapAsc"
        case .marketCapDesc: return "marketCapDesc"
        case .percentAsc: return "percentAsc"
        case .percentDesc: return "percentDesc"
        case .ytdAsc: return "ytdAsc"
        case .ytdDesc: return "ytdDesc"
        case .highAsc: return "highAsc"
        case .highDesc: return "highDesc"
        }
    }

    func sort(_ symbols: [String], using quotes: [String: StockQuote]) -> [String] {
        switch self {
        case .tickerAsc: return symbols.sorted { $0 < $1 }
        case .tickerDesc: return symbols.sorted { $0 > $1 }
        case .marketCapAsc: return symbols.sorted { (quotes[$0]?.marketCap ?? 0) < (quotes[$1]?.marketCap ?? 0) }
        case .marketCapDesc: return symbols.sorted { (quotes[$0]?.marketCap ?? 0) > (quotes[$1]?.marketCap ?? 0) }
        case .percentAsc: return symbols.sorted { (quotes[$0]?.changePercent ?? 0) < (quotes[$1]?.changePercent ?? 0) }
        case .percentDesc: return symbols.sorted { (quotes[$0]?.changePercent ?? 0) > (quotes[$1]?.changePercent ?? 0) }
        case .ytdAsc: return symbols.sorted {
            (quotes[$0]?.ytdChangePercent ?? 0) < (quotes[$1]?.ytdChangePercent ?? 0)
        }
        case .ytdDesc: return symbols.sorted {
            (quotes[$0]?.ytdChangePercent ?? 0) > (quotes[$1]?.ytdChangePercent ?? 0)
        }
        case .highAsc: return symbols.sorted {
            (quotes[$0]?.highestCloseChangePercent ?? 0) < (quotes[$1]?.highestCloseChangePercent ?? 0)
        }
        case .highDesc: return symbols.sorted {
            (quotes[$0]?.highestCloseChangePercent ?? 0) > (quotes[$1]?.highestCloseChangePercent ?? 0)
        }
        }
    }
}
