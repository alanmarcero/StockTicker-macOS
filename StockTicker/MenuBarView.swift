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
    static let universeRefreshCadence = 2  // Every 2nd refresh cycle (~60s at 30s interval)
    static let cacheRetryCadence = 4      // Retry missing cache entries every 4th cycle (~60s)
}

// MARK: - Menu Bar Controller

@MainActor
class MenuBarController: NSObject, ObservableObject {
    // MARK: - Dependencies

    let stockService: StockServiceProtocol
    private let newsService: NewsServiceProtocol
    private let scannerService: ScannerServiceProtocol
    let configManager: WatchlistConfigManager
    let marketSchedule: MarketSchedule
    let urlOpener: URLOpener
    let dateProvider: DateProvider

    // MARK: - Published State

    @Published var quotes: [String: StockQuote] = [:]
    @Published var currentIndex: Int = 0
    @Published var config: WatchlistConfig
    @Published var currentSortOption: SortOption
    var currentFilter: TickerFilter { TickerFilter(rawValue: config.filterGreenFields) }
    @Published var currentWatchlistSource: WatchlistSource = .allSources
    var effectiveWatchlist: [String] { currentWatchlistSource.symbols(personalWatchlist: config.watchlist) }
    @Published var yahooMarketState: String?

    // MARK: - Popover State

    @Published var newsItems: [NewsItem] = []
    @Published var highlightIntensity: [String: CGFloat] = [:]
    @Published var countdownText: String = ""
    @Published var marketStatusState: MarketState = .closed
    @Published var marketScheduleText: String = ""
    @Published var marketHolidayName: String?
    var marqueeView: MarqueeView?
    var isPopoverOpen = false

    // MARK: - Private State

    private var statusItem: NSStatusItem?
    private let timerManager = TimerManager()
    var indexQuotes: [String: StockQuote] = [:]
    private var editorWindowController: WatchlistEditorWindowController?
    private var debugWindowController: DebugWindowController?
    private var lastRefreshTime: Date
    private var popover: NSPopover?
    private var eventMonitor: Any?
    private var hasCompletedInitialLoad = false
    let ytdCacheManager: YTDCacheManager
    var ytdPrices: [String: Double] = [:]
    let quarterlyCacheManager: QuarterlyCacheManager
    var quarterlyPrices: [String: [String: Double]] = [:]
    var quarterInfos: [QuarterInfo] = []
    var marketCaps: [String: Double] = [:]
    let highestCloseCacheManager: HighestCloseCacheManager
    var highestClosePrices: [String: Double] = [:]
    var lowestClosePrices: [String: Double] = [:]
    let forwardPECacheManager: ForwardPECacheManager
    var forwardPEData: [String: [String: Double]] = [:]
    var currentForwardPEs: [String: Double] = [:]
    let swingLevelCacheManager: SwingLevelCacheManager
    var swingLevelEntries: [String: SwingLevelCacheEntry] = [:]
    let rsiCacheManager: RSICacheManager
    var rsiValues: [String: Double] = [:]
    let emaCacheManager: EMACacheManager
    var emaEntries: [String: EMACacheEntry] = [:]
    let vixSpikeCacheManager: VIXSpikeCacheManager
    var vixSpikes: [VIXSpike] = []
    var vixSpikePrices: [String: [String: Double]] = [:]
    var universeQuotes: [String: StockQuote] = [:]
    var universeMarketCaps: [String: Double] = [:]
    var universeForwardPEs: [String: Double] = [:]
    var isFetchingDailyAnalysis = false
    private var refreshCycleCount = 0
    private var universeFinnhubBatchIndex = 0
    private var universeYahooBatchIndex = 0
    let backfillScheduler = BackfillScheduler()
    var scannerEMAData: ScannerEMAData?
    private var quarterlyWindowController: QuarterlyPanelWindowController?

    // MARK: - Initialization

    init(
        stockService: StockServiceProtocol = StockService(),
        newsService: NewsServiceProtocol = NewsService(),
        scannerService: ScannerServiceProtocol = ScannerService(),
        configManager: WatchlistConfigManager = .shared,
        marketSchedule: MarketSchedule = .shared,
        urlOpener: URLOpener = NSWorkspace.shared,
        dateProvider: DateProvider = SystemDateProvider(),
        ytdCacheManager: YTDCacheManager = YTDCacheManager(),
        quarterlyCacheManager: QuarterlyCacheManager = QuarterlyCacheManager(),
        highestCloseCacheManager: HighestCloseCacheManager = HighestCloseCacheManager(),
        forwardPECacheManager: ForwardPECacheManager = ForwardPECacheManager(),
        swingLevelCacheManager: SwingLevelCacheManager = SwingLevelCacheManager(),
        rsiCacheManager: RSICacheManager = RSICacheManager(),
        emaCacheManager: EMACacheManager = EMACacheManager(),
        vixSpikeCacheManager: VIXSpikeCacheManager = VIXSpikeCacheManager()
    ) {
        self.stockService = stockService
        self.newsService = newsService
        self.scannerService = scannerService
        self.configManager = configManager
        self.marketSchedule = marketSchedule
        self.urlOpener = urlOpener
        self.dateProvider = dateProvider
        self.ytdCacheManager = ytdCacheManager
        self.quarterlyCacheManager = quarterlyCacheManager
        self.highestCloseCacheManager = highestCloseCacheManager
        self.forwardPECacheManager = forwardPECacheManager
        self.swingLevelCacheManager = swingLevelCacheManager
        self.rsiCacheManager = rsiCacheManager
        self.emaCacheManager = emaCacheManager
        self.vixSpikeCacheManager = vixSpikeCacheManager
        self.lastRefreshTime = dateProvider.now()

        let loadedConfig = configManager.load(backfillDefaults: true)
        self.config = loadedConfig
        self.currentSortOption = SortOption.from(configString: loadedConfig.sortDirection)

        super.init()

        timerManager.delegate = self
        setupStatusItem()
        startTimers()
        Task {
            await stockService.updateFinnhubApiKey(config.finnhubApiKey)
            await loadYTDCache()
            await loadQuarterlyCache()
            await loadHighestCloseCache()
            await loadLowestCloseCache()
            await loadForwardPECache()
            await loadSwingLevelCache()
            await loadRSICache()
            await loadEMACache()
            await loadVIXSpikeCache()
            await refreshAllQuotes()
            await refreshNews()
            await startBackfill()
        }
    }

    // MARK: - Setup

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem?.button else { return }
        button.title = Strings.loading
        button.font = MenuItemFactory.monoFontMedium
        button.action = #selector(togglePopover)
        button.target = self

        let marqueeFrame = NSRect(x: 0, y: 0, width: MarqueeConfig.viewWidth, height: MarqueeConfig.viewHeight)
        marqueeView = MarqueeView(frame: marqueeFrame)
    }

    // MARK: - Popover Management

    @objc private func togglePopover() {
        if popover?.isShown == true {
            closePopover()
        } else {
            showPopover()
        }
    }

    private func showPopover() {
        guard let button = statusItem?.button else { return }

        let contentView = PopoverContentView(controller: self)
        let hostingController = NSHostingController(rootView: contentView)
        hostingController.view.frame = NSRect(
            x: 0, y: 0,
            width: LayoutConfig.Popover.width,
            height: LayoutConfig.Popover.height
        )

        let pop = NSPopover()
        pop.contentSize = NSSize(width: LayoutConfig.Popover.width, height: LayoutConfig.Popover.height)
        pop.behavior = .transient
        pop.contentViewController = hostingController
        pop.delegate = self
        pop.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        self.popover = pop

        NSApp.activate(ignoringOtherApps: true)
        isPopoverOpen = true
        highlightIntensity.removeAll()
        startHighlightTimer()
        marqueeView?.startScrolling()

        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handlePopoverKeyEvent(event)
        }
    }

    func closePopover() {
        popover?.performClose(nil)
        cleanupPopover()
    }

    private func cleanupPopover() {
        isPopoverOpen = false
        stopHighlightTimer()
        highlightIntensity.removeAll()
        marqueeView?.stopScrolling()
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    private func handlePopoverKeyEvent(_ event: NSEvent) -> NSEvent? {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        // Cmd+Q → Quit
        if flags == .command, event.charactersIgnoringModifiers == "q" {
            quitApp()
            return nil
        }
        // Cmd+, → Edit Watchlist
        if flags == .command, event.charactersIgnoringModifiers == "," {
            editWatchlistHere()
            return nil
        }
        // Cmd+Opt+Q → Extra Stats
        if flags == [.command, .option], event.charactersIgnoringModifiers == "q" {
            showQuarterlyPanel()
            return nil
        }
        // Cmd+Opt+D → API Errors
        if flags == [.command, .option], event.charactersIgnoringModifiers == "d" {
            showDebugWindow()
            return nil
        }
        // Escape → Close popover
        if event.keyCode == 53 {
            closePopover()
            return nil
        }
        return event
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
        var changed = false
        for symbol in highlightIntensity.keys {
            guard let intensity = highlightIntensity[symbol], intensity > 0 else { continue }
            highlightIntensity[symbol] = max(0, intensity - Timing.highlightFadeStep)
            changed = true
        }
        if changed {
            objectWillChange.send()
        }
        updateCountdown()
    }

    // MARK: - Data Refresh

    func refreshAllQuotes() async {
        let loadedConfig = configManager.load()
        if loadedConfig != config {
            reloadConfig()
            return
        }

        let scheduleInfo = marketSchedule.getTodaySchedule()
        let isWeekend = scheduleInfo.schedule.contains("Weekend")
        let isInitialLoad = !hasCompletedInitialLoad

        let watchlist = effectiveWatchlist
        let closedMarketSymbol = config.menuBarAssetWhenClosed.symbol
        let indexSymbols = config.indexSymbols.map { $0.symbol }
        let alwaysOpenSymbols = config.alwaysOpenMarkets.map { $0.symbol }

        let result: FetchResult
        if isInitialLoad {
            result = await QuoteFetchCoordinator.fetchInitialLoad(
                service: stockService, watchlist: watchlist,
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
                service: stockService, watchlist: watchlist,
                indexSymbols: indexSymbols, closedMarketSymbol: closedMarketSymbol
            )
        } else {
            result = await QuoteFetchCoordinator.fetchExtendedHours(
                service: stockService, watchlist: watchlist,
                alwaysOpenSymbols: alwaysOpenSymbols, closedMarketSymbol: closedMarketSymbol
            )
        }

        if result.shouldMergeQuotes {
            self.quotes.mergeKeepingNew(result.quotes)
            self.indexQuotes.mergeKeepingNew(result.indexQuotes)
        } else {
            self.quotes = result.quotes
            self.indexQuotes = result.indexQuotes
        }
        self.yahooMarketState = result.yahooMarketState
        if currentSortOption.isExtendedHoursSort {
            let state = MarketState(fromYahooState: result.yahooMarketState)
            if state == .open {
                currentSortOption = .percentDesc
                config.sortDirection = currentSortOption.configString
                config.save()
            }
        }
        if result.isInitialLoadComplete { hasCompletedInitialLoad = true }

        self.lastRefreshTime = dateProvider.now()
        refreshCycleCount += 1
        attachYTDPricesToQuotes()

        if isInitialLoad || scheduleInfo.state == .open {
            let (fetchedCaps, fetchedPEs) = await stockService.fetchQuoteFields(symbols: watchlist)
            marketCaps.mergeKeepingNew(fetchedCaps)
            currentForwardPEs.mergeKeepingNew(fetchedPEs)
        }
        attachMarketCapsToQuotes()
        await refreshDailyAnalysisIfNeeded()
        await refreshVIXSpikesIfNeeded()
        if refreshCycleCount % Timing.cacheRetryCadence == 0 {
            let backfillRunning = await backfillScheduler.isRunning
            if !backfillRunning {
                await retryMissingCacheEntries()
            }
        }
        attachHighestClosesToQuotes()
        attachLowestClosesToQuotes()
        highlightFetchedSymbols(result.fetchedSymbols)

        await refreshUniverseQuotesIfNeeded(isInitialLoad: isInitialLoad)

        quarterlyWindowController?.refresh(data: makeQuarterlyPanelData(), personalWatchlist: Set(config.watchlist))

        updateMenuBarDisplay()
        updateMarketStatus()
        updateCountdown()
        updateIndexLine()
    }

    private func highlightFetchedSymbols(_ fetchedSymbols: Set<String>) {
        guard isPopoverOpen, !fetchedSymbols.isEmpty else { return }
        effectiveWatchlist.filter { fetchedSymbols.contains($0) }
            .forEach { highlightIntensity[$0] = 1.0 }
        marqueeView?.triggerPing()
    }

    // MARK: - Universe Quote Fetching

    private var universeOnlySymbols: [String] {
        let allSourceSet = Set(WatchlistSource.allSymbols(personalWatchlist: config.watchlist))
        return config.universe.filter { !allSourceSet.contains($0) }
    }

    private var isExtraStatsVisible: Bool {
        quarterlyWindowController?.isWindowVisible ?? false
    }

    private func refreshUniverseQuotesIfNeeded(isInitialLoad: Bool) async {
        guard !config.universe.isEmpty else { return }
        let symbols = universeOnlySymbols
        guard !symbols.isEmpty else { return }

        let shouldFetch = isInitialLoad
            || refreshCycleCount % Timing.universeRefreshCadence == 0

        guard shouldFetch else { return }

        // Partition: equities → Finnhub, indices/crypto → Yahoo
        let (finnhubSymbols, yahooSymbols) = SymbolRouting.partition(symbols, finnhubApiKey: config.finnhubApiKey)

        // Stagger Finnhub: max N per cycle to stay under 60 req/min
        let maxPerCycle = ThrottledTaskGroup.FinnhubQuote.maxSymbolsPerCycle
        let batch: [String]
        if finnhubSymbols.count <= maxPerCycle {
            batch = finnhubSymbols
        } else {
            let sorted = finnhubSymbols.sorted()
            let offset = (universeFinnhubBatchIndex * maxPerCycle) % sorted.count
            let end = min(offset + maxPerCycle, sorted.count)
            batch = Array(sorted[offset..<end])
            universeFinnhubBatchIndex += 1
        }

        // Overflow equity symbols fall back to Yahoo this cycle, batched
        let batchSet = Set(batch)
        let overflow = finnhubSymbols.filter { !batchSet.contains($0) }
        let allYahoo = yahooSymbols + overflow

        let yahooMaxPerCycle = ThrottledTaskGroup.YahooQuote.maxSymbolsPerCycle
        let yahooBatch: [String]
        if allYahoo.count <= yahooMaxPerCycle {
            yahooBatch = allYahoo
        } else {
            let sorted = allYahoo.sorted()
            let offset = (universeYahooBatchIndex * yahooMaxPerCycle) % sorted.count
            let end = min(offset + yahooMaxPerCycle, sorted.count)
            yahooBatch = Array(sorted[offset..<end])
            universeYahooBatchIndex += 1
        }

        // Fetch in parallel: Finnhub at full speed, Yahoo throttled
        async let fQuotes = stockService.fetchFinnhubQuotes(symbols: batch)
        async let yQuotes = stockService.fetchQuotes(
            symbols: yahooBatch,
            maxConcurrency: ThrottledTaskGroup.YahooQuote.maxConcurrency,
            delay: ThrottledTaskGroup.YahooQuote.delayNanoseconds
        )
        var fetched = await yQuotes
        fetched.mergeKeepingNew(await fQuotes)

        universeQuotes.mergeKeepingNew(fetched)

        let (fetchedCaps, fetchedPEs) = await stockService.fetchQuoteFields(symbols: symbols)
        universeMarketCaps.mergeKeepingNew(fetchedCaps)
        universeForwardPEs.mergeKeepingNew(fetchedPEs)
    }

    func mergedQuotes() -> [String: StockQuote] {
        var combined = quotes
        combined.mergeKeepingExisting(universeQuotes)
        return combined
    }

    private func mergedForwardPEs() -> [String: Double] {
        var combined = currentForwardPEs
        combined.mergeKeepingExisting(universeForwardPEs)
        return combined
    }

    private func cycleToNextTicker() {
        let watchlist = effectiveWatchlist
        guard !watchlist.isEmpty else { return }

        // Only cycle during regular market hours
        if currentMarketState == .open {
            currentIndex = (currentIndex + 1) % watchlist.count
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
    }

    // MARK: - UI Updates

    private func updateCountdown() {
        let elapsed = dateProvider.now().timeIntervalSince(lastRefreshTime)
        let remaining = max(0, Int(TimeInterval(config.refreshInterval) - elapsed))

        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        let lastTime = formatter.string(from: lastRefreshTime)
        countdownText = String(format: Strings.countdownFormat, lastTime, remaining)
    }

    private func updateMarketStatus() {
        let (localState, scheduleText, holidayName) = marketSchedule.getTodaySchedule()
        let state = yahooMarketState.map { MarketState(fromYahooState: $0) } ?? localState

        marketStatusState = state
        marketScheduleText = scheduleText
        marketHolidayName = holidayName
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

        let watchlist = effectiveWatchlist
        guard !watchlist.isEmpty else {
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
            let safeIndex = currentIndex % watchlist.count
            symbol = watchlist[safeIndex]
            showExtendedHours = false
        }

        guard let quote = quotes[symbol], !quote.isPlaceholder else {
            button.attributedTitle = .styled("\(symbol) --", font: MenuItemFactory.monoFontMedium)
            return
        }

        button.attributedTitle = TickerDisplayBuilder.menuBarTitle(for: quote, showExtendedHours: showExtendedHours)
    }

    // MARK: - Sorted & Filtered Tickers

    var sortedFilteredSymbols: [String] {
        let filtered = currentFilter.filter(effectiveWatchlist, using: quotes)
        return currentSortOption.sort(filtered, using: quotes)
    }

    // MARK: - Actions

    func openYahooFinance(symbol: String) {
        guard let url = URL(string: "https://finance.yahoo.com/quote/\(symbol)") else { return }
        urlOpener.openInBrowser(url)
    }

    func openNewsArticle(_ newsItem: NewsItem) {
        guard let url = newsItem.link else { return }
        urlOpener.openInBrowser(url)
    }

    func editWatchlistHere() {
        editorWindowController = WatchlistEditorWindowController()
        editorWindowController?.showEditor(currentWatchlist: config.watchlist) { [weak self] newWatchlist in
            self?.saveAndReload(newWatchlist: newWatchlist)
        }
    }

    func editConfigJson() {
        configManager.openConfigFile()
    }

    private func saveAndReload(newWatchlist: [String]) {
        var newConfig = config
        newConfig.watchlist = newWatchlist
        newConfig.save()
        reloadConfig()
    }

    private func reloadConfig() {
        config = configManager.load(backfillDefaults: true)
        currentSortOption = SortOption.from(configString: config.sortDirection)
        currentIndex = 0
        hasCompletedInitialLoad = false  // Reset so next refresh fetches all symbols
        universeFinnhubBatchIndex = 0
        universeYahooBatchIndex = 0
        universeQuotes = [:]
        universeMarketCaps = [:]
        universeForwardPEs = [:]
        scannerEMAData = nil
        stopTimers()
        startTimers()
        Task {
            await cancelBackfill()
            await stockService.updateFinnhubApiKey(config.finnhubApiKey)
            await refreshCachesFromDisk()
            await refreshAllQuotes()
            await startBackfill()
        }
    }

    func resetConfigToDefault() {
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

    func clearAllCaches() {
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
        lowestClosePrices = [:]
        forwardPEData = [:]
        currentForwardPEs = [:]
        swingLevelEntries = [:]
        rsiValues = [:]
        emaEntries = [:]
        universeQuotes = [:]
        universeMarketCaps = [:]
        universeForwardPEs = [:]

        hasCompletedInitialLoad = false
        Task {
            await cancelBackfill()
            await ytdCacheManager.clearForNewYear()
            await quarterlyCacheManager.clearAllQuarters()
            await highestCloseCacheManager.clearForNewRange(cacheQuarterRange())
            await forwardPECacheManager.clearForNewRange(cacheQuarterRange())
            await swingLevelCacheManager.clearForNewRange(cacheQuarterRange())
            await rsiCacheManager.clearForDailyRefresh()
            await emaCacheManager.clearForDailyRefresh()
            await refreshAllQuotes()
            await startBackfill()
        }
    }

    func clearEMACache() {
        emaEntries = [:]
        Task {
            await emaCacheManager.clearForDailyRefresh()
            await emaCacheManager.save()
            await fetchMissingDailyAnalysis()
        }
    }

    func selectSortOption(_ option: SortOption) {
        currentSortOption = option
        config.sortDirection = option.configString
        config.save()
    }

    func selectClosedMarketAsset(_ asset: ClosedMarketAsset) {
        config.menuBarAssetWhenClosed = asset
        config.save()
        updateMenuBarDisplay()
        Task { await refreshAllQuotes() }
    }

    func toggleFilter(_ option: TickerFilter) {
        var filter = currentFilter
        filter.formSymmetricDifference(option)
        config.filterGreenFields = filter.rawValue
        config.save()
    }

    func toggleSource(_ source: WatchlistSource) {
        var sources = currentWatchlistSource
        sources.formSymmetricDifference(source)
        guard !sources.isEmpty else { return }
        currentWatchlistSource = sources
        currentIndex = 0
    }

    func clearFilters() {
        config.filterGreenFields = 0
        currentWatchlistSource = .allSources
        config.save()
    }

    func showQuarterlyPanel() {
        if quarterlyWindowController == nil {
            quarterlyWindowController = QuarterlyPanelWindowController()
        }
        if !config.scannerBaseURL.isEmpty, scannerEMAData == nil {
            Task {
                scannerEMAData = await scannerService.fetchEMAData(baseURL: config.scannerBaseURL)
                showQuarterlyWindow()
            }
        } else {
            showQuarterlyWindow()
        }
    }

    private func showQuarterlyWindow() {
        quarterlyWindowController?.showWindow(
            watchlist: extraStatsSymbols,
            quarterInfos: quarterInfos,
            highlightedSymbols: Set(config.highlightedSymbols),
            highlightColor: config.highlightColor,
            highlightOpacity: config.highlightOpacity,
            data: makeQuarterlyPanelData(),
            personalWatchlist: Set(config.watchlist),
            onWatchlistChange: { [weak self] symbol, shouldAdd in
                guard let self else { return }
                let newWatchlist: [String]
                if shouldAdd {
                    newWatchlist = WatchlistOperations.addSymbol(symbol, to: self.config.watchlist)
                } else {
                    newWatchlist = WatchlistOperations.removeSymbol(symbol, from: self.config.watchlist)
                }
                self.saveAndReload(newWatchlist: newWatchlist)
            },
            isUniverseActive: !config.universe.isEmpty,
            refreshInterval: config.refreshInterval,
            hasFinnhubApiKey: !config.finnhubApiKey.isEmpty
        )
    }

    private func makeQuarterlyPanelData() -> QuarterlyPanelData {
        QuarterlyPanelData(
            quotes: mergedQuotes(),
            quarterPrices: quarterlyPrices,
            highestClosePrices: highestClosePrices,
            forwardPEData: forwardPEData,
            currentForwardPEs: mergedForwardPEs(),
            swingLevelEntries: swingLevelEntries,
            rsiValues: rsiValues,
            emaEntries: emaEntries,
            scannerEMAData: scannerEMAData,
            vixSpikes: vixSpikes,
            vixSpikePrices: vixSpikePrices
        )
    }

    func showDebugWindow() {
        if debugWindowController == nil {
            debugWindowController = DebugWindowController()
        }
        debugWindowController?.showWindow()
    }

    func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}

// MARK: - Market State Color

extension MarketState {
    var swiftUIColor: Color {
        switch self {
        case .open: return .green
        case .preMarket, .afterHours: return .orange
        case .closed: return .red
        }
    }
}

// MARK: - NSPopoverDelegate

extension MenuBarController: NSPopoverDelegate {
    nonisolated func popoverDidClose(_ notification: Notification) {
        Task { @MainActor in
            cleanupPopover()
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
