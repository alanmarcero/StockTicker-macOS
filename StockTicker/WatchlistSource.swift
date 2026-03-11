import Foundation

struct WatchlistSource: OptionSet, Codable, Equatable {
    let rawValue: Int

    static let megaCap          = WatchlistSource(rawValue: 1 << 0)
    static let topAUMETFs       = WatchlistSource(rawValue: 1 << 1)
    static let topVolETFs       = WatchlistSource(rawValue: 1 << 2)
    static let personal         = WatchlistSource(rawValue: 1 << 3)
    static let stateStreetETFs  = WatchlistSource(rawValue: 1 << 4)
    static let vanguardETFs     = WatchlistSource(rawValue: 1 << 5)

    static let allSources: WatchlistSource = [.megaCap, .topAUMETFs, .topVolETFs, .personal, .stateStreetETFs, .vanguardETFs]

    static let allCases: [WatchlistSource] = [.megaCap, .topAUMETFs, .topVolETFs, .stateStreetETFs, .vanguardETFs, .personal]

    var displayName: String {
        switch rawValue {
        case WatchlistSource.megaCap.rawValue: return "$100B+"
        case WatchlistSource.topAUMETFs.rawValue: return "Top AUM ETFs"
        case WatchlistSource.topVolETFs.rawValue: return "Top Vol ETFs"
        case WatchlistSource.personal.rawValue: return "My Watchlist"
        case WatchlistSource.stateStreetETFs.rawValue: return "SPDR"
        case WatchlistSource.vanguardETFs.rawValue: return "Vanguard"
        default: return "Sources"
        }
    }

    /// Returns the union of symbols from all enabled sources, deduplicated and ordered.
    func symbols(personalWatchlist: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []

        func add(_ symbols: [String]) {
            for symbol in symbols where seen.insert(symbol).inserted {
                result.append(symbol)
            }
        }

        if contains(.megaCap)         { add(MegaCapEquities.symbols) }
        if contains(.topAUMETFs)      { add(TopAUMETFs.symbols) }
        if contains(.topVolETFs)      { add(TopVolumeETFs.symbols) }
        if contains(.stateStreetETFs) { add(StateStreetETFs.symbols) }
        if contains(.vanguardETFs)    { add(VanguardETFs.symbols) }
        if contains(.personal)        { add(personalWatchlist) }

        return result
    }

    /// Returns all symbols from every source regardless of toggles (for caching).
    static func allSymbols(personalWatchlist: [String]) -> [String] {
        allSources.symbols(personalWatchlist: personalWatchlist)
    }

    /// Returns the set of all bundled symbols (not including personal watchlist).
    static var allBundledSymbols: Set<String> {
        var combined = Set(MegaCapEquities.symbols)
        combined.formUnion(TopAUMETFs.symbols)
        combined.formUnion(TopVolumeETFs.symbols)
        combined.formUnion(StateStreetETFs.symbols)
        combined.formUnion(VanguardETFs.symbols)
        return combined
    }
}
