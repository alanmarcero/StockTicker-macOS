import Foundation
import AppKit

// MARK: - Opaque Container View

/// NSView subclass that draws a solid opaque background to eliminate SwiftUI transparency.
/// Use this as a container for NSHostingView when creating windows that need zero transparency.
final class OpaqueContainerView: NSView {
    override var isOpaque: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.windowBackgroundColor.setFill()
        dirtyRect.fill()
        super.draw(dirtyRect)
    }
}

// MARK: - File System Protocol

protocol FileSystemProtocol {
    var homeDirectoryForCurrentUser: URL { get }
    func fileExists(atPath path: String) -> Bool
    func createDirectoryAt(_ url: URL, withIntermediateDirectories: Bool) throws
    func contentsOfFile(atPath path: String) -> Data?
    func writeData(_ data: Data, to url: URL) throws
}

extension FileManager: FileSystemProtocol {
    func createDirectoryAt(_ url: URL, withIntermediateDirectories createIntermediates: Bool) throws {
        try createDirectory(at: url, withIntermediateDirectories: createIntermediates)
    }

    func writeData(_ data: Data, to url: URL) throws {
        try data.write(to: url)
    }

    func contentsOfFile(atPath path: String) -> Data? {
        contents(atPath: path)
    }
}

// MARK: - Workspace Protocol

protocol WorkspaceProtocol {
    func openURL(_ url: URL)
}

extension NSWorkspace: WorkspaceProtocol {
    func openURL(_ url: URL) {
        open(url)
    }
}

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
        watchlist: ["SPY", "QQQ", "XLK", "IWM", "IBIT", "ETHA", "GLD", "SLV", "VXUS"],
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
        newsRefreshInterval: 300
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
    }

    // Custom decoder to handle missing fields and backward compatibility
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Support both "watchlist" (new) and "tickers" (legacy)
        if let watchlist = try container.decodeIfPresent([String].self, forKey: .watchlist) {
            self.watchlist = watchlist
        } else {
            self.watchlist = try container.decode([String].self, forKey: .tickers)
        }

        // Support both new and legacy key names
        if let interval = try container.decodeIfPresent(Int.self, forKey: .menuBarRotationInterval) {
            self.menuBarRotationInterval = interval
        } else {
            self.menuBarRotationInterval = try container.decode(Int.self, forKey: .cycleInterval)
        }
        refreshInterval = try container.decodeIfPresent(Int.self, forKey: .refreshInterval) ?? 15

        // Support both "sortDirection" (new) and "defaultSort" (legacy)
        if let sort = try container.decodeIfPresent(String.self, forKey: .sortDirection) {
            self.sortDirection = sort
        } else {
            self.sortDirection = try container.decodeIfPresent(String.self, forKey: .defaultSort) ?? "percentDesc"
        }

        // Support both "menuBarAssetWhenClosed" (new) and "closedMarketAsset" (legacy)
        if let asset = try container.decodeIfPresent(MenuBarAsset.self, forKey: .menuBarAssetWhenClosed) {
            self.menuBarAssetWhenClosed = asset
        } else {
            self.menuBarAssetWhenClosed = try container.decodeIfPresent(
                MenuBarAsset.self, forKey: .closedMarketAsset
            ) ?? .bitcoin
        }

        // Support both "indexSymbols" (new) and "indexTickers" (legacy)
        if let symbols = try container.decodeIfPresent([IndexSymbol].self, forKey: .indexSymbols) {
            self.indexSymbols = symbols
        } else {
            self.indexSymbols = try container.decodeIfPresent(
                [IndexSymbol].self, forKey: .indexTickers
            ) ?? WatchlistConfig.defaultIndexSymbols
        }

        self.alwaysOpenMarkets = try container.decodeIfPresent(
            [IndexSymbol].self, forKey: .alwaysOpenMarkets
        ) ?? WatchlistConfig.defaultAlwaysOpenMarkets

        // Support both "highlightedSymbols" (new) and "highlightedTickers" (legacy)
        if let highlighted = try container.decodeIfPresent([String].self, forKey: .highlightedSymbols) {
            self.highlightedSymbols = highlighted
        } else {
            self.highlightedSymbols = try container.decodeIfPresent([String].self, forKey: .highlightedTickers) ?? ["SPY"]
        }

        highlightColor = try container.decodeIfPresent(String.self, forKey: .highlightColor) ?? "yellow"
        highlightOpacity = try container.decodeIfPresent(Double.self, forKey: .highlightOpacity) ?? 0.25
        showNewsHeadlines = try container.decodeIfPresent(Bool.self, forKey: .showNewsHeadlines) ?? true
        newsRefreshInterval = try container.decodeIfPresent(Int.self, forKey: .newsRefreshInterval) ?? 300
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
    }

    init(watchlist: [String], menuBarRotationInterval: Int, refreshInterval: Int = 15, sortDirection: String, menuBarAssetWhenClosed: MenuBarAsset = .bitcoin, indexSymbols: [IndexSymbol] = defaultIndexSymbols, alwaysOpenMarkets: [IndexSymbol] = defaultAlwaysOpenMarkets, highlightedSymbols: [String] = ["SPY"], highlightColor: String = "yellow", highlightOpacity: Double = 0.25, showNewsHeadlines: Bool = true, newsRefreshInterval: Int = 300) {
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

        guard let data = try? encoder.encode(config) else { return }
        try? fileSystem.writeData(data, to: configFileURL)
    }

    func openConfigFile() {
        if !fileSystem.fileExists(atPath: configFileURL.path) {
            saveDefault()
        }
        workspace.openURL(configFileURL)
    }

    private func ensureDirectoryExists() {
        if !fileSystem.fileExists(atPath: configDirectoryURL.path) {
            try? fileSystem.createDirectoryAt(configDirectoryURL, withIntermediateDirectories: true)
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
