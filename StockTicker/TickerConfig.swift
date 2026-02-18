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

    static let defaultConfig = WatchlistConfig(
        watchlist: [
            "SPY", "QQQ", "XLU", "XLP", "XLC", "XLRE", "XLI", "XLV", "XLE", "XLF",
            "XLK", "XLY", "XLB", "IWM", "DIA", "IBIT", "ETHA", "SLV", "GLD", "SMH",
            "NVDA", "AAPL", "GOOGL", "MSFT", "AMZN", "TSM", "META", "AVGO", "TSLA",
            "BRK-B", "WMT", "LLY", "JPM", "XOM", "V", "JNJ", "ASML",
            "SSK", "XRPR", "DOJE", "TMUS"
        ],
        menuBarRotationInterval: 5,
        refreshInterval: 15,
        sortDirection: "percentDesc",
        menuBarAssetWhenClosed: .bitcoin,
        indexSymbols: defaultIndexSymbols,
        alwaysOpenMarkets: defaultAlwaysOpenMarkets,
        highlightedSymbols: ["SPY"],
        highlightColor: "yellow",
        highlightOpacity: 0.25,
        showNewsHeadlines: true,
        newsRefreshInterval: 300,
        universe: []
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
        refreshInterval = try container.decodeIfPresent(Int.self, forKey: .refreshInterval) ?? 15
        alwaysOpenMarkets = try container.decodeIfPresent([IndexSymbol].self, forKey: .alwaysOpenMarkets) ?? WatchlistConfig.defaultAlwaysOpenMarkets
        highlightColor = try container.decodeIfPresent(String.self, forKey: .highlightColor) ?? "yellow"
        highlightOpacity = try container.decodeIfPresent(Double.self, forKey: .highlightOpacity) ?? 0.25
        showNewsHeadlines = try container.decodeIfPresent(Bool.self, forKey: .showNewsHeadlines) ?? true
        newsRefreshInterval = try container.decodeIfPresent(Int.self, forKey: .newsRefreshInterval) ?? 300
        universe = try container.decodeIfPresent([String].self, forKey: .universe) ?? []
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
    }

    init(
        watchlist: [String],
        menuBarRotationInterval: Int,
        refreshInterval: Int = 15,
        sortDirection: String,
        menuBarAssetWhenClosed: MenuBarAsset = .bitcoin,
        indexSymbols: [IndexSymbol] = defaultIndexSymbols,
        alwaysOpenMarkets: [IndexSymbol] = defaultAlwaysOpenMarkets,
        highlightedSymbols: [String] = ["SPY"],
        highlightColor: String = "yellow",
        highlightOpacity: Double = 0.25,
        showNewsHeadlines: Bool = true,
        newsRefreshInterval: Int = 300,
        universe: [String] = []
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

    func load() -> WatchlistConfig {
        ensureDirectoryExists()

        guard fileSystem.fileExists(atPath: configFileURL.path),
              let data = fileSystem.contentsOfFile(atPath: configFileURL.path) else {
            return saveDefault()
        }

        do {
            var config = try JSONDecoder().decode(WatchlistConfig.self, from: data)
            config.watchlist = Array(config.watchlist.prefix(WatchlistConfig.maxWatchlistSize))
            // Save config to add any missing fields with defaults
            save(config)
            return config
        } catch {
            return saveDefault()
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
