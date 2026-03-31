import Foundation

struct WatchlistSource: OptionSet, Codable, Equatable {
    let rawValue: Int

    static let megaCap          = WatchlistSource(rawValue: 1 << 0)
    static let topAUMETFs       = WatchlistSource(rawValue: 1 << 1)
    static let topVolETFs       = WatchlistSource(rawValue: 1 << 2)
    static let personal         = WatchlistSource(rawValue: 1 << 3)
    static let stateStreetETFs  = WatchlistSource(rawValue: 1 << 4)
    static let vanguardETFs     = WatchlistSource(rawValue: 1 << 5)
    static let spdrSectors      = WatchlistSource(rawValue: 1 << 6)
    static let commodities      = WatchlistSource(rawValue: 1 << 7)

    static let allSources: WatchlistSource = [.megaCap, .topAUMETFs, .topVolETFs, .personal, .stateStreetETFs, .vanguardETFs, .spdrSectors, .commodities]

    static let allCases: [WatchlistSource] = [.megaCap, .topAUMETFs, .topVolETFs, .stateStreetETFs, .vanguardETFs, .spdrSectors, .commodities, .personal]

    var displayName: String {
        switch rawValue {
        case WatchlistSource.megaCap.rawValue: return "$100B+"
        case WatchlistSource.topAUMETFs.rawValue: return "Top AUM ETFs"
        case WatchlistSource.topVolETFs.rawValue: return "Top Vol ETFs"
        case WatchlistSource.personal.rawValue: return "Watchlist"
        case WatchlistSource.stateStreetETFs.rawValue: return "SPDR"
        case WatchlistSource.vanguardETFs.rawValue: return "Vanguard"
        case WatchlistSource.spdrSectors.rawValue: return "Sectors"
        case WatchlistSource.commodities.rawValue: return "Commodities"
        default: return "Sources"
        }
    }

    /// Returns the union of symbols from all enabled sources, deduplicated and ordered.
    func symbols(personalWatchlist: [String]) -> [String] {
        var sources: [[String]] = []
        
        if contains(.megaCap)         { sources.append(MegaCapEquities.symbols) }
        if contains(.topAUMETFs)      { sources.append(TopAUMETFs.symbols) }
        if contains(.topVolETFs)      { sources.append(TopVolumeETFs.symbols) }
        if contains(.stateStreetETFs) { sources.append(StateStreetETFs.symbols) }
        if contains(.vanguardETFs)    { sources.append(VanguardETFs.symbols) }
        if contains(.spdrSectors)     { sources.append(SPDRSectorETFs.symbols) }
        if contains(.commodities)     { sources.append(CommodityETFs.symbols) }
        if contains(.personal)        { sources.append(personalWatchlist) }

        var seen = Set<String>()
        return sources.flatMap { $0 }.filter { seen.insert($0).inserted }
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
        combined.formUnion(SPDRSectorETFs.symbols)
        combined.formUnion(CommodityETFs.symbols)
        return combined
    }
}
