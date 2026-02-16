import XCTest
@testable import StockTicker

// MARK: - Mock Workspace

final class MockWorkspace: WorkspaceProtocol {
    var openedURLs: [URL] = []

    func openURL(_ url: URL) {
        openedURLs.append(url)
    }
}

// MARK: - IndexSymbol Tests

final class IndexSymbolTests: XCTestCase {

    func testIndexSymbol_codable() throws {
        let symbol = IndexSymbol(symbol: "^GSPC", displayName: "SPX")
        let data = try JSONEncoder().encode(symbol)
        let decoded = try JSONDecoder().decode(IndexSymbol.self, from: data)

        XCTAssertEqual(decoded.symbol, "^GSPC")
        XCTAssertEqual(decoded.displayName, "SPX")
    }

    func testIndexSymbol_equatable() {
        let symbol1 = IndexSymbol(symbol: "^GSPC", displayName: "SPX")
        let symbol2 = IndexSymbol(symbol: "^GSPC", displayName: "SPX")
        let symbol3 = IndexSymbol(symbol: "^DJI", displayName: "DJI")

        XCTAssertEqual(symbol1, symbol2)
        XCTAssertNotEqual(symbol1, symbol3)
    }
}

// MARK: - MenuBarAsset Tests

final class ClosedMarketAssetTests: XCTestCase {

    func testAllCases_containsExpectedAssets() {
        XCTAssertEqual(MenuBarAsset.allCases.count, 6)
        XCTAssertTrue(MenuBarAsset.allCases.contains(.spy))
        XCTAssertTrue(MenuBarAsset.allCases.contains(.bitcoin))
        XCTAssertTrue(MenuBarAsset.allCases.contains(.ethereum))
    }

    func testSymbol_matchesRawValue() {
        XCTAssertEqual(MenuBarAsset.spy.symbol, "SPY")
        XCTAssertEqual(MenuBarAsset.bitcoin.symbol, "BTC-USD")
        XCTAssertEqual(MenuBarAsset.ethereum.symbol, "ETH-USD")
    }

    func testDisplayName_returnsReadableName() {
        XCTAssertEqual(MenuBarAsset.spy.displayName, "SPY")
        XCTAssertEqual(MenuBarAsset.bitcoin.displayName, "Bitcoin")
        XCTAssertEqual(MenuBarAsset.ethereum.displayName, "Ethereum")
    }
}

// MARK: - WatchlistConfig Tests

final class WatchlistConfigTests: XCTestCase {

    func testDefaultConfig_hasExpectedValues() {
        let config = WatchlistConfig.defaultConfig

        XCTAssertEqual(config.watchlist, [
            "SPY", "QQQ", "XLU", "XLP", "XLC", "XLRE", "XLI", "XLV", "XLE", "XLF",
            "XLK", "XLY", "XLB", "IWM", "DIA", "IBIT", "ETHA", "SLV", "GLD", "SMH",
            "NVDA", "AAPL", "GOOGL", "MSFT", "AMZN", "TSM", "META", "AVGO", "TSLA",
            "BRK-B", "WMT", "LLY", "JPM", "XOM", "V", "JNJ", "ASML",
            "SSK", "XRPR", "DOJE", "TMUS"
        ])
        XCTAssertEqual(config.menuBarRotationInterval, 5)
        XCTAssertEqual(config.refreshInterval, 15)
        XCTAssertEqual(config.sortDirection, "percentDesc")
        XCTAssertEqual(config.menuBarAssetWhenClosed, .bitcoin)
        XCTAssertEqual(config.indexSymbols.count, 6)
        XCTAssertTrue(config.showNewsHeadlines)
        XCTAssertEqual(config.newsRefreshInterval, 300)
    }

    func testDefaultConfig_watchlistCount() {
        XCTAssertEqual(WatchlistConfig.defaultConfig.watchlist.count, 41)
    }

    func testDefaultConfig_containsNewTickers() {
        let watchlist = WatchlistConfig.defaultConfig.watchlist
        XCTAssertTrue(watchlist.contains("SSK"))
        XCTAssertTrue(watchlist.contains("XRPR"))
        XCTAssertTrue(watchlist.contains("DOJE"))
        XCTAssertTrue(watchlist.contains("TMUS"))
    }

    func testDefaultConfig_watchlistWithinMaxSize() {
        XCTAssertLessThanOrEqual(
            WatchlistConfig.defaultConfig.watchlist.count,
            LayoutConfig.Watchlist.maxSize
        )
    }

    func testMaxWatchlistSize_is128() {
        XCTAssertEqual(LayoutConfig.Watchlist.maxSize, 128)
    }

    func testDefaultIndexSymbols_hasExpectedIndexes() {
        let indexes = WatchlistConfig.defaultIndexSymbols

        XCTAssertEqual(indexes.count, 6)
        XCTAssertEqual(indexes[0].symbol, "^GSPC")
        XCTAssertEqual(indexes[0].displayName, "SPX")
        XCTAssertEqual(indexes[1].symbol, "^DJI")
        XCTAssertEqual(indexes[1].displayName, "DJI")
    }

    func testMaxWatchlistSize_matchesLayoutConfig() {
        XCTAssertEqual(WatchlistConfig.maxWatchlistSize, LayoutConfig.Watchlist.maxSize)
    }

    func testEquatable_sameConfig_areEqual() {
        let config1 = WatchlistConfig(watchlist: ["SPY", "QQQ"], menuBarRotationInterval: 5, sortDirection: "percentDesc")
        let config2 = WatchlistConfig(watchlist: ["SPY", "QQQ"], menuBarRotationInterval: 5, sortDirection: "percentDesc")

        XCTAssertEqual(config1, config2)
    }

    func testEquatable_differentSymbols_areNotEqual() {
        let config1 = WatchlistConfig(watchlist: ["SPY"], menuBarRotationInterval: 5, sortDirection: "percentDesc")
        let config2 = WatchlistConfig(watchlist: ["QQQ"], menuBarRotationInterval: 5, sortDirection: "percentDesc")

        XCTAssertNotEqual(config1, config2)
    }

    func testEquatable_differentInterval_areNotEqual() {
        let config1 = WatchlistConfig(watchlist: ["SPY"], menuBarRotationInterval: 5, sortDirection: "percentDesc")
        let config2 = WatchlistConfig(watchlist: ["SPY"], menuBarRotationInterval: 10, sortDirection: "percentDesc")

        XCTAssertNotEqual(config1, config2)
    }

    func testDecoder_missingOptionalFields_usesDefaults() throws {
        let json = """
        {
            "tickers": ["SPY"],
            "menuBarRotationInterval": 5,
            "sortDirection": "percentDesc"
        }
        """.data(using: .utf8)!

        let config = try JSONDecoder().decode(WatchlistConfig.self, from: json)

        XCTAssertEqual(config.refreshInterval, 15)
        XCTAssertEqual(config.menuBarAssetWhenClosed, .bitcoin)
        XCTAssertEqual(config.indexSymbols, WatchlistConfig.defaultIndexSymbols)
    }

    func testDecoder_customIndexSymbols_decodesCorrectly() throws {
        let json = """
        {
            "tickers": ["SPY"],
            "menuBarRotationInterval": 5,
            "sortDirection": "percentDesc",
            "indexTickers": [
                {"symbol": "^GSPC", "displayName": "S&P500"}
            ]
        }
        """.data(using: .utf8)!

        let config = try JSONDecoder().decode(WatchlistConfig.self, from: json)

        XCTAssertEqual(config.indexSymbols.count, 1)
        XCTAssertEqual(config.indexSymbols[0].displayName, "S&P500")
    }

    // MARK: - Highlighted symbols tests

    func testDecoder_missingHighlightedSymbols_usesDefaults() throws {
        let json = """
        {
            "tickers": ["SPY"],
            "menuBarRotationInterval": 5,
            "sortDirection": "percentDesc"
        }
        """.data(using: .utf8)!

        let config = try JSONDecoder().decode(WatchlistConfig.self, from: json)

        // Compare against actual defaults, not hardcoded values
        XCTAssertEqual(config.highlightedSymbols, WatchlistConfig.defaultConfig.highlightedSymbols)
        XCTAssertEqual(config.highlightColor, WatchlistConfig.defaultConfig.highlightColor)
        XCTAssertEqual(config.highlightOpacity, WatchlistConfig.defaultConfig.highlightOpacity)
    }

    func testDecoder_emptyHighlightedSymbols_decodesAsEmpty() throws {
        let json = """
        {
            "tickers": ["SPY", "QQQ"],
            "menuBarRotationInterval": 5,
            "sortDirection": "percentDesc",
            "highlightedTickers": []
        }
        """.data(using: .utf8)!

        let config = try JSONDecoder().decode(WatchlistConfig.self, from: json)

        XCTAssertEqual(config.highlightedSymbols, [])
        XCTAssertTrue(config.highlightedSymbols.isEmpty)
    }

    func testDecoder_customHighlightSettings_decodesCorrectly() throws {
        let json = """
        {
            "tickers": ["SPY"],
            "menuBarRotationInterval": 5,
            "sortDirection": "percentDesc",
            "highlightedTickers": ["SPY", "QQQ"],
            "highlightColor": "orange",
            "highlightOpacity": 0.4
        }
        """.data(using: .utf8)!

        let config = try JSONDecoder().decode(WatchlistConfig.self, from: json)

        XCTAssertEqual(config.highlightedSymbols, ["SPY", "QQQ"])
        XCTAssertEqual(config.highlightColor, "orange")
        XCTAssertEqual(config.highlightOpacity, 0.4)
    }

    func testHighlightedSymbols_containsCheck_worksWithEmptyArray() {
        let config = WatchlistConfig(
            watchlist: ["SPY", "QQQ"],
            menuBarRotationInterval: 5,
            sortDirection: "percentDesc",
            highlightedSymbols: []
        )

        // This is the check used in MenuBarView - should not crash and return false
        XCTAssertFalse(config.highlightedSymbols.contains("SPY"))
        XCTAssertFalse(config.highlightedSymbols.contains("QQQ"))
        XCTAssertFalse(config.highlightedSymbols.contains("AAPL"))
    }

    // MARK: - sortDirection backward compatibility tests

    func testDecoder_legacyDefaultSort_decodesToSortDirection() throws {
        let json = """
        {
            "tickers": ["SPY"],
            "menuBarRotationInterval": 5,
            "defaultSort": "tickerAsc"
        }
        """.data(using: .utf8)!

        let config = try JSONDecoder().decode(WatchlistConfig.self, from: json)

        XCTAssertEqual(config.sortDirection, "tickerAsc")
    }

    func testDecoder_newSortDirection_takePrecedenceOverDefaultSort() throws {
        let json = """
        {
            "tickers": ["SPY"],
            "menuBarRotationInterval": 5,
            "sortDirection": "changeDesc",
            "defaultSort": "tickerAsc"
        }
        """.data(using: .utf8)!

        let config = try JSONDecoder().decode(WatchlistConfig.self, from: json)

        XCTAssertEqual(config.sortDirection, "changeDesc")
    }

    func testDecoder_missingSortDirection_usesDefaultPercentDesc() throws {
        let json = """
        {
            "tickers": ["SPY"],
            "menuBarRotationInterval": 5
        }
        """.data(using: .utf8)!

        let config = try JSONDecoder().decode(WatchlistConfig.self, from: json)

        XCTAssertEqual(config.sortDirection, "percentDesc")
    }

    // MARK: - alwaysOpenMarkets tests

    func testDecoder_missingAlwaysOpenMarkets_usesDefaults() throws {
        let json = """
        {
            "tickers": ["SPY"],
            "menuBarRotationInterval": 5,
            "sortDirection": "percentDesc"
        }
        """.data(using: .utf8)!

        let config = try JSONDecoder().decode(WatchlistConfig.self, from: json)

        XCTAssertEqual(config.alwaysOpenMarkets, WatchlistConfig.defaultAlwaysOpenMarkets)
        XCTAssertEqual(config.alwaysOpenMarkets.count, 5)
    }

    func testDecoder_customAlwaysOpenMarkets_decodesCorrectly() throws {
        let json = """
        {
            "tickers": ["SPY"],
            "menuBarRotationInterval": 5,
            "sortDirection": "percentDesc",
            "alwaysOpenMarkets": [
                {"symbol": "BTC-USD", "displayName": "Bitcoin"}
            ]
        }
        """.data(using: .utf8)!

        let config = try JSONDecoder().decode(WatchlistConfig.self, from: json)

        XCTAssertEqual(config.alwaysOpenMarkets.count, 1)
        XCTAssertEqual(config.alwaysOpenMarkets[0].symbol, "BTC-USD")
        XCTAssertEqual(config.alwaysOpenMarkets[0].displayName, "Bitcoin")
    }

    func testDefaultAlwaysOpenMarkets_containsExpectedCryptos() {
        let markets = WatchlistConfig.defaultAlwaysOpenMarkets

        XCTAssertEqual(markets.count, 5)

        let symbols = markets.map { $0.symbol }
        XCTAssertTrue(symbols.contains("BTC-USD"))
        XCTAssertTrue(symbols.contains("ETH-USD"))
        XCTAssertTrue(symbols.contains("SOL-USD"))
        XCTAssertTrue(symbols.contains("DOGE-USD"))
        XCTAssertTrue(symbols.contains("XRP-USD"))
    }

    // MARK: - menuBarAssetWhenClosed backward compatibility tests

    func testDecoder_legacyClosedMarketAsset_decodesToMenuBarAssetWhenClosed() throws {
        let json = """
        {
            "tickers": ["SPY"],
            "menuBarRotationInterval": 5,
            "sortDirection": "percentDesc",
            "closedMarketAsset": "ETH-USD"
        }
        """.data(using: .utf8)!

        let config = try JSONDecoder().decode(WatchlistConfig.self, from: json)

        XCTAssertEqual(config.menuBarAssetWhenClosed, .ethereum)
    }

    func testDecoder_newMenuBarAssetWhenClosed_takesPrecedence() throws {
        let json = """
        {
            "tickers": ["SPY"],
            "menuBarRotationInterval": 5,
            "sortDirection": "percentDesc",
            "menuBarAssetWhenClosed": "SOL-USD",
            "closedMarketAsset": "ETH-USD"
        }
        """.data(using: .utf8)!

        let config = try JSONDecoder().decode(WatchlistConfig.self, from: json)

        XCTAssertEqual(config.menuBarAssetWhenClosed, .solana)
    }

    // MARK: - Encoder tests

    func testEncoder_includesAllNewFields() throws {
        let config = WatchlistConfig(
            watchlist: ["SPY"],
            menuBarRotationInterval: 5,
            sortDirection: "changeAsc",
            menuBarAssetWhenClosed: .ethereum,
            alwaysOpenMarkets: [IndexSymbol(symbol: "BTC-USD", displayName: "BTC")]
        )

        let data = try JSONEncoder().encode(config)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertEqual(json["sortDirection"] as? String, "changeAsc")
        XCTAssertEqual(json["menuBarAssetWhenClosed"] as? String, "ETH-USD")
        XCTAssertNotNil(json["alwaysOpenMarkets"])
    }

    // MARK: - News Headlines Config Tests

    func testDecoder_missingNewsFields_usesDefaults() throws {
        let json = """
        {
            "tickers": ["SPY"],
            "menuBarRotationInterval": 5,
            "sortDirection": "percentDesc"
        }
        """.data(using: .utf8)!

        let config = try JSONDecoder().decode(WatchlistConfig.self, from: json)

        XCTAssertTrue(config.showNewsHeadlines)
        XCTAssertEqual(config.newsRefreshInterval, 300)
    }

    func testDecoder_showNewsHeadlinesFalse_decodesCorrectly() throws {
        let json = """
        {
            "tickers": ["SPY"],
            "menuBarRotationInterval": 5,
            "sortDirection": "percentDesc",
            "showNewsHeadlines": false
        }
        """.data(using: .utf8)!

        let config = try JSONDecoder().decode(WatchlistConfig.self, from: json)

        XCTAssertFalse(config.showNewsHeadlines)
    }

    func testDecoder_customNewsRefreshInterval_decodesCorrectly() throws {
        let json = """
        {
            "tickers": ["SPY"],
            "menuBarRotationInterval": 5,
            "sortDirection": "percentDesc",
            "newsRefreshInterval": 600
        }
        """.data(using: .utf8)!

        let config = try JSONDecoder().decode(WatchlistConfig.self, from: json)

        XCTAssertEqual(config.newsRefreshInterval, 600)
    }

    func testEncoder_includesNewsFields() throws {
        let config = WatchlistConfig(
            watchlist: ["SPY"],
            menuBarRotationInterval: 5,
            sortDirection: "percentDesc",
            showNewsHeadlines: false,
            newsRefreshInterval: 120
        )

        let data = try JSONEncoder().encode(config)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertEqual(json["showNewsHeadlines"] as? Bool, false)
        XCTAssertEqual(json["newsRefreshInterval"] as? Int, 120)
    }

    func testInit_withNewsFields_setsCorrectly() {
        let config = WatchlistConfig(
            watchlist: ["SPY"],
            menuBarRotationInterval: 5,
            sortDirection: "percentDesc",
            showNewsHeadlines: false,
            newsRefreshInterval: 180
        )

        XCTAssertFalse(config.showNewsHeadlines)
        XCTAssertEqual(config.newsRefreshInterval, 180)
    }

    func testInit_withDefaultNewsFields_usesDefaults() {
        let config = WatchlistConfig(
            watchlist: ["SPY"],
            menuBarRotationInterval: 5,
            sortDirection: "percentDesc"
        )

        XCTAssertTrue(config.showNewsHeadlines)
        XCTAssertEqual(config.newsRefreshInterval, 300)
    }

    func testEquatable_differentNewsSettings_areNotEqual() {
        let config1 = WatchlistConfig(
            watchlist: ["SPY"],
            menuBarRotationInterval: 5,
            sortDirection: "percentDesc",
            showNewsHeadlines: true
        )
        let config2 = WatchlistConfig(
            watchlist: ["SPY"],
            menuBarRotationInterval: 5,
            sortDirection: "percentDesc",
            showNewsHeadlines: false
        )

        XCTAssertNotEqual(config1, config2)
    }

    func testEquatable_differentNewsRefreshInterval_areNotEqual() {
        let config1 = WatchlistConfig(
            watchlist: ["SPY"],
            menuBarRotationInterval: 5,
            sortDirection: "percentDesc",
            newsRefreshInterval: 300
        )
        let config2 = WatchlistConfig(
            watchlist: ["SPY"],
            menuBarRotationInterval: 5,
            sortDirection: "percentDesc",
            newsRefreshInterval: 600
        )

        XCTAssertNotEqual(config1, config2)
    }

    func testRoundTrip_newsFields_preserved() throws {
        let original = WatchlistConfig(
            watchlist: ["SPY", "QQQ"],
            menuBarRotationInterval: 10,
            sortDirection: "tickerAsc",
            showNewsHeadlines: false,
            newsRefreshInterval: 120
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(WatchlistConfig.self, from: data)

        XCTAssertEqual(decoded.showNewsHeadlines, original.showNewsHeadlines)
        XCTAssertEqual(decoded.newsRefreshInterval, original.newsRefreshInterval)
    }
}

// MARK: - WatchlistConfigManager Tests

final class WatchlistConfigManagerTests: XCTestCase {

    // MARK: - configDirectoryURL tests

    func testConfigDirectoryURL_usesHomeDirectory() {
        let mockFS = MockFileSystem(homeDirectory: "/Users/test")
        let manager = WatchlistConfigManager(fileSystem: mockFS)

        XCTAssertEqual(manager.configDirectoryURL.path, "/Users/test/.stockticker")
    }

    func testConfigFileURL_hasCorrectPath() {
        let mockFS = MockFileSystem(homeDirectory: "/Users/test")
        let manager = WatchlistConfigManager(fileSystem: mockFS)

        XCTAssertEqual(manager.configFileURL.path, "/Users/test/.stockticker/config.json")
    }

    // MARK: - load tests

    func testLoad_noFileExists_createsDefault() {
        let mockFS = MockFileSystem()
        let manager = WatchlistConfigManager(fileSystem: mockFS)

        let config = manager.load()

        XCTAssertEqual(config, WatchlistConfig.defaultConfig)
        XCTAssertNotNil(mockFS.files[manager.configFileURL.path])
    }

    func testLoad_validFileExists_returnsConfig() {
        let mockFS = MockFileSystem(homeDirectory: "/Users/test")
        let customConfig = WatchlistConfig(watchlist: ["AAPL", "MSFT"], menuBarRotationInterval: 10, sortDirection: "tickerAsc")
        let jsonData = try! JSONEncoder().encode(customConfig)
        mockFS.files["/Users/test/.stockticker/config.json"] = jsonData
        mockFS.directories.insert("/Users/test/.stockticker")

        let manager = WatchlistConfigManager(fileSystem: mockFS)
        let config = manager.load()

        XCTAssertEqual(config.watchlist, ["AAPL", "MSFT"])
        XCTAssertEqual(config.menuBarRotationInterval, 10)
        XCTAssertEqual(config.sortDirection, "tickerAsc")
    }

    func testLoad_invalidJSON_createsDefault() {
        let mockFS = MockFileSystem(homeDirectory: "/Users/test")
        mockFS.files["/Users/test/.stockticker/config.json"] = "invalid json".data(using: .utf8)
        mockFS.directories.insert("/Users/test/.stockticker")

        let manager = WatchlistConfigManager(fileSystem: mockFS)
        let config = manager.load()

        XCTAssertEqual(config, WatchlistConfig.defaultConfig)
    }

    func testLoad_tooManyTickers_truncatesToMax() {
        let mockFS = MockFileSystem(homeDirectory: "/Users/test")
        let manyTickers = (1...150).map { "T\($0)" }
        let customConfig = WatchlistConfig(watchlist: manyTickers, menuBarRotationInterval: 5, sortDirection: "percentDesc")
        let jsonData = try! JSONEncoder().encode(customConfig)
        mockFS.files["/Users/test/.stockticker/config.json"] = jsonData
        mockFS.directories.insert("/Users/test/.stockticker")

        let manager = WatchlistConfigManager(fileSystem: mockFS)
        let config = manager.load()

        XCTAssertEqual(config.watchlist.count, LayoutConfig.Watchlist.maxSize)
    }

    // MARK: - save tests

    func testSave_writesConfigToFile() {
        let mockFS = MockFileSystem()
        let manager = WatchlistConfigManager(fileSystem: mockFS)
        let config = WatchlistConfig(watchlist: ["AAPL", "GOOGL"], menuBarRotationInterval: 7, sortDirection: "tickerDesc")

        manager.save(config)

        XCTAssertNotNil(mockFS.files[manager.configFileURL.path])

        let savedData = mockFS.files[manager.configFileURL.path]!
        let savedConfig = try! JSONDecoder().decode(WatchlistConfig.self, from: savedData)
        XCTAssertEqual(savedConfig, config)
    }

    func testSave_createsDirectoryIfNeeded() {
        let mockFS = MockFileSystem()
        let manager = WatchlistConfigManager(fileSystem: mockFS)
        let config = WatchlistConfig.defaultConfig

        manager.save(config)

        XCTAssertTrue(mockFS.directories.contains(manager.configDirectoryURL.path))
    }

    // MARK: - saveDefault tests

    func testSaveDefault_savesDefaultConfig() {
        let mockFS = MockFileSystem()
        let manager = WatchlistConfigManager(fileSystem: mockFS)

        let config = manager.saveDefault()

        XCTAssertEqual(config, WatchlistConfig.defaultConfig)
        XCTAssertNotNil(mockFS.files[manager.configFileURL.path])
    }

    func testSaveDefault_thenLoad_returnsDefaultConfig() {
        let mockFS = MockFileSystem()
        let manager = WatchlistConfigManager(fileSystem: mockFS)

        _ = manager.saveDefault()
        let loaded = manager.load()

        XCTAssertEqual(loaded, WatchlistConfig.defaultConfig)
    }

    func testSaveDefault_overwritesExistingConfig() {
        let mockFS = MockFileSystem()
        let manager = WatchlistConfigManager(fileSystem: mockFS)
        let customConfig = WatchlistConfig(watchlist: ["AAPL"], menuBarRotationInterval: 10, sortDirection: "tickerAsc")
        manager.save(customConfig)

        let resetConfig = manager.saveDefault()

        XCTAssertEqual(resetConfig, WatchlistConfig.defaultConfig)
        let loaded = manager.load()
        XCTAssertEqual(loaded, WatchlistConfig.defaultConfig)
    }

    // MARK: - openConfigFile tests

    func testOpenConfigFile_opensURL() {
        let mockFS = MockFileSystem()
        let mockWS = MockWorkspace()
        let manager = WatchlistConfigManager(fileSystem: mockFS, workspace: mockWS)

        manager.openConfigFile()

        XCTAssertEqual(mockWS.openedURLs.count, 1)
        XCTAssertEqual(mockWS.openedURLs.first, manager.configFileURL)
    }

    func testOpenConfigFile_createsDefaultIfNotExists() {
        let mockFS = MockFileSystem()
        let mockWS = MockWorkspace()
        let manager = WatchlistConfigManager(fileSystem: mockFS, workspace: mockWS)

        manager.openConfigFile()

        XCTAssertNotNil(mockFS.files[manager.configFileURL.path])
    }
}
