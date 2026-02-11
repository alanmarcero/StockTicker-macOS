import SwiftUI
import AppKit

// MARK: - URL Opener Protocol

protocol URLOpener {
    func openInBrowser(_ url: URL)
}

extension NSWorkspace: URLOpener {
    func openInBrowser(_ url: URL) { open(url) }
}

// MARK: - Color Helpers

private func priceChangeColor(_ change: Double, neutral: NSColor) -> NSColor {
    if abs(change) < TradingHours.nearZeroThreshold { return neutral }
    return change > 0 ? .systemGreen : .systemRed
}

private func colorFromString(_ name: String) -> NSColor {
    switch name.lowercased() {
    case "yellow": return .systemYellow
    case "orange": return .systemOrange
    case "red": return .systemRed
    case "pink": return .systemPink
    case "purple": return .systemPurple
    case "blue": return .systemBlue
    case "cyan": return .systemCyan
    case "teal": return .systemTeal
    case "green": return .systemGreen
    case "gray", "grey": return .systemGray
    case "brown": return .systemBrown
    default: return .systemYellow
    }
}

private extension StockQuote {
    var displayColor: NSColor { priceChangeColor(change, neutral: .secondaryLabelColor) }
    var highlightColor: NSColor { priceChangeColor(change, neutral: .systemGray) }
    var extendedHoursColor: NSColor { priceChangeColor(extendedHoursChangePercent ?? 0, neutral: .secondaryLabelColor) }
    var extendedHoursHighlightColor: NSColor { priceChangeColor(extendedHoursChangePercent ?? 0, neutral: .systemGray) }
    var ytdColor: NSColor {
        guard let pct = ytdChangePercent else { return .secondaryLabelColor }
        if abs(pct) < TradingHours.nearZeroThreshold { return .labelColor }
        return pct >= 0 ? .systemGreen : .systemRed
    }
}

// MARK: - Attributed String Helpers

private extension NSAttributedString {
    static func styled(
        _ string: String, font: NSFont, color: NSColor? = nil, backgroundColor: NSColor? = nil
    ) -> NSAttributedString {
        var attributes: [Key: Any] = [.font: font]
        if let color = color { attributes[.foregroundColor] = color }
        if let backgroundColor = backgroundColor { attributes[.backgroundColor] = backgroundColor }
        return NSAttributedString(string: string, attributes: attributes)
    }
}

private extension NSMutableAttributedString {
    func append(_ string: String, font: NSFont, color: NSColor? = nil) {
        append(.styled(string, font: font, color: color))
    }
}

// MARK: - Layout Constants (referencing centralized LayoutConfig)

private enum Layout {
    static let fontSize: CGFloat = LayoutConfig.Font.size
    static let headerFontSize: CGFloat = LayoutConfig.Font.headerSize
    static let scheduleFontSize: CGFloat = LayoutConfig.Font.scheduleSize

    static let tickerSymbolWidth = LayoutConfig.Ticker.symbolWidth
    static let tickerPriceWidth = LayoutConfig.Ticker.priceWidth
    static let tickerChangeWidth = LayoutConfig.Ticker.changeWidth
    static let tickerPercentWidth = LayoutConfig.Ticker.percentWidth
    static let tickerYTDWidth = LayoutConfig.Ticker.ytdWidth
    static let tickerExtendedHoursWidth = LayoutConfig.Ticker.extendedHoursWidth
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
    static let highlightFadeInterval: TimeInterval = 0.05
    static let countdownUpdateInterval: TimeInterval = 1.0
    static let scheduleRefreshInterval: TimeInterval = 4 * 60 * 60  // 4 hours
    static let highlightIntensityThreshold: CGFloat = 0.01
    static let highlightAlphaMultiplier: CGFloat = 0.6
}

// MARK: - Highlight Configuration

private struct HighlightConfig {
    let isPingHighlighted: Bool
    let pingBackgroundColor: NSColor?
    let isPersistentHighlighted: Bool
    let persistentHighlightColor: NSColor
    let persistentHighlightOpacity: Double

    func resolve(defaultColor: NSColor) -> (foreground: NSColor, background: NSColor?) {
        if isPingHighlighted {
            return (.white, pingBackgroundColor)
        }
        if isPersistentHighlighted {
            return (defaultColor, persistentHighlightColor.withAlphaComponent(persistentHighlightOpacity))
        }
        return (defaultColor, nil)
    }

    func withPingBackground(_ color: NSColor?) -> HighlightConfig {
        HighlightConfig(
            isPingHighlighted: isPingHighlighted,
            pingBackgroundColor: color,
            isPersistentHighlighted: isPersistentHighlighted,
            persistentHighlightColor: persistentHighlightColor,
            persistentHighlightOpacity: persistentHighlightOpacity
        )
    }

    func withPingDisabled() -> HighlightConfig {
        HighlightConfig(
            isPingHighlighted: false,
            pingBackgroundColor: nil,
            isPersistentHighlighted: isPersistentHighlighted,
            persistentHighlightColor: persistentHighlightColor,
            persistentHighlightOpacity: persistentHighlightOpacity
        )
    }
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

    private let stockService: StockServiceProtocol
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
    private var cycleTimer: Timer?
    private var refreshTimer: Timer?
    private var countdownTimer: Timer?
    private var scheduleRefreshTimer: Timer?
    private var highlightTimer: Timer?
    private var newsRefreshTimer: Timer?
    private var indexQuotes: [String: StockQuote] = [:]
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
    private let ytdCacheManager: YTDCacheManager
    private var ytdPrices: [String: Double] = [:]
    private let quarterlyCacheManager: QuarterlyCacheManager
    private var quarterlyPrices: [String: [String: Double]] = [:]
    private var quarterInfos: [QuarterInfo] = []
    private var quarterlyWindowController: QuarterlyPanelWindowController?

    // MARK: - Initialization

    init(
        stockService: StockServiceProtocol = StockService(),
        newsService: NewsServiceProtocol = NewsService(),
        configManager: WatchlistConfigManager = .shared,
        marketSchedule: MarketSchedule = .shared,
        urlOpener: URLOpener = NSWorkspace.shared,
        ytdCacheManager: YTDCacheManager = YTDCacheManager(),
        quarterlyCacheManager: QuarterlyCacheManager = QuarterlyCacheManager()
    ) {
        self.stockService = stockService
        self.newsService = newsService
        self.configManager = configManager
        self.marketSchedule = marketSchedule
        self.urlOpener = urlOpener
        self.ytdCacheManager = ytdCacheManager
        self.quarterlyCacheManager = quarterlyCacheManager

        let loadedConfig = configManager.load()
        self.config = loadedConfig
        self.currentSortOption = SortOption.from(configString: loadedConfig.sortDirection)

        super.init()

        setupStatusItem()
        startTimers()
        Task {
            await loadYTDCache()
            await loadQuarterlyCache()
            await refreshAllQuotes()
            await refreshNews()
        }
    }

    // MARK: - YTD Cache Management

    private func loadYTDCache() async {
        await ytdCacheManager.load()

        // Check if we need to clear cache for new year
        if await ytdCacheManager.needsYearRollover() {
            await ytdCacheManager.clearForNewYear()
        }

        await fetchMissingYTDPrices()
    }

    private func fetchMissingYTDPrices() async {
        let allSymbols = config.watchlist + config.indexSymbols.map { $0.symbol }
        let missingSymbols = await ytdCacheManager.getMissingSymbols(from: allSymbols)

        guard !missingSymbols.isEmpty else {
            ytdPrices = await ytdCacheManager.getAllPrices()
            return
        }

        let fetched = await stockService.batchFetchYTDPrices(symbols: missingSymbols)
        for (symbol, price) in fetched {
            await ytdCacheManager.setStartPrice(for: symbol, price: price)
        }
        await ytdCacheManager.save()

        // Load all YTD prices into memory
        ytdPrices = await ytdCacheManager.getAllPrices()
    }

    // MARK: - Quarterly Cache Management

    private func loadQuarterlyCache() async {
        await quarterlyCacheManager.load()
        quarterInfos = QuarterCalculation.lastNCompletedQuarters(from: Date(), count: 12)
        await fetchMissingQuarterlyPrices()
    }

    private func fetchMissingQuarterlyPrices() async {
        quarterInfos = QuarterCalculation.lastNCompletedQuarters(from: Date(), count: 12)

        for qi in quarterInfos {
            let missingSymbols = await quarterlyCacheManager.getMissingSymbols(
                for: qi.identifier, from: config.watchlist
            )
            guard !missingSymbols.isEmpty else { continue }

            let (period1, period2) = QuarterCalculation.quarterEndDateRange(year: qi.year, quarter: qi.quarter)
            let fetched = await stockService.batchFetchQuarterEndPrices(
                symbols: missingSymbols, period1: period1, period2: period2
            )

            guard !fetched.isEmpty else { continue }
            await quarterlyCacheManager.setPrices(quarter: qi.identifier, prices: fetched)
            await quarterlyCacheManager.save()
        }

        // Prune quarters older than the active 8
        let activeIds = quarterInfos.map { $0.identifier }
        await quarterlyCacheManager.pruneOldQuarters(keeping: activeIds)
        await quarterlyCacheManager.save()

        quarterlyPrices = await quarterlyCacheManager.getAllQuarterPrices()
    }

    private func attachYTDPricesToQuotes() {
        // Attach YTD start prices to watchlist quotes
        for (symbol, quote) in quotes {
            if let ytdPrice = ytdPrices[symbol] {
                quotes[symbol] = quote.withYTDStartPrice(ytdPrice)
            }
        }

        // Attach YTD start prices to index quotes
        for (symbol, quote) in indexQuotes {
            if let ytdPrice = ytdPrices[symbol] {
                indexQuotes[symbol] = quote.withYTDStartPrice(ytdPrice)
            }
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

        let quarterlyItem = MenuItemFactory.action(title: "Quarterly Performance...", action: #selector(showQuarterlyPanel), target: self, keyEquivalent: "q")
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
            MenuItemFactory.action(title: "Reset Config to Default", action: #selector(resetConfigToDefault), target: self)
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
        cycleTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(config.menuBarRotationInterval), repeats: true) { [weak self] _ in
            Task { @MainActor in self?.cycleToNextTicker() }
        }

        refreshTimer = createCommonModeTimer(interval: TimeInterval(config.refreshInterval)) { [weak self] in
            Task { @MainActor in await self?.refreshAllQuotes() }
        }

        updateCountdown()
        countdownTimer = createCommonModeTimer(interval: Timing.countdownUpdateInterval) { [weak self] in
            DispatchQueue.main.async { self?.updateCountdown() }
        }

        scheduleRefreshTimer = Timer.scheduledTimer(withTimeInterval: Timing.scheduleRefreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.updateMarketStatus() }
        }

        // News refresh timer (separate from stock refresh, typically every 5 minutes)
        if config.showNewsHeadlines {
            newsRefreshTimer = createCommonModeTimer(interval: TimeInterval(config.newsRefreshInterval)) { [weak self] in
                Task { @MainActor in await self?.refreshNews() }
            }
        }

        scheduleMidnightRefresh()
    }

    private func createCommonModeTimer(interval: TimeInterval, block: @escaping () -> Void) -> Timer {
        let timer = Timer(timeInterval: interval, repeats: true) { _ in block() }
        RunLoop.main.add(timer, forMode: .common)
        return timer
    }

    private func stopTimers() {
        [cycleTimer, refreshTimer, countdownTimer, scheduleRefreshTimer, newsRefreshTimer].forEach { $0?.invalidate() }
        cycleTimer = nil
        refreshTimer = nil
        countdownTimer = nil
        scheduleRefreshTimer = nil
        newsRefreshTimer = nil
        marqueeView?.stopScrolling()
    }

    private func scheduleMidnightRefresh() {
        let calendar = Calendar.current
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()),
              let midnight = calendar.date(bySettingHour: 0, minute: 0, second: 5, of: tomorrow) else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + midnight.timeIntervalSinceNow) { [weak self] in
            Task { @MainActor in
                self?.updateMarketStatus()
                self?.scheduleMidnightRefresh()
            }
        }
    }

    // MARK: - Highlight Timer

    private func startHighlightTimer() {
        highlightTimer?.invalidate()
        highlightTimer = createCommonModeTimer(interval: Timing.highlightFadeInterval) { [weak self] in
            DispatchQueue.main.async { self?.updateHighlights() }
        }
    }

    private func stopHighlightTimer() {
        highlightTimer?.invalidate()
        highlightTimer = nil
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

    private func ensureClosedMarketSymbol(in symbols: [String]) -> [String] {
        let closedMarketSymbol = config.menuBarAssetWhenClosed.symbol
        guard !symbols.contains(closedMarketSymbol) else { return symbols }
        return symbols + [closedMarketSymbol]
    }

    func refreshAllQuotes() async {
        let scheduleInfo = marketSchedule.getTodaySchedule()
        let isWeekend = scheduleInfo.schedule.contains("Weekend")

        let fetchedSymbols: Set<String>

        if !hasCompletedInitialLoad {
            fetchedSymbols = await fetchInitialLoad(isWeekend: isWeekend)
        } else if scheduleInfo.state == .closed || isWeekend {
            fetchedSymbols = await fetchClosedMarket()
        } else if scheduleInfo.state == .open {
            fetchedSymbols = await fetchRegularSession()
        } else {
            fetchedSymbols = await fetchExtendedHours()
        }

        self.lastRefreshTime = Date()
        attachYTDPricesToQuotes()
        highlightFetchedSymbols(fetchedSymbols)

        quarterlyWindowController?.refresh(quotes: quotes, quarterPrices: quarterlyPrices)

        updateMenuBarDisplay()
        updateMenuItems()
        updateMarketStatus()
        updateCountdown()
        updateIndexLine()
    }

    private func fetchInitialLoad(isWeekend: Bool) async -> Set<String> {
        let allSymbols = ensureClosedMarketSymbol(in: config.watchlist)
        let indexSymbols = config.indexSymbols.map { $0.symbol }
        let alwaysOpenSymbols = config.alwaysOpenMarkets.map { $0.symbol }

        async let fetchedQuotes = stockService.fetchQuotes(symbols: allSymbols)
        async let fetchedIndexQuotes = stockService.fetchQuotes(symbols: indexSymbols)
        async let fetchedAlwaysOpen = stockService.fetchQuotes(symbols: alwaysOpenSymbols)
        async let fetchedMarketState = stockService.fetchMarketState(symbol: "SPY")

        self.quotes = await fetchedQuotes
        self.indexQuotes = await fetchedIndexQuotes
        self.indexQuotes.merge(await fetchedAlwaysOpen) { _, new in new }

        // On weekends, force CLOSED regardless of what API returns
        // (API may still report POST from Friday's after-hours)
        self.yahooMarketState = isWeekend ? "CLOSED" : await fetchedMarketState

        hasCompletedInitialLoad = true
        return Set(allSymbols)
    }

    private func fetchClosedMarket() async -> Set<String> {
        let cryptoSymbol = config.menuBarAssetWhenClosed.symbol
        let alwaysOpenSymbols = config.alwaysOpenMarkets.map { $0.symbol }
        let symbolsToFetch = Set([cryptoSymbol] + alwaysOpenSymbols)

        let fetchedQuotes = await stockService.fetchQuotes(symbols: Array(symbolsToFetch))
        self.quotes.merge(fetchedQuotes) { _, new in new }
        self.indexQuotes.merge(fetchedQuotes) { _, new in new }
        self.yahooMarketState = "CLOSED"

        return symbolsToFetch
    }

    private func fetchRegularSession() async -> Set<String> {
        let allSymbols = ensureClosedMarketSymbol(in: config.watchlist)
        let indexSymbols = config.indexSymbols.map { $0.symbol }

        async let fetchedQuotes = stockService.fetchQuotes(symbols: allSymbols)
        async let fetchedIndexQuotes = stockService.fetchQuotes(symbols: indexSymbols)
        async let fetchedMarketState = stockService.fetchMarketState(symbol: "SPY")

        self.quotes = await fetchedQuotes
        self.indexQuotes = await fetchedIndexQuotes
        self.yahooMarketState = await fetchedMarketState

        return Set(allSymbols)
    }

    private func fetchExtendedHours() async -> Set<String> {
        let allSymbols = ensureClosedMarketSymbol(in: config.watchlist)
        let alwaysOpenSymbols = config.alwaysOpenMarkets.map { $0.symbol }

        async let fetchedQuotes = stockService.fetchQuotes(symbols: allSymbols)
        async let fetchedAlwaysOpen = stockService.fetchQuotes(symbols: alwaysOpenSymbols)
        async let fetchedMarketState = stockService.fetchMarketState(symbol: "SPY")

        self.quotes = await fetchedQuotes
        self.indexQuotes = await fetchedAlwaysOpen
        self.yahooMarketState = await fetchedMarketState

        return Set(allSymbols)
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
            // Add separator between indexes
            if index > 0 {
                result.append(NSAttributedString(string: MarqueeConfig.separator, attributes: separatorAttrs))
            }

            // Get quote and determine color
            let quote = indexQuotes[indexSymbol.symbol]
            let color: NSColor
            if let validQuote = quote, !validQuote.isPlaceholder {
                color = validQuote.displayColor
            } else {
                color = .secondaryLabelColor
            }

            // Build text for this index: bold name, regular weight values
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

        // Update each headline slot
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
            let highlightColor = colorFromString(config.highlightColor)
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

        let state = currentMarketState

        switch state {
        case .preMarket, .afterHours:
            // Show selected closed market asset with extended hours data if available
            let symbol = config.menuBarAssetWhenClosed.symbol
            button.attributedTitle = makeMenuBarAttributedTitle(for: symbol, showExtendedHours: true)
        case .closed:
            // Market truly closed - show selected asset without extended hours
            let symbol = config.menuBarAssetWhenClosed.symbol
            button.attributedTitle = makeMenuBarAttributedTitle(for: symbol)
        case .open:
            // Cycle through watchlist during regular hours
            let symbol = config.watchlist[currentIndex]
            button.attributedTitle = makeMenuBarAttributedTitle(for: symbol)
        }
    }

    private func makeMenuBarAttributedTitle(for symbol: String, showExtendedHours: Bool = false) -> NSAttributedString {
        guard let quote = quotes[symbol], !quote.isPlaceholder else {
            return .styled("\(symbol) --", font: MenuItemFactory.monoFontMedium)
        }

        let result = NSMutableAttributedString()
        result.append("\(quote.symbol) ", font: MenuItemFactory.monoFontMedium)

        if showExtendedHours, let extPercent = quote.formattedExtendedHoursChangePercent {
            // Show extended hours change (pre-market or after-hours)
            let color = quote.extendedHoursIsPositive ? NSColor.systemGreen : NSColor.systemRed
            result.append(extPercent, font: MenuItemFactory.monoFontMedium, color: color)
            result.append(" (\(quote.extendedHoursLabel))", font: MenuItemFactory.monoFontMedium, color: .white)
        } else {
            result.append(quote.formattedChangePercent, font: MenuItemFactory.monoFontMedium, color: quote.displayColor)
        }

        return result
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
        let persistentColor = colorFromString(config.highlightColor)
        let persistentOpacity = config.highlightOpacity

        let highlight = HighlightConfig(
            isPingHighlighted: isPingHighlighted,
            pingBackgroundColor: pingBgColor,
            isPersistentHighlighted: isPersistentHighlighted,
            persistentHighlightColor: persistentColor,
            persistentHighlightOpacity: persistentOpacity
        )
        menuItem.attributedTitle = buildTickerAttributedTitle(quote: quote, highlight: highlight)
    }

    private func buildTickerAttributedTitle(quote: StockQuote, highlight: HighlightConfig) -> NSAttributedString {
        let result = NSMutableAttributedString()

        // Main price line
        let symbolStr = quote.symbol.padding(toLength: Layout.tickerSymbolWidth, withPad: " ", startingAt: 0)
        let priceStr = quote.formattedPrice.padding(toLength: Layout.tickerPriceWidth, withPad: " ", startingAt: 0)
        let changeStr = quote.formattedChange.padding(toLength: Layout.tickerChangeWidth, withPad: " ", startingAt: 0)
        let percentStr = quote.formattedChangePercent.padding(
            toLength: Layout.tickerPercentWidth, withPad: " ", startingAt: 0
        )

        let mainHighlight = quote.isInExtendedHoursPeriod
            ? highlight.withPingDisabled()
            : highlight
        let (mainColor, mainBgColor) = mainHighlight.resolve(defaultColor: quote.displayColor)

        result.append(.styled("\(symbolStr) \(priceStr) \(changeStr) \(percentStr)",
                              font: MenuItemFactory.monoFont, color: mainColor, backgroundColor: mainBgColor))

        // YTD display
        appendYTDSection(to: result, quote: quote, highlight: highlight)

        // Extended hours display
        appendExtendedHoursSection(to: result, quote: quote, highlight: highlight)

        return result
    }

    private func appendYTDSection(to result: NSMutableAttributedString, quote: StockQuote, highlight: HighlightConfig) {
        guard let ytdPercent = quote.formattedYTDChangePercent else { return }
        let ytdContent = "YTD: \(ytdPercent)"
        let paddedContent = ytdContent.count >= Layout.tickerYTDWidth
            ? ytdContent
            : ytdContent.padding(toLength: Layout.tickerYTDWidth, withPad: " ", startingAt: 0)
        let (ytdColor, ytdBgColor) = highlight.resolve(defaultColor: quote.ytdColor)
        result.append(.styled("  \(paddedContent)",
                              font: MenuItemFactory.monoFont, color: ytdColor, backgroundColor: ytdBgColor))
    }

    private func appendExtendedHoursSection(
        to result: NSMutableAttributedString, quote: StockQuote, highlight: HighlightConfig
    ) {
        guard quote.isInExtendedHoursPeriod, let periodLabel = quote.extendedHoursPeriodLabel else { return }

        if quote.formattedYTDChangePercent == nil {
            let emptyPadding = String(repeating: " ", count: Layout.tickerYTDWidth + 2)
            result.append(.styled(emptyPadding, font: MenuItemFactory.monoFont))
        }

        if quote.shouldShowExtendedHours, let extPercent = quote.formattedExtendedHoursChangePercent {
            let extPingBgColor = quote.extendedHoursHighlightColor.withAlphaComponent(
                highlight.pingBackgroundColor?.alphaComponent ?? 0
            )
            let extHighlight = highlight.withPingBackground(extPingBgColor)
            let (extColor, extBgColor) = extHighlight.resolve(defaultColor: quote.extendedHoursColor)
            result.append(.styled("  \(periodLabel): \(extPercent)",
                                  font: MenuItemFactory.monoFont, color: extColor, backgroundColor: extBgColor))
        } else {
            let (extColor, extBgColor) = highlight.withPingDisabled().resolve(defaultColor: .secondaryLabelColor)
            result.append(.styled("  \(periodLabel): --",
                                  font: MenuItemFactory.monoFont, color: extColor, backgroundColor: extBgColor))
        }
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
            highlightOpacity: config.highlightOpacity
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
