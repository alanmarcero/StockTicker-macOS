import Foundation
import AppKit

// MARK: - Menu Bar Asset (for closed/pre-market display)

enum MenuBarAsset: String, Codable, CaseIterable {
    case spy = "SPY"
    case bitcoin = "BTC-USD"
    case ethereum = "ETH-USD"
    case xrp = "XRP-USD"
    case dogecoin = "DOGE-USD"
    case solana = "SOL-USD"

    var displayName: String {
        switch self {
        case .spy: return "SPY"
        case .bitcoin: return "Bitcoin"
        case .ethereum: return "Ethereum"
        case .xrp: return "XRP"
        case .dogecoin: return "Dogecoin"
        case .solana: return "Solana"
        }
    }

    var symbol: String { rawValue }
}

// Legacy alias for backward compatibility
typealias ClosedMarketAsset = MenuBarAsset

// MARK: - Legacy Decoding Helper

private extension KeyedDecodingContainer {
    /// Decodes a value trying the primary key first, then falling back to a legacy key.
    /// Throws if neither key is present (required field).
    func decodeLegacy<T: Decodable>(_ type: T.Type, primary: Key, legacy: Key) throws -> T {
        if let value = try decodeIfPresent(type, forKey: primary) { return value }
        return try decode(type, forKey: legacy)
    }

    /// Decodes a value trying the primary key first, then the legacy key, then a default.
    func decodeLegacy<T: Decodable>(_ type: T.Type, primary: Key, legacy: Key, default defaultValue: T) throws -> T {
        if let value = try decodeIfPresent(type, forKey: primary) { return value }
        return try decodeIfPresent(type, forKey: legacy) ?? defaultValue
    }
}

// MARK: - Watchlist Config

struct IndexSymbol: Codable, Equatable {
    let symbol: String
    let displayName: String
}

struct WatchlistConfig: Codable, Equatable {
    static let maxWatchlistSize = LayoutConfig.Watchlist.maxSize

    var watchlist: [String]
    var menuBarRotationInterval: Int
    var refreshInterval: Int
    var sortDirection: String
    var menuBarAssetWhenClosed: MenuBarAsset
    var indexSymbols: [IndexSymbol]
    var alwaysOpenMarkets: [IndexSymbol]
    var highlightedSymbols: [String]
    var highlightColor: String
    var highlightOpacity: Double
    var showNewsHeadlines: Bool
    var newsRefreshInterval: Int
    var universe: [String]
    var finnhubApiKey: String
    var scannerBaseURL: String
    var filterGreenFields: Int
    var watchlistSources: Int

    static let defaultIndexSymbols: [IndexSymbol] = [
        IndexSymbol(symbol: "^GSPC", displayName: "SPX"),
        IndexSymbol(symbol: "^DJI", displayName: "DJI"),
        IndexSymbol(symbol: "^IXIC", displayName: "NDX"),
        IndexSymbol(symbol: "^VIX", displayName: "VIX"),
        IndexSymbol(symbol: "^RUT", displayName: "RUT"),
        IndexSymbol(symbol: "BTC-USD", displayName: "BTC")
    ]

    static let defaultAlwaysOpenMarkets: [IndexSymbol] = [
        IndexSymbol(symbol: "BTC-USD", displayName: "BTC"),
        IndexSymbol(symbol: "ETH-USD", displayName: "ETH"),
        IndexSymbol(symbol: "SOL-USD", displayName: "SOL"),
        IndexSymbol(symbol: "DOGE-USD", displayName: "DOGE"),
        IndexSymbol(symbol: "XRP-USD", displayName: "XRP")
    ]

    // S&P 500 constituents (503 symbols including dual share classes)
    static let defaultUniverse: [String] = [
        "A", "AAPL", "ABBV", "ABNB", "ABT", "ACGL", "ACN", "ADBE", "ADI", "ADM",
        "ADP", "ADSK", "AEE", "AEP", "AES", "AFL", "AIG", "AIZ", "AJG", "AKAM",
        "ALB", "ALGN", "ALL", "ALLE", "AMAT", "AMD", "AME", "AMGN", "AMP", "AMT",
        "AMZN", "ANET", "AON", "AOS", "APA", "APD", "APH", "APO", "APP", "APTV",
        "ARE", "ARES", "AVGO", "AVB", "AVY", "AXON", "AXP", "AZO",
        "BA", "BAC", "BAX", "BBY", "BDX", "BEN", "BF-B", "BG", "BIIB", "BK",
        "BKNG", "BKR", "BLDR", "BLK", "BMY", "BR", "BRK-B", "BRO", "BSX", "BX",
        "BXP",
        "C", "CAG", "CAH", "CARR", "CAT", "CB", "CBOE", "CCI", "CCL", "CDNS",
        "CDW", "CEG", "CF", "CFG", "CHD", "CHRW", "CHTR", "CI", "CIEN", "CINF",
        "CL", "CLX", "CMS", "CNC", "CNP", "COF", "COIN", "COO", "COP", "COR",
        "COST", "CPAY", "CPB", "CPRT", "CPT", "CBRE", "CRH", "CRL", "CRM", "CRWD",
        "CSCO", "CSGP", "CSX", "CTAS", "CTSH", "CTVA", "CTRA", "CVS", "CVNA", "CVX",
        "D", "DAL", "DASH", "DD", "DDOG", "DE", "DECK", "DELL", "DG", "DGX",
        "DHI", "DHR", "DIS", "DLTR", "DOC", "DOV", "DOW", "DPZ", "DRI", "DTE",
        "DUK", "DVA", "DVN", "DXCM",
        "EA", "EBAY", "ECL", "ED", "EFX", "EG", "EIX", "EL", "ELV", "EME",
        "EMR", "EPAM", "EQIX", "EQR", "EQT", "ERIE", "ES", "ESS", "ETN", "ETR",
        "EVRG", "EW", "EXC", "EXE", "EXPD", "EXPE", "EXR",
        "F", "FANG", "FAST", "FSLR", "FCX", "FDS", "FDX", "FE", "FFIV",
        "FICO", "FIS", "FISV", "FITB", "FIX", "FOXA", "FOX", "FRT", "FTNT", "FTV",
        "GD", "GDDY", "GE", "GEHC", "GEN", "GEV", "GILD", "GIS", "GL", "GLW",
        "GM", "GNRC", "GOOG", "GOOGL", "GPC", "GPN", "GRMN", "GS", "GWW",
        "HAL", "HAS", "HBAN", "HCA", "HD", "HOLX", "HON", "HOOD", "HPE", "HPQ",
        "HRL", "HSIC", "HST", "HSY", "HUBB", "HUM", "HWM", "HIG", "HII", "HLT",
        "IBKR", "ICE", "IDXX", "IEX", "IFF", "INCY", "INTC", "INTU", "INVH", "IP",
        "IQV", "IR", "IRM", "ISRG", "IT", "ITW", "IVZ",
        "J", "JBL", "JBHT", "JCI", "JKHY", "JNJ", "JPM",
        "KDP", "KEY", "KEYS", "KHC", "KIM", "KKR", "KLAC", "KMB", "KMI",
        "KO", "KR", "KVUE",
        "L", "LDOS", "LEN", "LH", "LHX", "LII", "LIN", "LRCX", "LULU", "LUV",
        "LVS", "LW", "LYB", "LYV", "LLY", "LMT", "LNT", "LOW",
        "MA", "MAA", "MAR", "MAS", "MCD", "MCHP", "MCK", "MCO", "MDLZ", "MDT",
        "MET", "META", "MGM", "MKC", "MLM", "MMM", "MNST", "MO", "MOH", "MOS",
        "MPC", "MPWR", "MRK", "MRNA", "MRSH", "MS", "MSCI", "MSFT", "MSI", "MTB",
        "MTCH", "MTD", "MU",
        "NCLH", "NDAQ", "NDSN", "NEM", "NEE", "NFLX", "NI", "NKE", "NOC",
        "NOW", "NRG", "NSC", "NTAP", "NTRS", "NUE", "NVDA", "NVR", "NWS", "NWSA",
        "NXPI",
        "O", "ODFL", "OKE", "OMC", "ON", "ORCL", "ORLY", "OTIS", "OXY",
        "PANW", "PAYC", "PAYX", "PCAR", "PCG", "PEG", "PEP", "PFE", "PFG", "PG",
        "PGR", "PH", "PHM", "PKG", "PLD", "PLTR", "PM", "PNC", "PNR", "PNW",
        "PODD", "POOL", "PPG", "PPL", "PRU", "PSA", "PSKY", "PSX", "PTC", "PYPL",
        "Q", "QCOM",
        "RCL", "REG", "REGN", "RF", "RJF", "RL", "RMD", "ROK", "ROL",
        "ROP", "ROST", "RSG", "RTX", "RVTY",
        "SBAC", "SBUX", "SCHW", "SHW", "SJM", "SLB", "SMCI", "SNA", "SNDK", "SNPS",
        "SO", "SOLV", "SPG", "SPGI", "SRE", "STE", "STLD", "STT", "STX", "STZ",
        "SW", "SWK", "SWKS", "SYF", "SYK", "SYY",
        "T", "TAP", "TDG", "TDY", "TECH", "TEL", "TER", "TFC", "TGT", "TJX",
        "TKO", "TMO", "TMUS", "TPL", "TPR", "TRGP", "TRMB", "TROW", "TRV", "TSCO",
        "TSLA", "TSN", "TT", "TTD", "TTWO", "TXN", "TXT", "TYL",
        "UAL", "UBER", "UDR", "UHS", "ULTA", "UNH", "UNP", "UPS", "URI", "USB",
        "V", "VICI", "VLO", "VLTO", "VMC", "VRSK", "VRSN", "VRTX", "VST", "VTR",
        "VTRS", "VZ",
        "WAB", "WAT", "WBA", "WBD", "WDAY", "WDC", "WEC", "WELL", "WFC", "WM",
        "WMB", "WMT", "WRB", "WSM", "WST", "WTW", "WY", "WYNN",
        "XEL", "XOM", "XYL", "XYZ",
        "YUM",
        "ZBH", "ZBRA", "ZTS"
    ]

    static let defaultConfig = WatchlistConfig(
        watchlist: [],
        menuBarRotationInterval: 5,
        refreshInterval: 30,
        sortDirection: "percentDesc",
        menuBarAssetWhenClosed: .bitcoin,
        indexSymbols: defaultIndexSymbols,
        alwaysOpenMarkets: defaultAlwaysOpenMarkets,
        highlightedSymbols: ["SPY"],
        highlightColor: "yellow",
        highlightOpacity: 0.25,
        showNewsHeadlines: true,
        newsRefreshInterval: 300,
        universe: defaultUniverse
    )

    private enum CodingKeys: String, CodingKey {
        case watchlist, tickers  // Support both for backward compatibility
        case menuBarRotationInterval, cycleInterval  // cycleInterval for backward compatibility
        case refreshInterval, sortDirection, defaultSort  // defaultSort for backward compatibility
        case menuBarAssetWhenClosed, closedMarketAsset  // closedMarketAsset for backward compatibility
        case indexSymbols, indexTickers  // Support both for backward compatibility
        case alwaysOpenMarkets
        case highlightedSymbols, highlightedTickers  // Support both
        case highlightColor, highlightOpacity
        case showNewsHeadlines, newsRefreshInterval
        case universe
        case finnhubApiKey
        case scannerBaseURL
        case filterGreenFields
        case watchlistSources
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Fields with legacy key fallback (backward compatibility)
        watchlist = try container.decodeLegacy([String].self, primary: .watchlist, legacy: .tickers)
        menuBarRotationInterval = try container.decodeLegacy(Int.self, primary: .menuBarRotationInterval, legacy: .cycleInterval)
        sortDirection = try container.decodeLegacy(String.self, primary: .sortDirection, legacy: .defaultSort, default: "percentDesc")
        menuBarAssetWhenClosed = try container.decodeLegacy(MenuBarAsset.self, primary: .menuBarAssetWhenClosed, legacy: .closedMarketAsset, default: .bitcoin)
        indexSymbols = try container.decodeLegacy([IndexSymbol].self, primary: .indexSymbols, legacy: .indexTickers, default: WatchlistConfig.defaultIndexSymbols)
        highlightedSymbols = try container.decodeLegacy([String].self, primary: .highlightedSymbols, legacy: .highlightedTickers, default: ["SPY"])

        // Fields without legacy keys
        refreshInterval = try container.decodeIfPresent(Int.self, forKey: .refreshInterval) ?? 30
        alwaysOpenMarkets = try container.decodeIfPresent([IndexSymbol].self, forKey: .alwaysOpenMarkets) ?? WatchlistConfig.defaultAlwaysOpenMarkets
        highlightColor = try container.decodeIfPresent(String.self, forKey: .highlightColor) ?? "yellow"
        highlightOpacity = try container.decodeIfPresent(Double.self, forKey: .highlightOpacity) ?? 0.25
        showNewsHeadlines = try container.decodeIfPresent(Bool.self, forKey: .showNewsHeadlines) ?? true
        newsRefreshInterval = try container.decodeIfPresent(Int.self, forKey: .newsRefreshInterval) ?? 300
        universe = try container.decodeIfPresent([String].self, forKey: .universe) ?? []
        finnhubApiKey = try container.decodeIfPresent(String.self, forKey: .finnhubApiKey) ?? ""
        scannerBaseURL = try container.decodeIfPresent(String.self, forKey: .scannerBaseURL) ?? ""
        filterGreenFields = try container.decodeIfPresent(Int.self, forKey: .filterGreenFields) ?? 0
        watchlistSources = try container.decodeIfPresent(Int.self, forKey: .watchlistSources) ?? WatchlistSource.allSources.rawValue
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(watchlist, forKey: .watchlist)
        try container.encode(menuBarRotationInterval, forKey: .menuBarRotationInterval)
        try container.encode(refreshInterval, forKey: .refreshInterval)
        try container.encode(sortDirection, forKey: .sortDirection)
        try container.encode(menuBarAssetWhenClosed, forKey: .menuBarAssetWhenClosed)
        try container.encode(indexSymbols, forKey: .indexSymbols)
        try container.encode(alwaysOpenMarkets, forKey: .alwaysOpenMarkets)
        try container.encode(highlightedSymbols, forKey: .highlightedSymbols)
        try container.encode(highlightColor, forKey: .highlightColor)
        try container.encode(highlightOpacity, forKey: .highlightOpacity)
        try container.encode(showNewsHeadlines, forKey: .showNewsHeadlines)
        try container.encode(newsRefreshInterval, forKey: .newsRefreshInterval)
        try container.encode(universe, forKey: .universe)
        try container.encode(finnhubApiKey, forKey: .finnhubApiKey)
        try container.encode(scannerBaseURL, forKey: .scannerBaseURL)
        try container.encode(filterGreenFields, forKey: .filterGreenFields)
        try container.encode(watchlistSources, forKey: .watchlistSources)
    }

    init(
        watchlist: [String],
        menuBarRotationInterval: Int,
        refreshInterval: Int = 30,
        sortDirection: String,
        menuBarAssetWhenClosed: MenuBarAsset = .bitcoin,
        indexSymbols: [IndexSymbol] = defaultIndexSymbols,
        alwaysOpenMarkets: [IndexSymbol] = defaultAlwaysOpenMarkets,
        highlightedSymbols: [String] = ["SPY"],
        highlightColor: String = "yellow",
        highlightOpacity: Double = 0.25,
        showNewsHeadlines: Bool = true,
        newsRefreshInterval: Int = 300,
        universe: [String] = [],
        finnhubApiKey: String = "",
        scannerBaseURL: String = "",
        filterGreenFields: Int = 0,
        watchlistSources: Int = 63  // WatchlistSource.allSources.rawValue
    ) {
        self.watchlist = watchlist
        self.menuBarRotationInterval = menuBarRotationInterval
        self.refreshInterval = refreshInterval
        self.sortDirection = sortDirection
        self.menuBarAssetWhenClosed = menuBarAssetWhenClosed
        self.indexSymbols = indexSymbols
        self.alwaysOpenMarkets = alwaysOpenMarkets
        self.highlightedSymbols = highlightedSymbols
        self.highlightColor = highlightColor
        self.highlightOpacity = highlightOpacity
        self.showNewsHeadlines = showNewsHeadlines
        self.newsRefreshInterval = newsRefreshInterval
        self.universe = universe
        self.finnhubApiKey = finnhubApiKey
        self.scannerBaseURL = scannerBaseURL
        self.filterGreenFields = filterGreenFields
        self.watchlistSources = watchlistSources
    }
}

// MARK: - Config Manager

class WatchlistConfigManager {
    static let shared = WatchlistConfigManager()

    private let fileSystem: FileSystemProtocol
    private let workspace: WorkspaceProtocol
    private let configDirectory: String
    private let configFileName: String

    init(
        fileSystem: FileSystemProtocol = FileManager.default,
        workspace: WorkspaceProtocol = NSWorkspace.shared,
        configDirectory: String = ".stockticker",
        configFileName: String = "config.json"
    ) {
        self.fileSystem = fileSystem
        self.workspace = workspace
        self.configDirectory = configDirectory
        self.configFileName = configFileName
    }

    var configDirectoryURL: URL {
        fileSystem.homeDirectoryForCurrentUser.appendingPathComponent(configDirectory)
    }

    var configFileURL: URL {
        configDirectoryURL.appendingPathComponent(configFileName)
    }

    func load(backfillDefaults: Bool = false) -> WatchlistConfig {
        ensureDirectoryExists()

        guard fileSystem.fileExists(atPath: configFileURL.path),
              let data = fileSystem.contentsOfFile(atPath: configFileURL.path) else {
            return saveDefault()
        }

        do {
            var config = try JSONDecoder().decode(WatchlistConfig.self, from: data)
            config.watchlist = Array(config.watchlist.prefix(WatchlistConfig.maxWatchlistSize))
            if backfillDefaults {
                save(config)
            }
            return config
        } catch {
            print("Config parse error (keeping current config): \(error.localizedDescription)")
            return WatchlistConfig.defaultConfig
        }
    }

    @discardableResult
    func saveDefault() -> WatchlistConfig {
        save(WatchlistConfig.defaultConfig)
        return WatchlistConfig.defaultConfig
    }

    func save(_ config: WatchlistConfig) {
        ensureDirectoryExists()

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        do {
            let data = try encoder.encode(config)
            try fileSystem.writeData(data, to: configFileURL)
        } catch {
            print("Failed to save config: \(error.localizedDescription)")
        }
    }

    func openConfigFile() {
        if !fileSystem.fileExists(atPath: configFileURL.path) {
            saveDefault()
        }
        workspace.openURL(configFileURL)
    }

    private func ensureDirectoryExists() {
        guard !fileSystem.fileExists(atPath: configDirectoryURL.path) else { return }
        do {
            try fileSystem.createDirectoryAt(configDirectoryURL, withIntermediateDirectories: true)
        } catch {
            print("Failed to create config directory: \(error.localizedDescription)")
        }
    }
}

// MARK: - Convenience (Backwards Compatibility)

extension WatchlistConfig {
    static var configDirectoryURL: URL {
        WatchlistConfigManager.shared.configDirectoryURL
    }

    static var configFileURL: URL {
        WatchlistConfigManager.shared.configFileURL
    }

    static func load() -> WatchlistConfig {
        WatchlistConfigManager.shared.load()
    }

    @discardableResult
    static func saveDefault() -> WatchlistConfig {
        WatchlistConfigManager.shared.saveDefault()
    }

    func save() {
        WatchlistConfigManager.shared.save(self)
    }

    static func openConfigFile() {
        WatchlistConfigManager.shared.openConfigFile()
    }
}
