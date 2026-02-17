import SwiftUI
import AppKit

// MARK: - URL Opener Protocol

protocol URLOpener {
    func openInBrowser(_ url: URL)
}

extension NSWorkspace: URLOpener {
    func openInBrowser(_ url: URL) { open(url) }
}

// MARK: - Layout Constants (referencing centralized LayoutConfig)

private enum Layout {
    static let headerFontSize: CGFloat = LayoutConfig.Font.headerSize
    static let scheduleFontSize: CGFloat = LayoutConfig.Font.scheduleSize
}

// MARK: - Display Strings

private enum Strings {
    static let loading = "Loading..."
    static let emptyWatchlist = "Empty watchlist"
    static let noNewsAvailable = "No news available"
    static let noData = "--"
    static let countdownFormat = "Last: %@ \u{00B7} Next in %ds"
    static let nysePrefix = "NYSE: "
}

// MARK: - Timing Constants

private enum Timing {
    static let highlightFadeStep: CGFloat = 0.03
    static let highlightIntensityThreshold: CGFloat = 0.01
    static let highlightAlphaMultiplier: CGFloat = 0.6
}

// MARK: - Menu Bar Controller

@MainActor
class MenuBarController: NSObject, ObservableObject {
    // MARK: - Constants

    private enum MenuTag {
        static let marketStatus = 1001
        static let countdown = 1002
        static let indexLine = 1003
        static let headline1 = 1004
        static let headline2 = 1005
        static let headline3 = 1006
        static let headline4 = 1007
        static let headline5 = 1008
        static let headline6 = 1009
        static let allHeadlines = [headline1, headline2, headline3, headline4, headline5, headline6]
    }

    private enum TickerInsertIndex {
        static let start = 11  // After market status, countdown, index line, separator, 6 headlines, separator
    }

    // MARK: - Dependencies

    let stockService: StockServiceProtocol
    private let newsService: NewsServiceProtocol
    private let configManager: WatchlistConfigManager
    private let marketSchedule: MarketSchedule
    private let urlOpener: URLOpener

    // MARK: - Published State

    @Published var quotes: [String: StockQuote] = [:]
    @Published var currentIndex: Int = 0
    @Published var config: WatchlistConfig
    @Published var currentSortOption: SortOption
    @Published var yahooMarketState: String?

    // MARK: - Private State

    private var statusItem: NSStatusItem?
    private let timerManager = TimerManager()
    var indexQuotes: [String: StockQuote] = [:]
    private var newsItems: [NewsItem] = []
    private var marqueeView: MarqueeView?
    private var editorWindowController: WatchlistEditorWindowController?
    private var debugWindowController: DebugWindowController?
    private var lastRefreshTime = Date()
    private var countdownMenuItem: NSMenuItem?
    private var highlightIntensity: [String: CGFloat] = [:]
    private var tickerMenuItems: [String: NSMenuItem] = [:]
    private var isMenuOpen = false
    private var hasCompletedInitialLoad = false
    let ytdCacheManager: YTDCacheManager
    var ytdPrices: [String: Double] = [:]
    let quarterlyCacheManager: QuarterlyCacheManager
    var quarterlyPrices: [String: [String: Double]] = [:]
    var quarterInfos: [QuarterInfo] = []
    var marketCaps: [String: Double] = [:]
    let highestCloseCacheManager: HighestCloseCacheManager
    var highestClosePrices: [String: Double] = [:]
    let forwardPECacheManager: ForwardPECacheManager
    var forwardPEData: [String: [String: Double]] = [:]
    var currentForwardPEs: [String: Double] = [:]
    let swingLevelCacheManager: SwingLevelCacheManager
    var swingLevelEntries: [String: SwingLevelCacheEntry] = [:]
    let rsiCacheManager: RSICacheManager
    var rsiValues: [String: Double] = [:]
    let emaCacheManager: EMACacheManager
    var emaEntries: [String: EMACacheEntry] = [:]
    private var quarterlyWindowController: QuarterlyPanelWindowController?

    // MARK: - Initialization

    init(
        stockService: StockServiceProtocol = StockService(),
        newsService: NewsServiceProtocol = NewsService(),
        configManager: WatchlistConfigManager = .shared,
        marketSchedule: MarketSchedule = .shared,
        urlOpener: URLOpener = NSWorkspace.shared,
        ytdCacheManager: YTDCacheManager = YTDCacheManager(),
        quarterlyCacheManager: QuarterlyCacheManager = QuarterlyCacheManager(),
        highestCloseCacheManager: HighestCloseCacheManager = HighestCloseCacheManager(),
        forwardPECacheManager: ForwardPECacheManager = ForwardPECacheManager(),
        swingLevelCacheManager: SwingLevelCacheManager = SwingLevelCacheManager(),
        rsiCacheManager: RSICacheManager = RSICacheManager(),
        emaCacheManager: EMACacheManager = EMACacheManager()
    ) {
        self.stockService = stockService
        self.newsService = newsService
        self.configManager = configManager
        self.marketSchedule = marketSchedule
        self.urlOpener = urlOpener
        self.ytdCacheManager = ytdCacheManager
        self.quarterlyCacheManager = quarterlyCacheManager
        self.highestCloseCacheManager = highestCloseCacheManager
        self.forwardPECacheManager = forwardPECacheManager
        self.swingLevelCacheManager = swingLevelCacheManager
        self.rsiCacheManager = rsiCacheManager
        self.emaCacheManager = emaCacheManager

        let loadedConfig = configManager.load()
        self.config = loadedConfig
        self.currentSortOption = SortOption.from(configString: loadedConfig.sortDirection)

        super.init()

        timerManager.delegate = self
        setupStatusItem()
        startTimers()
        Task {
            await loadYTDCache()
            await loadQuarterlyCache()
            await loadHighestCloseCache()
            await loadForwardPECache()
            await loadSwingLevelCache()
            await loadRSICache()
            await loadEMACache()
            await refreshAllQuotes()
            await refreshNews()
        }
    }

    // MARK: - Setup

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem?.button else { return }
        button.title = Strings.loading
        button.font = MenuItemFactory.monoFontMedium
        setupMenu()
    }

    private func setupMenu() {
        let menu = NSMenu()

        menu.addItem(MenuItemFactory.disabled(title: "NYSE: --", tag: MenuTag.marketStatus))

        let countdownItem = MenuItemFactory.disabled(title: "Refreshing in --s", tag: MenuTag.countdown)
        menu.addItem(countdownItem)
        self.countdownMenuItem = countdownItem

        let marqueeFrame = NSRect(x: 0, y: 0, width: MarqueeConfig.viewWidth, height: MarqueeConfig.viewHeight)
        let marquee = MarqueeView(frame: marqueeFrame)
        self.marqueeView = marquee
        let indexItem = NSMenuItem()
        indexItem.view = marquee
        indexItem.tag = MenuTag.indexLine
        menu.addItem(indexItem)

        menu.addItem(.separator())

        for (index, tag) in MenuTag.allHeadlines.enumerated() {
            let title = index == 0 ? "Loading news..." : ""
            let headline = MenuItemFactory.action(
                title: title, action: #selector(openNewsArticle(_:)), target: self
            )
            headline.tag = tag
            headline.isHidden = index > 0
            menu.addItem(headline)
        }

        menu.addItem(.separator())
        menu.addItem(.separator())  // Ticker items inserted before this

        menu.addItem(MenuItemFactory.action(title: "Edit Watchlist...", action: #selector(editWatchlistHere), target: self, keyEquivalent: ","))

        let quarterlyItem = MenuItemFactory.action(title: "Extra Stats...", action: #selector(showQuarterlyPanel), target: self, keyEquivalent: "q")
        quarterlyItem.keyEquivalentModifierMask = [.command, .option]
        menu.addItem(quarterlyItem)

        menu.addItem(createConfigSubmenu())
        menu.addItem(createClosedMarketSubmenu())
        menu.addItem(createSortSubmenu())
        menu.addItem(createDebugSubmenu())
        menu.addItem(.separator())
        menu.addItem(MenuItemFactory.action(title: "Quit", action: #selector(quitApp), target: self, keyEquivalent: "q"))

        menu.delegate = self
        statusItem?.menu = menu
    }

    private func createClosedMarketSubmenu() -> NSMenuItem {
        let items = ClosedMarketAsset.allCases.map { asset -> NSMenuItem in
            let item = MenuItemFactory.action(title: asset.displayName, action: #selector(closedMarketAssetSelected(_:)), target: self)
            item.representedObject = asset
            item.state = (asset == config.menuBarAssetWhenClosed) ? .on : .off
            return item
        }
        return MenuItemFactory.submenu(title: "Closed Market Display", items: items)
    }

    private func createSortSubmenu() -> NSMenuItem {
        let items = SortOption.allCases.map { option -> NSMenuItem in
            let item = MenuItemFactory.action(title: option.rawValue, action: #selector(sortOptionSelected(_:)), target: self)
            item.representedObject = option
            return item
        }
        return MenuItemFactory.submenu(title: "Sort By", items: items)
    }

    private func createConfigSubmenu() -> NSMenuItem {
        let items = [
            MenuItemFactory.action(title: "Edit Config...", action: #selector(editConfigJson), target: self),
            MenuItemFactory.action(title: "Reload Config", action: #selector(reloadConfig), target: self),
            MenuItemFactory.action(title: "Reset Config to Default", action: #selector(resetConfigToDefault), target: self),
            MenuItemFactory.action(title: "Clear Cache", action: #selector(clearAllCaches), target: self)
        ]
        return MenuItemFactory.submenu(title: "Config", items: items)
    }

    private func createDebugSubmenu() -> NSMenuItem {
        let item = MenuItemFactory.action(title: "View API Requests...", action: #selector(showDebugWindow), target: self, keyEquivalent: "d")
        item.keyEquivalentModifierMask = [.command, .option]
        return MenuItemFactory.submenu(title: "Debug", items: [item])
    }

    // MARK: - Timer Management

    private func startTimers() {
        timerManager.startTimers(
            cycleInterval: config.menuBarRotationInterval,
            refreshInterval: config.refreshInterval,
            newsEnabled: config.showNewsHeadlines,
            newsInterval: config.newsRefreshInterval
        )
    }

    private func stopTimers() {
        timerManager.stopTimers()
        marqueeView?.stopScrolling()
    }

    private func startHighlightTimer() {
        timerManager.startHighlightTimer()
    }

    private func stopHighlightTimer() {
        timerManager.stopHighlightTimer()
    }

    private func updateHighlights() {
        for symbol in highlightIntensity.keys {
            guard let intensity = highlightIntensity[symbol], intensity > 0 else { continue }
            highlightIntensity[symbol] = max(0, intensity - Timing.highlightFadeStep)

            guard let menuItem = tickerMenuItems[symbol], let quote = quotes[symbol] else { continue }
            applyTickerStyle(to: menuItem, quote: quote, symbol: symbol)
        }

        updateCountdown()
    }

    // MARK: - Data Refresh

    func refreshAllQuotes() async {
        let scheduleInfo = marketSchedule.getTodaySchedule()
        let isWeekend = scheduleInfo.schedule.contains("Weekend")
        let isInitialLoad = !hasCompletedInitialLoad

        let closedMarketSymbol = config.menuBarAssetWhenClosed.symbol
        let indexSymbols = config.indexSymbols.map { $0.symbol }
        let alwaysOpenSymbols = config.alwaysOpenMarkets.map { $0.symbol }

        let result: FetchResult
        if isInitialLoad {
            result = await QuoteFetchCoordinator.fetchInitialLoad(
                service: stockService, watchlist: config.watchlist,
                indexSymbols: indexSymbols, alwaysOpenSymbols: alwaysOpenSymbols,
                closedMarketSymbol: closedMarketSymbol, isWeekend: isWeekend
            )
        } else if scheduleInfo.state == .closed || isWeekend {
            result = await QuoteFetchCoordinator.fetchClosedMarket(
                service: stockService, closedMarketSymbol: closedMarketSymbol,
                alwaysOpenSymbols: alwaysOpenSymbols
            )
        } else if scheduleInfo.state == .open {
            result = await QuoteFetchCoordinator.fetchRegularSession(
                service: stockService, watchlist: config.watchlist,
                indexSymbols: indexSymbols, closedMarketSymbol: closedMarketSymbol
            )
        } else {
            result = await QuoteFetchCoordinator.fetchExtendedHours(
                service: stockService, watchlist: config.watchlist,
                alwaysOpenSymbols: alwaysOpenSymbols, closedMarketSymbol: closedMarketSymbol
            )
        }

        if result.shouldMergeQuotes {
            self.quotes.merge(result.quotes) { _, new in new }
            self.indexQuotes.merge(result.indexQuotes) { _, new in new }
        } else {
            self.quotes = result.quotes
            self.indexQuotes = result.indexQuotes
        }
        self.yahooMarketState = result.yahooMarketState
        if result.isInitialLoadComplete { hasCompletedInitialLoad = true }

        self.lastRefreshTime = Date()
        attachYTDPricesToQuotes()

        if isInitialLoad || scheduleInfo.state == .open {
            let (fetchedCaps, fetchedPEs) = await stockService.fetchQuoteFields(symbols: config.watchlist)
            marketCaps.merge(fetchedCaps) { _, new in new }
            currentForwardPEs.merge(fetchedPEs) { _, new in new }
        }
        attachMarketCapsToQuotes()
        await refreshHighestClosesIfNeeded()
        attachHighestClosesToQuotes()
        await refreshSwingLevelsIfNeeded()
        await refreshRSIIfNeeded()
        await refreshEMAIfNeeded()
        highlightFetchedSymbols(result.fetchedSymbols)

        quarterlyWindowController?.refresh(quotes: quotes, quarterPrices: quarterlyPrices, highestClosePrices: highestClosePrices, forwardPEData: forwardPEData, currentForwardPEs: currentForwardPEs, swingLevelEntries: swingLevelEntries, rsiValues: rsiValues, emaEntries: emaEntries)

        updateMenuBarDisplay()
        updateMenuItems()
        updateMarketStatus()
        updateCountdown()
        updateIndexLine()
    }

    private func highlightFetchedSymbols(_ fetchedSymbols: Set<String>) {
        guard isMenuOpen, !fetchedSymbols.isEmpty else { return }
        config.watchlist.filter { fetchedSymbols.contains($0) }
            .forEach { highlightIntensity[$0] = 1.0 }
        marqueeView?.triggerPing()
    }

    private func cycleToNextTicker() {
        guard !config.watchlist.isEmpty else { return }

        // Only cycle during regular market hours
        if currentMarketState == .open {
            currentIndex = (currentIndex + 1) % config.watchlist.count
        }
        updateMenuBarDisplay()
    }

    private func updateIndexLine() {
        guard let marquee = marqueeView else { return }

        // Use alwaysOpenMarkets when regular market is not open, indexSymbols during regular hours
        let symbolsToDisplay = isRegularMarketClosed ? config.alwaysOpenMarkets : config.indexSymbols
        guard !symbolsToDisplay.isEmpty else { return }

        let attributedString = buildFullIndexAttributedString(symbols: symbolsToDisplay)
        marquee.updateText(attributedString)
    }

    /// Returns true when regular market session is not active (pre-market, after-hours, or closed)
    private var isRegularMarketClosed: Bool {
        currentMarketState != .open
    }

    private func buildFullIndexAttributedString(symbols: [IndexSymbol]) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let separatorAttrs: [NSAttributedString.Key: Any] = [.font: MenuItemFactory.monoFont]

        for (index, indexSymbol) in symbols.enumerated() {
            if index > 0 {
                result.append(NSAttributedString(string: MarqueeConfig.separator, attributes: separatorAttrs))
            }

            let quote = indexQuotes[indexSymbol.symbol]
            let color: NSColor
            if let validQuote = quote, !validQuote.isPlaceholder {
                color = validQuote.displayColor
            } else {
                color = .secondaryLabelColor
            }

            let nameAttrs: [NSAttributedString.Key: Any] = [
                .font: MenuItemFactory.monoFontMedium,
                .foregroundColor: color
            ]
            result.append(NSAttributedString(string: indexSymbol.displayName, attributes: nameAttrs))

            let valueText: String
            if let validQuote = quote, !validQuote.isPlaceholder {
                valueText = "  \(validQuote.formattedPrice)  \(validQuote.formattedChangePercent)"
            } else {
                valueText = "  \(Strings.noData)"
            }

            let valueAttrs: [NSAttributedString.Key: Any] = [
                .font: MenuItemFactory.monoFont,
                .foregroundColor: color
            ]
            result.append(NSAttributedString(string: valueText, attributes: valueAttrs))
        }

        return result
    }

    // MARK: - News

    func refreshNews() async {
        guard config.showNewsHeadlines else { return }
        newsItems = await newsService.fetchNews()
        updateNewsDisplay()
    }

    private func updateNewsDisplay() {
        guard let menu = statusItem?.menu else { return }

        let headlineItems = MenuTag.allHeadlines.compactMap { menu.item(withTag: $0) }

        guard config.showNewsHeadlines, !newsItems.isEmpty else {
            headlineItems.first?.title = Strings.noNewsAvailable
            headlineItems.first?.representedObject = nil
            headlineItems.first?.isHidden = false
            headlineItems.dropFirst().forEach { $0.isHidden = true }
            return
        }

        for (index, menuItem) in headlineItems.enumerated() {
            if index < newsItems.count {
                let newsItem = newsItems[index]
                menuItem.attributedTitle = makeNewsHeadlineAttributedTitle(newsItem)
                menuItem.representedObject = newsItem
                menuItem.isHidden = false
            } else {
                menuItem.isHidden = true
            }
        }
    }

    private func makeNewsHeadlineAttributedTitle(_ item: NewsItem) -> NSAttributedString {
        // Truncate headline to configured max length
        let maxLength = LayoutConfig.Headlines.maxLength
        let headline = item.headline.count > maxLength
            ? String(item.headline.prefix(maxLength - 3)) + "..."
            : item.headline

        // Top-from-source headlines use bold proportional font
        let font = item.isTopFromSource ? MenuItemFactory.headlineFontBold : MenuItemFactory.headlineFont

        if item.isTopFromSource {
            let highlightColor = ColorMapping.nsColor(from: config.highlightColor)
            let backgroundColor = highlightColor.withAlphaComponent(config.highlightOpacity)
            return .styled(headline, font: font, color: .labelColor, backgroundColor: backgroundColor)
        }

        return .styled(headline, font: font, color: .labelColor)
    }

    @objc private func openNewsArticle(_ sender: NSMenuItem) {
        guard let newsItem = sender.representedObject as? NewsItem,
              let url = newsItem.link else { return }
        urlOpener.openInBrowser(url)
    }

    // MARK: - UI Updates

    private func updateCountdown() {
        let elapsed = Date().timeIntervalSince(lastRefreshTime)
        let remaining = max(0, Int(TimeInterval(config.refreshInterval) - elapsed))

        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        let lastTime = formatter.string(from: lastRefreshTime)
        countdownMenuItem?.title = String(format: Strings.countdownFormat, lastTime, remaining)

        guard isMenuOpen else { return }
        statusItem?.menu?.update()
    }

    private func updateMarketStatus() {
        guard let marketStatusItem = statusItem?.menu?.item(withTag: MenuTag.marketStatus) else { return }

        let (localState, scheduleText, holidayName) = marketSchedule.getTodaySchedule()
        let state = yahooMarketState.map { MarketState(fromYahooState: $0) } ?? localState

        marketStatusItem.attributedTitle = makeMarketStatusAttributedTitle(state: state, scheduleText: scheduleText, holidayName: holidayName)
    }

    private func makeMarketStatusAttributedTitle(state: MarketState, scheduleText: String, holidayName: String?) -> NSAttributedString {
        let scheduleString = holidayName.map { "\(scheduleText) (\($0))" } ?? scheduleText

        let result = NSMutableAttributedString()
        result.append(Strings.nysePrefix, font: .systemFont(ofSize: Layout.headerFontSize, weight: .medium))
        result.append("\u{25CF} ", font: .systemFont(ofSize: Layout.headerFontSize - 2), color: state.color)
        result.append(state.rawValue, font: .systemFont(ofSize: Layout.headerFontSize, weight: .bold), color: state.color)
        result.append(" \u{2022} \(scheduleString)", font: .systemFont(ofSize: Layout.scheduleFontSize), color: .secondaryLabelColor)
        return result
    }

    private var currentMarketState: MarketState {
        if let state = yahooMarketState {
            return MarketState(fromYahooState: state)
        }
        // Fallback to time-based detection
        let session = StockQuote.currentTimeBasedSession()
        switch session {
        case .preMarket: return .preMarket
        case .regular: return .open
        case .afterHours: return .afterHours
        case .closed: return .closed
        }
    }

    private func updateMenuBarDisplay() {
        guard let button = statusItem?.button else { return }

        guard !config.watchlist.isEmpty else {
            button.title = Strings.emptyWatchlist
            return
        }

        let symbol: String
        let showExtendedHours: Bool

        switch currentMarketState {
        case .preMarket, .afterHours:
            symbol = config.menuBarAssetWhenClosed.symbol
            showExtendedHours = true
        case .closed:
            symbol = config.menuBarAssetWhenClosed.symbol
            showExtendedHours = false
        case .open:
            symbol = config.watchlist[currentIndex]
            showExtendedHours = false
        }

        guard let quote = quotes[symbol], !quote.isPlaceholder else {
            button.attributedTitle = .styled("\(symbol) --", font: MenuItemFactory.monoFontMedium)
            return
        }

        button.attributedTitle = TickerDisplayBuilder.menuBarTitle(for: quote, showExtendedHours: showExtendedHours)
    }

    // MARK: - Menu Item Management

    private func updateMenuItems() {
        guard let menu = statusItem?.menu else { return }

        removeOldTickerItems(from: menu)
        updateSortMenuCheckmarks(in: menu)
        insertTickerItems(into: menu)
    }

    private func removeOldTickerItems(from menu: NSMenu) {
        let index = TickerInsertIndex.start
        while index < menu.items.count, !menu.items[index].isSeparatorItem {
            menu.removeItem(at: index)
        }
    }

    private func updateSortMenuCheckmarks(in menu: NSMenu) {
        guard let sortItem = menu.items.first(where: { $0.title == "Sort By" }),
              let sortMenu = sortItem.submenu else { return }

        for item in sortMenu.items {
            guard let option = item.representedObject as? SortOption else { continue }
            item.state = (option == currentSortOption) ? .on : .off
        }
    }

    private func insertTickerItems(into menu: NSMenu) {
        var index = TickerInsertIndex.start
        for symbol in currentSortOption.sort(config.watchlist, using: quotes) {
            let menuItem = createTickerMenuItem(for: symbol)
            menu.insertItem(menuItem, at: index)
            index += 1
        }
    }

    private func createTickerMenuItem(for symbol: String) -> NSMenuItem {
        let menuItem = NSMenuItem(title: "", action: #selector(openYahooFinance(_:)), keyEquivalent: "")
        menuItem.target = self
        menuItem.representedObject = symbol

        guard let quote = quotes[symbol], !quote.isPlaceholder else {
            menuItem.attributedTitle = .styled("\(symbol) --", font: MenuItemFactory.monoFont)
            return menuItem
        }

        applyTickerStyle(to: menuItem, quote: quote, symbol: symbol)
        tickerMenuItems[symbol] = menuItem
        return menuItem
    }

    private func applyTickerStyle(to menuItem: NSMenuItem, quote: StockQuote, symbol: String) {
        let intensity = highlightIntensity[symbol] ?? 0.0
        let isPingHighlighted = intensity > Timing.highlightIntensityThreshold
        let pingBgColor: NSColor? = isPingHighlighted
            ? quote.highlightColor.withAlphaComponent(intensity * Timing.highlightAlphaMultiplier)
            : nil

        let isPersistentHighlighted = config.highlightedSymbols.contains(symbol)
        let persistentColor = ColorMapping.nsColor(from: config.highlightColor)
        let persistentOpacity = config.highlightOpacity

        let highlight = HighlightConfig(
            isPingHighlighted: isPingHighlighted,
            pingBackgroundColor: pingBgColor,
            isPersistentHighlighted: isPersistentHighlighted,
            persistentHighlightColor: persistentColor,
            persistentHighlightOpacity: persistentOpacity
        )
        menuItem.attributedTitle = TickerDisplayBuilder.tickerTitle(quote: quote, highlight: highlight)
    }

    // MARK: - Actions

    @objc private func openYahooFinance(_ sender: NSMenuItem) {
        guard let symbol = sender.representedObject as? String,
              let url = URL(string: "https://finance.yahoo.com/quote/\(symbol)") else { return }
        urlOpener.openInBrowser(url)
    }

    @objc private func editWatchlistHere() {
        editorWindowController = WatchlistEditorWindowController()
        editorWindowController?.showEditor(currentWatchlist: config.watchlist) { [weak self] newWatchlist in
            self?.saveAndReload(newWatchlist: newWatchlist)
        }
    }

    @objc private func editConfigJson() {
        configManager.openConfigFile()
    }

    private func saveAndReload(newWatchlist: [String]) {
        var newConfig = config
        newConfig.watchlist = newWatchlist
        newConfig.save()
        reloadConfig()
    }

    @objc private func reloadConfig() {
        config = configManager.load()
        currentSortOption = SortOption.from(configString: config.sortDirection)
        currentIndex = 0
        hasCompletedInitialLoad = false  // Reset so next refresh fetches all symbols
        stopTimers()
        startTimers()
        Task {
            await fetchMissingYTDPrices()
            await fetchMissingQuarterlyPrices()
            await fetchMissingHighestCloses()
            await fetchMissingForwardPERatios()
            await fetchMissingSwingLevels()
            await fetchMissingRSIValues()
            await fetchMissingEMAValues()
            await refreshAllQuotes()
        }
    }

    @objc private func resetConfigToDefault() {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Reset Config to Default"
        alert.informativeText = "This will reset all settings to their default values. This cannot be undone."
        alert.addButton(withTitle: "Reset")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        _ = configManager.saveDefault()
        reloadConfig()
    }

    @objc private func clearAllCaches() {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Clear Cache"
        alert.informativeText = "This will delete all cached price data and refetch from the API."
        alert.addButton(withTitle: "Clear")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        ytdPrices = [:]
        quarterlyPrices = [:]
        highestClosePrices = [:]
        forwardPEData = [:]
        currentForwardPEs = [:]
        swingLevelEntries = [:]
        rsiValues = [:]
        emaEntries = [:]

        Task {
            await ytdCacheManager.clearForNewYear()
            await quarterlyCacheManager.clearAllQuarters()
            await highestCloseCacheManager.clearForNewRange(highestCloseQuarterRange())
            await forwardPECacheManager.clearForNewRange(forwardPEQuarterRange())
            await swingLevelCacheManager.clearForNewRange(swingLevelQuarterRange())
            await rsiCacheManager.clearForDailyRefresh()
            await emaCacheManager.clearForDailyRefresh()
        }

        hasCompletedInitialLoad = false
        Task {
            await fetchMissingYTDPrices()
            await fetchMissingQuarterlyPrices()
            await fetchMissingHighestCloses()
            await fetchMissingForwardPERatios()
            await fetchMissingSwingLevels()
            await fetchMissingRSIValues()
            await fetchMissingEMAValues()
            await refreshAllQuotes()
        }
    }

    @objc private func sortOptionSelected(_ sender: NSMenuItem) {
        guard let option = sender.representedObject as? SortOption else { return }
        currentSortOption = option
        config.sortDirection = option.configString
        config.save()
        updateMenuItems()

        // Reopen menu to keep it visible after sort change
        DispatchQueue.main.async { [weak self] in
            self?.statusItem?.button?.performClick(nil)
        }
    }

    @objc private func closedMarketAssetSelected(_ sender: NSMenuItem) {
        guard let asset = sender.representedObject as? ClosedMarketAsset else { return }
        config.menuBarAssetWhenClosed = asset
        config.save()
        updateClosedMarketMenuCheckmarks()
        updateMenuBarDisplay()
        Task { await refreshAllQuotes() }
    }

    private func updateClosedMarketMenuCheckmarks() {
        guard let menu = statusItem?.menu,
              let closedMarketItem = menu.items.first(where: { $0.title == "Closed Market Display" }),
              let submenu = closedMarketItem.submenu else { return }

        for item in submenu.items {
            guard let asset = item.representedObject as? ClosedMarketAsset else { continue }
            item.state = (asset == config.menuBarAssetWhenClosed) ? .on : .off
        }
    }

    @objc private func showQuarterlyPanel() {
        if quarterlyWindowController == nil {
            quarterlyWindowController = QuarterlyPanelWindowController()
        }
        quarterlyWindowController?.showWindow(
            watchlist: config.watchlist,
            quotes: quotes,
            quarterPrices: quarterlyPrices,
            quarterInfos: quarterInfos,
            highlightedSymbols: Set(config.highlightedSymbols),
            highlightColor: config.highlightColor,
            highlightOpacity: config.highlightOpacity,
            highestClosePrices: highestClosePrices,
            forwardPEData: forwardPEData,
            currentForwardPEs: currentForwardPEs,
            swingLevelEntries: swingLevelEntries,
            rsiValues: rsiValues,
            emaEntries: emaEntries
        )
    }

    @objc private func showDebugWindow() {
        if debugWindowController == nil {
            debugWindowController = DebugWindowController()
        }
        debugWindowController?.showWindow()
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}

// MARK: - Market State Color

private extension MarketState {
    var color: NSColor {
        switch self {
        case .open: return .systemGreen
        case .preMarket, .afterHours: return .systemOrange
        case .closed: return .systemRed
        }
    }
}

// MARK: - NSMenuDelegate

extension MenuBarController: NSMenuDelegate {
    nonisolated func menuWillOpen(_ menu: NSMenu) {
        Task { @MainActor in
            isMenuOpen = true
            highlightIntensity.removeAll()
            updateMenuItems()
            updateNewsDisplay()
            startHighlightTimer()
            marqueeView?.startScrolling()
        }
    }

    nonisolated func menuDidClose(_ menu: NSMenu) {
        Task { @MainActor in
            isMenuOpen = false
            stopHighlightTimer()
            tickerMenuItems.removeAll()
            highlightIntensity.removeAll()
            marqueeView?.stopScrolling()
        }
    }
}

// MARK: - TimerManagerDelegate

extension MenuBarController: TimerManagerDelegate {
    func timerManagerCycleTick() {
        cycleToNextTicker()
    }

    func timerManagerRefreshTick() async {
        await refreshAllQuotes()
    }

    func timerManagerCountdownTick() {
        updateCountdown()
    }

    func timerManagerScheduleRefreshTick() {
        updateMarketStatus()
    }

    func timerManagerNewsRefreshTick() async {
        await refreshNews()
    }

    func timerManagerHighlightTick() {
        updateHighlights()
    }

    func timerManagerMidnightTick() {
        updateMarketStatus()
    }
}
