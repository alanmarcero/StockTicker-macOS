# StockTicker

A macOS menu bar app for tracking stock, ETF, and crypto prices. Built with Swift/SwiftUI + AppKit.

## Build & Run

```bash
./install.sh          # Build, install to /Applications, launch
./uninstall.sh        # Interactive uninstall (prompts for config/cache removal)
./uninstall.sh --force  # Non-interactive: stop app, remove from /Applications, preserve config
```

Requirements: macOS 13+ (Ventura), Xcode 15+. Runs as `LSUIElement` (menu bar only, no Dock icon).

## Verification Steps

After completing any code changes, run these steps to verify:

```bash
# 1. Run tests
xcodebuild test -project StockTicker.xcodeproj -scheme StockTicker -destination 'platform=macOS'

# 2. Build release
xcodebuild -project StockTicker.xcodeproj -scheme StockTicker -configuration Release build

# 3. Uninstall (--force skips prompts, preserves config)
./uninstall.sh --force

# 4. Install
./install.sh

# 5. Confirm running
pgrep -x StockTicker && echo "App is running"
```

## Source Files (38 files, ~7,187 lines)

```
StockTickerApp.swift             (12L)   Entry point, creates MenuBarController
MenuBarView.swift                (878L)  Main controller: menu bar UI, state management
MenuBarController+Cache.swift    (329L)  Extension: YTD, quarterly, highest close, forward P/E, swing level, RSI, EMA, and market cap cache coordination with shared helpers
TimerManager.swift               (101L)  Timer lifecycle management with delegate pattern
StockService.swift               (213L)  Yahoo Finance API client (actor), chart v8 methods
StockService+MarketCap.swift     (69L)   Extension: market cap + forward P/E via v7 quote API with crumb auth
StockService+Historical.swift    (206L)  Extension: historical price fetching (YTD, quarterly, highest close, swing levels with dates, RSI)
StockService+ForwardPE.swift     (57L)   Extension: historical forward P/E ratios via timeseries API
StockService+EMA.swift           (73L)   Extension: 5-day/week/month EMA fetch + weekly crossover via chart v8 API
StockData.swift                  (524L)  Data models: StockQuote, TradingSession, TradingHours, Formatting, v7/timeseries response models
MarketSchedule.swift             (291L)  NYSE holiday/hours calculation, MarketState enum
TickerConfig.swift               (299L)  Config loading/saving, protocols, legacy backward compat
TickerEditorView.swift           (541L)  SwiftUI watchlist editor, symbol validation, pure operations
RequestLogger.swift              (274L)  API request logging (actor), LoggingHTTPClient with retry, error queries
DebugWindow.swift                (281L)  Debug window with error indicator, injected RequestLogger
SortOption.swift                 (58L)   Sort option enum with config parsing and sorting logic
MarqueeView.swift                (126L)  Scrolling index marquee NSView with ping animation
MenuItemFactory.swift            (31L)   Factory for creating styled NSMenuItems and font constants
NewsService.swift                (134L)  RSS feed fetcher for financial news (actor)
NewsData.swift                   (153L)  NewsItem model, RSSParser, NewsSource enum
YTDCache.swift                   (99L)   Year-to-date price cache manager (actor)
QuarterlyCache.swift             (187L)  Quarter calculation helpers, quarterly price cache (actor)
QuarterlyPanelModels.swift        (65L)   Extra Stats data models: QuarterlyRow, MiscStat, QuarterlyViewMode, QuarterlySortColumn
QuarterlyPanelView.swift         (623L)  Extra Stats window: SwiftUI view, controller
QuarterlyPanelViewModel.swift     (400L)  Extra Stats view model: row building, sorting, highlights, misc stats
LayoutConfig.swift               (81L)   Centralized layout constants
AppInfrastructure.swift           (78L)   OpaqueContainerView, FileSystemProtocol, WorkspaceProtocol, ColorMapping
CacheStorage.swift               (56L)   Generic cache file I/O helper and CacheTimestamp utilities (used by YTD, quarterly, highest close, forward P/E, swing level, RSI caches)
TickerDisplayBuilder.swift       (181L)  Ticker display formatting, color helpers, HighlightConfig
QuoteFetchCoordinator.swift      (116L)  Stateless fetch orchestration with FetchResult
HighestCloseCache.swift          (103L)  Highest daily close cache manager (actor), daily refresh
ForwardPECache.swift             (89L)   Forward P/E ratio cache manager (actor), permanent per-quarter cache
SwingAnalysis.swift              (73L)   Pure swing analysis algorithm (breakout/breakdown detection with indices)
SwingLevelCache.swift            (110L)  Swing level cache manager (actor), daily refresh
RSIAnalysis.swift                (37L)   Pure RSI-14 algorithm (Wilder's smoothing method)
RSICache.swift                   (87L)   RSI cache manager (actor), daily refresh
EMAAnalysis.swift                (47L)   Pure 5-period EMA algorithm (SMA seed + iterative) + weekly crossover detection
EMACache.swift                   (96L)   EMA cache manager (actor), daily refresh, 3 timeframes + crossover per symbol
```

## Test Files (32 files, ~10,178 lines)

```
StockDataTests.swift             (724L)  Quote calculations, session detection, formatting, market cap, highest close, timeseries
StockServiceTests.swift          (790L)  API mocking, fetch operations, extended hours, v7 response decoding, highest close, forward P/E, swing levels with dates, RSI, EMA
MarketScheduleTests.swift        (271L)  Holiday calculations, market state, schedules
TickerConfigTests.swift          (682L)  Config load/save, encoding, legacy backward compat
TickerEditorStateTests.swift     (314L)  Editor state machine, validation
TickerListOperationsTests.swift  (212L)  Pure watchlist function tests
TickerValidatorTests.swift       (406L)  Symbol validation, HTTP mocking
TickerAddErrorTests.swift        (95L)   Error enum and result type tests
MenuBarViewTests.swift           (224L)  SortOption tests, sorting with quotes (market cap, YTD)
MarqueeViewTests.swift           (106L)  Config constants, layer setup, scrolling, ping animation
MenuItemFactoryTests.swift       (141L)  Font tests, disabled/action/submenu item creation
YTDCacheTests.swift              (289L)  Cache load/save, year rollover, DateProvider injection
QuarterlyCacheTests.swift        (481L)  Quarter calculations, cache operations, pruning, quarterStartTimestamp
QuarterlyPanelTests.swift        (1610L) Row computation, sorting, direction toggling, missing data, highlighting, view modes, highest close, forward P/E, price breaks with dates, RSI, EMA, crossover, misc stats
ColorMappingTests.swift          (52L)   Color name mapping, case insensitivity, NSColor/SwiftUI bridge
NewsServiceTests.swift           (832L)  RSS parsing, deduplication, multi-source fetching
LayoutConfigTests.swift          (97L)   Layout constant validation
RequestLoggerTests.swift         (70L)   Error count/last error queries, clear reset
TimerManagerTests.swift          (129L)  Timer lifecycle, delegate callbacks, start/stop
TestUtilities.swift              (59L)   Shared test helpers (MockDateProvider, date creation)
DebugViewModelTests.swift        (67L)   DebugViewModel refresh/clear with injected logger
CacheStorageTests.swift          (101L)  Generic cache load/save with MockFileSystem
TickerDisplayBuilderTests.swift  (230L)  Menu bar title, ticker title, highlights, color helpers, highest close
QuoteFetchCoordinatorTests.swift (253L)  Fetch modes, FetchResult correctness, MockStockService
HighestCloseCacheTests.swift     (334L)  Cache load/save, invalidation, daily refresh, missing symbols
ForwardPECacheTests.swift        (255L)  Forward P/E cache load/save, invalidation, missing symbols, empty dict handling
SwingAnalysisTests.swift         (147L)  Swing analysis algorithm: empty, steady, threshold detection, multiple swings, index tracking
SwingLevelCacheTests.swift       (371L)  Swing level cache load/save, invalidation, daily refresh, missing symbols, nil values
RSIAnalysisTests.swift           (97L)   RSI algorithm: empty, insufficient, all gains/losses, alternating, trends, custom period
RSICacheTests.swift              (230L)  RSI cache load/save, missing symbols, daily refresh, clear
EMAAnalysisTests.swift           (140L)  EMA algorithm: empty, insufficient, SMA, known sequence, constant, custom period, trends, weekly crossover detection
EMACacheTests.swift              (313L)  EMA cache load/save, missing symbols, daily refresh, clear, nil values, crossover field
```

## File Dependencies

```
StockTickerApp.swift
└── MenuBarView.swift (MenuBarController)

MenuBarView.swift (MenuBarController)
├── MenuBarController+Cache.swift (cache coordination extension)
├── TimerManager.swift (TimerManager, TimerManagerDelegate)
├── StockService.swift (StockServiceProtocol)
├── NewsService.swift (NewsServiceProtocol)
├── TickerConfig.swift (WatchlistConfigManager, WatchlistConfig)
├── MarketSchedule.swift (MarketSchedule, MarketState)
├── StockData.swift (StockQuote, TradingSession, TradingHours, Formatting)
├── SortOption.swift (SortOption)
├── MarqueeView.swift (MarqueeView, MarqueeConfig)
├── MenuItemFactory.swift (MenuItemFactory)
├── YTDCache.swift (YTDCacheManager)
├── QuarterlyCache.swift (QuarterlyCacheManager, QuarterCalculation, QuarterInfo)
├── HighestCloseCache.swift (HighestCloseCacheManager)
├── ForwardPECache.swift (ForwardPECacheManager)
├── SwingLevelCache.swift (SwingLevelCacheManager)
├── RSICache.swift (RSICacheManager)
├── EMACache.swift (EMACacheManager)
├── QuarterlyPanelView.swift (QuarterlyPanelWindowController)
├── TickerEditorView.swift (WatchlistEditorWindowController)
├── DebugWindow.swift (DebugWindowController)
├── TickerDisplayBuilder.swift (TickerDisplayBuilder, HighlightConfig)
└── QuoteFetchCoordinator.swift (QuoteFetchCoordinator, FetchResult)

StockService.swift
├── StockService+MarketCap.swift (market cap + forward P/E extension)
├── StockService+Historical.swift (historical price + swing level extension)
├── StockService+ForwardPE.swift (forward P/E timeseries extension)
├── StockService+EMA.swift (5-day/week/month EMA extension)
├── StockData.swift (StockQuote, TradingSession, YahooChartResponse, TradingHours)
└── RequestLogger.swift (LoggingHTTPClient, HTTPClient)

TickerDisplayBuilder.swift
├── StockData.swift (StockQuote, TradingHours)
├── MenuItemFactory.swift (MenuItemFactory)
└── LayoutConfig.swift (LayoutConfig.Ticker)

QuoteFetchCoordinator.swift
└── StockService.swift (StockServiceProtocol)

NewsService.swift
├── NewsData.swift (NewsItem, RSSParser)
└── RequestLogger.swift (LoggingHTTPClient)

TickerConfig.swift
├── AppInfrastructure.swift (FileSystemProtocol, WorkspaceProtocol)
└── LayoutConfig.swift (LayoutConfig.Watchlist.maxSize)

TickerEditorView.swift
├── StockData.swift (YahooChartResponse)
├── TickerConfig.swift (WatchlistConfig.maxWatchlistSize)
└── RequestLogger.swift (LoggingHTTPClient)

QuarterlyPanelView.swift
├── QuarterlyPanelModels.swift (QuarterlyRow, MiscStat, QuarterlyViewMode, QuarterlySortColumn, QuarterlyWindowSize, QuarterlyFormatting)
├── QuarterlyPanelViewModel.swift (QuarterlyPanelViewModel)
├── QuarterlyCache.swift (QuarterInfo)
├── SwingLevelCache.swift (SwingLevelCacheEntry)
├── StockData.swift (StockQuote)
├── AppInfrastructure.swift (OpaqueContainerView)
└── LayoutConfig.swift (LayoutConfig.QuarterlyWindow)

QuarterlyPanelViewModel.swift
├── QuarterlyPanelModels.swift (QuarterlyRow, MiscStat, QuarterlyViewMode, QuarterlySortColumn, QuarterlyFormatting)
├── QuarterlyCache.swift (QuarterInfo, QuarterCalculation)
├── SwingLevelCache.swift (SwingLevelCacheEntry)
├── EMACache.swift (EMACacheEntry)
├── StockData.swift (StockQuote, Formatting)
└── AppInfrastructure.swift (ColorMapping)

StockService+Historical.swift
├── SwingAnalysis.swift (SwingAnalysis)
└── RSIAnalysis.swift (RSIAnalysis)

StockService+EMA.swift
└── EMAAnalysis.swift (EMAAnalysis)

QuarterlyCache.swift
├── AppInfrastructure.swift (FileSystemProtocol)
├── MarketSchedule.swift (DateProvider)
└── CacheStorage.swift (CacheStorage, CacheTimestamp)

YTDCache.swift
├── AppInfrastructure.swift (FileSystemProtocol)
├── MarketSchedule.swift (DateProvider)
└── CacheStorage.swift (CacheStorage, CacheTimestamp)

HighestCloseCache.swift
├── AppInfrastructure.swift (FileSystemProtocol)
├── MarketSchedule.swift (DateProvider)
└── CacheStorage.swift (CacheStorage, CacheTimestamp)

ForwardPECache.swift
├── AppInfrastructure.swift (FileSystemProtocol)
├── MarketSchedule.swift (DateProvider)
└── CacheStorage.swift (CacheStorage, CacheTimestamp)

SwingLevelCache.swift
├── AppInfrastructure.swift (FileSystemProtocol)
├── MarketSchedule.swift (DateProvider)
└── CacheStorage.swift (CacheStorage, CacheTimestamp)

RSICache.swift
├── AppInfrastructure.swift (FileSystemProtocol)
├── MarketSchedule.swift (DateProvider)
└── CacheStorage.swift (CacheStorage, CacheTimestamp)

EMACache.swift
├── AppInfrastructure.swift (FileSystemProtocol)
├── MarketSchedule.swift (DateProvider)
└── CacheStorage.swift (CacheStorage, CacheTimestamp)

AppInfrastructure.swift (standalone, no dependencies)

DebugWindow.swift
└── RequestLogger.swift (RequestLogger, RequestLogEntry)
```

## Design Patterns

### Dependency Injection (Protocol-Based)
All major components use protocols for testability:
- `StockServiceProtocol` / `HTTPClient` — network layer
- `NewsServiceProtocol` — news fetching
- `TimerManagerDelegate` — timer lifecycle callbacks
- `FileSystemProtocol` / `WorkspaceProtocol` — file operations
- `SymbolValidator` — symbol validation
- `DateProvider` — injectable time (used by MarketSchedule, YTDCacheManager, QuarterlyCacheManager, HighestCloseCacheManager, ForwardPECacheManager, SwingLevelCacheManager, RSICacheManager, EMACacheManager)
- `URLOpener` / `WindowProvider` — UI abstraction

### Actors for Thread Safety
- `StockService` — concurrent quote fetching via TaskGroup
- `NewsService` — concurrent RSS fetching via TaskGroup
- `RequestLogger` — thread-safe request log storage
- `YTDCacheManager` — thread-safe YTD price cache
- `QuarterlyCacheManager` — thread-safe quarterly price cache
- `HighestCloseCacheManager` — thread-safe highest close price cache
- `ForwardPECacheManager` — thread-safe forward P/E ratio cache
- `SwingLevelCacheManager` — thread-safe swing level (breakout/breakdown) cache
- `RSICacheManager` — thread-safe RSI value cache
- `EMACacheManager` — thread-safe EMA value cache (3 timeframes per symbol)

### State Management
- `MenuBarController` — `@MainActor`, `@Published` properties, drives all UI
- `WatchlistEditorState` — `@MainActor` ObservableObject for editor window
- `DebugViewModel` — `@MainActor` ObservableObject, auto-refreshes every 1s
- `QuarterlyPanelViewModel` — `@MainActor` ObservableObject for Extra Stats window

### Constants in Private Enums
All magic numbers are extracted into namespaced enums:
- `Layout`, `Strings`, `Timing`, `MenuTag`, `TickerInsertIndex` (MenuBarView)
- `Intervals` (TimerManager)
- `MarqueeConfig` (MarqueeView)
- `DebugWindowSize`, `DebugTiming` (DebugWindow)
- `WindowSize`, `WindowTiming` (TickerEditorView)
- `ResponseLimits`, `RetryConfig` (RequestLogger)
- `TradingHours` (StockData — shared across codebase)
- `Formatting` (StockData — currency and percent formatting)
- `LayoutConfig` (centralized layout dimensions)
- `QuarterlyWindow`, `QuarterlyFormatting` (QuarterlyPanelModels)

### Pure Functions
- `WatchlistOperations` — symbol add/remove/sort operations
- `SortOption.sort()` — sorting with quote context
- Color helpers: `priceChangeColor()`, `ColorMapping.nsColor(from:)`, `ColorMapping.color(from:)`
- Formatting: `Formatting.currency()`, `Formatting.signedCurrency()`, `Formatting.signedPercent()`, `Formatting.marketCap()`
- `QuarterCalculation` — quarter date math, identifier/label generation
- `TickerDisplayBuilder` — stateless enum with static display formatting methods
- `QuoteFetchCoordinator` — stateless enum with static fetch orchestration methods
- `SwingAnalysis` — stateless enum with pure swing high/low detection algorithm (returns prices + indices)
- `RSIAnalysis` — stateless enum with pure RSI-14 calculation (Wilder's smoothing)
- `EMAAnalysis` — stateless enum with pure 5-period EMA calculation (SMA seed) and weekly crossover detection

### Callback Cleanup
`WatchlistEditorState` explicitly clears callbacks to prevent retain cycles. Called in `save()`, `cancel()`, and when window closes.

### HighlightConfig
Batches 5 highlight parameters into a single struct with `resolve()`, `withPingBackground()`, `withPingDisabled()` helpers. Defined in `TickerDisplayBuilder.swift`, used by both MenuBarView and QuarterlyPanelView.

### Generic CacheStorage\<T\>
Eliminates duplicate load/save file I/O in YTDCacheManager, QuarterlyCacheManager, HighestCloseCacheManager, ForwardPECacheManager, SwingLevelCacheManager, RSICacheManager, and EMACacheManager. Single `CacheStorage<T: Codable>` struct handles JSON encoding/decoding, directory creation, and error logging. `CacheTimestamp` enum provides shared ISO8601 formatting and daily refresh logic.

### Legacy Config Decoding
`decodeLegacy()` extension on `KeyedDecodingContainer` handles backward-compatible field names (e.g. `tickers` → `watchlist`, `cycleInterval` → `menuBarRotationInterval`). Two overloads: required (throws) and optional (with default).

## API Integration

### Yahoo Finance Chart API (v8) — Price Data
```
https://query1.finance.yahoo.com/v8/finance/chart/{SYMBOL}?interval=1m&range=1d&includePrePost=true
```

### Yahoo Finance Quote API (v7) — Market Cap + Current Forward P/E
```
https://query2.finance.yahoo.com/v7/finance/quote?symbols={SYMBOLS}&crumb={CRUMB}&fields=marketCap,quoteType,forwardPE
```

Requires crumb/cookie authentication. StockService manages this internally:
1. `GET https://fc.yahoo.com/v1/test` → establishes cookies in URLSession.shared
2. `GET https://query2.finance.yahoo.com/v1/test/getcrumb` → returns crumb string
3. Use crumb + cookies for v7 quote requests. Crumb auto-refreshes on 401.

Batch request for all watchlist symbols. Returns `marketCap` and `forwardPE` per symbol via `fetchQuoteFields()`. Fetched each refresh cycle alongside chart data. Response: `YahooQuoteResponse` → `QuoteResponseData` → `[QuoteResult]`.

### Yahoo Finance Fundamentals Timeseries API — Historical Forward P/E
```
https://query2.finance.yahoo.com/ws/fundamentals-timeseries/v1/finance/timeseries/{SYMBOL}?type=quarterlyForwardPeRatio&period1={P1}&period2={P2}
```

No authentication required. One call per symbol. Returns quarterly forward P/E ratios with `asOfDate` (e.g. "2024-12-31") mapped to quarter identifiers (e.g. "Q4-2024"). Response: `YahooTimeseriesResponse` → `TimeseriesResult` → `[TimeseriesData]` → `[ForwardPeEntry]`.

### HTTP Client Architecture
```
HTTPClient (protocol) ─── data(from:) + data(for:) interface
    │
URLSession (conforms) ─── raw network layer
    │
LoggingHTTPClient (wraps HTTPClient)
    ├── Logs all requests to RequestLogger actor
    ├── buildSuccessEntry() extracts headers/body into log entries
    ├── Retry: 1 retry after 0.5s on non-2xx or network error
    ├── Skips retries during pre-market/after-hours
    └── Response body capped at ResponseLimits.maxBodySize (50KB)
    │
StockService, NewsService, YahooSymbolValidator (consumers)
    └── All default to LoggingHTTPClient()
```

Individual request retry — if fetching AAPL, MSFT, GOOGL and MSFT fails, only MSFT retries.

### Smart Fetching (Market Hours Aware)

| Market State | Watchlist | Index Marquee | Menu Bar |
|--------------|-----------|---------------|----------|
| Closed | Skip | `alwaysOpenMarkets` | `menuBarAssetWhenClosed` |
| Pre-Market | Fetch | `alwaysOpenMarkets` | `menuBarAssetWhenClosed` |
| Open | Fetch | `indexSymbols` | Cycle through watchlist |
| After-Hours | Fetch | `alwaysOpenMarkets` | `menuBarAssetWhenClosed` |

### Initial Load vs Subsequent Refreshes

Two-phase strategy controlled by `hasCompletedInitialLoad`:

1. **Initial load** — Fetches ALL symbols regardless of market state. Ensures users see data on weekends.
2. **Subsequent refreshes** — Smart fetching based on market state. Only crypto refreshes when closed.

Weekend handling:
- Yahoo API may return "POST" on weekends (from Friday's after-hours)
- App forces `yahooMarketState = "CLOSED"` on weekends
- Extended hours labels (Pre/AH) not shown on weekends

Config reload resets `hasCompletedInitialLoad = false` and calls `fetchMissingYTDPrices()`, `fetchMissingQuarterlyPrices()`, `fetchMissingForwardPERatios()`, `fetchMissingSwingLevels()`, `fetchMissingRSIValues()`, and `fetchMissingEMAValues()`.

### Extended Hours Calculation

`StockService.calculateExtendedHoursData()`:
1. Gets latest close price from chart indicators (`includePrePost=true`)
2. Uses time-based session detection as fallback
3. Calculates change from regular market price to current indicator price
4. Only populates when difference > `TradingHours.extendedHoursPriceThreshold`

### Selective Ping Animation

Only symbols that were actually fetched trigger the highlight animation. On weekends, only crypto symbols in the watchlist ping.

## YTD Price Tracking

Year-to-date prices cached at `~/.stockticker/ytd-cache.json`:

```json
{
  "year": 2026,
  "lastUpdated": "2026-01-15T12:00:00Z",
  "prices": { "AAPL": 185.50, "SPY": 475.25 }
}
```

**Flow:** App startup loads cache → checks year rollover → fetches missing prices → each refresh attaches cached YTD to quotes → year change clears cache automatically.

Key methods: `loadYTDCache()`, `fetchMissingYTDPrices()`, `attachYTDPricesToQuotes()`

## Highest Close Tracking

Shows how far each symbol's current price is from its highest daily closing price over the trailing 12 completed quarters (~3 years). Displayed as `High: -8.52%` in both the main dropdown ticker and the Extra Stats window.

Cached at `~/.stockticker/highest-close-cache.json`:

```json
{
  "quarterRange": "Q1-2023:Q4-2025",
  "lastUpdated": "2026-02-16T12:00:00Z",
  "prices": { "AAPL": 254.23, "SPY": 602.10 }
}
```

**Flow:** App startup loads cache → checks quarter range invalidation (new quarter = new range) → checks daily freshness → fetches missing prices → each refresh attaches cached highest close to quotes.

**Invalidation:** `quarterRange` changes when a new quarter completes. Daily refresh clears prices so new daily closes are captured.

**API:** One chart v8 call per symbol for the full 3-year range (`interval=1d`), extracts `.max()` from close prices (~750 daily bars, ~20-30KB).

Key methods: `loadHighestCloseCache()`, `fetchMissingHighestCloses()`, `attachHighestClosesToQuotes()`, `refreshHighestClosesIfNeeded()`

## Forward P/E Tracking

Historical forward P/E ratios per quarter end, fetched from Yahoo Finance Fundamentals Timeseries API. Cached at `~/.stockticker/forward-pe-cache.json`:

```json
{
  "quarterRange": "Q1-2023:Q4-2025",
  "lastUpdated": "2026-02-16T12:00:00Z",
  "symbols": {
    "AAPL": { "Q4-2025": 28.5, "Q3-2025": 30.2 },
    "BTC-USD": {}
  }
}
```

**Flow:** App startup loads cache → checks quarter range invalidation → fetches missing symbols → stores results (empty dict for non-equity symbols) → displayed in Extra Stats Forward P/E tab.

**Permanent cache:** Quarter-end P/E values are immutable historical facts. No daily refresh. Only fetches on startup for missing symbols or when quarter range changes (new quarter completes). Symbols with no P/E data stored as empty `{}` to avoid refetching.

**API:** One timeseries call per symbol for the full 3-year range. Batch fetch via TaskGroup.

Key methods: `loadForwardPECache()`, `fetchMissingForwardPERatios()`, `forwardPEQuarterRange()`

## Swing Level Tracking (Breakout/Breakdown)

Detects significant swing highs and swing lows using the `SwingAnalysis` pure algorithm. A **significant high** is a peak followed by a decline of at least 10% (the threshold). A **significant low** is a trough followed by a rise of at least 10%. The breakout price is the highest such significant high; the breakdown price is the highest such significant low (strongest support level).

Cached at `~/.stockticker/swing-level-cache.json`:

```json
{
  "quarterRange": "Q1-2023:Q4-2025",
  "lastUpdated": "2026-02-16T12:00:00Z",
  "entries": {
    "AAPL": { "breakoutPrice": 254.23, "breakoutDate": "7/16/24", "breakdownPrice": 120.50, "breakdownDate": "1/3/23" },
    "BTC-USD": { "breakoutPrice": null, "breakoutDate": null, "breakdownPrice": null, "breakdownDate": null }
  }
}
```

**Flow:** App startup loads cache → checks quarter range invalidation → checks daily freshness → fetches missing symbols → displayed in Extra Stats Breakout/Breakdown tabs.

**Invalidation:** Same as highest close — `quarterRange` changes when a new quarter completes. Daily refresh clears entries so new daily closes are captured.

**API:** Same chart v8 call as highest close (daily bars for full 3-year range). Timestamps and closes are zipped, null closes filtered. `SwingAnalysis.analyze(closes:)` returns prices and indices; indices map to timestamps for date formatting ("M/d/yy").

Key methods: `loadSwingLevelCache()`, `fetchMissingSwingLevels()`, `refreshSwingLevelsIfNeeded()`

## RSI Tracking

Daily RSI-14 (Relative Strength Index) using Wilder's smoothed method over ~250 daily closing prices (1 year of data). Displayed as a column in the Price Breaks tables in Extra Stats. Color-coded: >70 red (overbought), <30 green (oversold), secondary otherwise.

Cached at `~/.stockticker/rsi-cache.json`:

```json
{
  "lastUpdated": "2026-02-17T12:00:00Z",
  "values": { "AAPL": 65.2, "SPY": 48.7 }
}
```

**Flow:** App startup loads cache → checks daily freshness → fetches missing symbols → values passed to Extra Stats Price Breaks tables.

**Invalidation:** Daily refresh clears values so fresh RSI is computed from latest closes.

**API:** One chart v8 call per symbol with `range=1y&interval=1d` (~250 bars, ~10KB). `RSIAnalysis.calculate()` computes RSI from close prices.

Key methods: `loadRSICache()`, `fetchMissingRSIValues()`, `refreshRSIIfNeeded()`

## EMA Tracking

5-period Exponential Moving Average across three timeframes: daily (5-day), weekly (5-week), and monthly (5-month). Displayed in the Extra Stats "5 EMAs" tab — three side-by-side tables showing symbols whose current price is above the EMA for each timeframe.

Cached at `~/.stockticker/ema-cache.json`:

```json
{
  "lastUpdated": "2026-02-17T12:00:00Z",
  "entries": {
    "AAPL": { "day": 150.2, "week": 148.5, "month": 145.0, "weekCrossoverWeeksBelow": 3 },
    "BTC-USD": { "day": null, "week": null, "month": null, "weekCrossoverWeeksBelow": null }
  }
}
```

**Flow:** App startup loads cache → checks daily freshness → fetches missing symbols → values passed to Extra Stats 5 EMAs tab.

**Invalidation:** Daily refresh clears entries so fresh EMAs are computed from latest bars.

**API:** Three chart v8 calls per symbol:
- Daily: `range=1mo&interval=1d` (~20 bars)
- Weekly: `range=6mo&interval=1wk` (~26 bars)
- Monthly: `range=2y&interval=1mo` (~24 bars)

All three fetched concurrently via `async let`. Batch fetch via `TaskGroup` over symbols.

**Algorithm:** `EMAAnalysis.calculate()` — SMA of first `period` values as seed, then iterative EMA with multiplier `2/(period+1)` = 0.3333 for period 5. `EMAAnalysis.detectWeeklyCrossover()` — computes full EMA series, detects most recent weekly close crossing above 5-week EMA after one or more weeks below; returns weeks-below count or nil.

Key methods: `loadEMACache()`, `fetchMissingEMAValues()`, `refreshEMAIfNeeded()`

## Extra Stats (Cmd+Opt+Q)

Standalone window with six view modes (segmented picker): **Since Quarter** shows percent change from each quarter's end to current price; **During Quarter** shows percent change within each quarter (start to end); **Forward P/E** shows historical forward P/E ratios per quarter end; **Price Breaks** shows two headed sub-tables — Breakout (percent from highest significant high) and Breakdown (percent from lowest significant low) via swing analysis; **5 EMAs** shows three side-by-side tables of symbols above their 5-day, 5-week, and 5-month EMAs with % above; **Misc Stats** shows aggregate statistics across the watchlist (e.g., % of symbols within 5% of their highest close). Uses 12 most recent completed quarters (3 years). Cached at `~/.stockticker/quarterly-cache.json`:

```json
{
  "lastUpdated": "2026-02-10T12:00:00Z",
  "quarters": {
    "Q4-2025": { "AAPL": 254.23, "SPY": 602.10 },
    "Q3-2025": { "AAPL": 228.50, "SPY": 571.30 }
  }
}
```

**Rolling window:** `QuarterCalculation.lastNCompletedQuarters(from:count:12)` always produces the 12 most recent completed quarters. New quarters are fetched automatically; old quarters pruned from cache.

**Fetching strategy:** Per-quarter sequential, per-symbol parallel via TaskGroup. Cache saved after each quarter (preserves progress if interrupted). First run ~832 API calls (64 symbols x 13 quarters); subsequent runs only fetch new symbols or newly completed quarters.

**View modes:** `QuarterlyViewMode` enum (in `QuarterlyPanelModels`) — `.sinceQuarter` computes `(currentPrice - Q_end) / Q_end`, `.duringQuarter` computes `(Q_end - Q_prev_end) / Q_prev_end`, `.forwardPE` shows raw P/E values per quarter end, `.priceBreaks` shows two independently sorted tables (breakoutRows and breakdownRows) with Symbol, Date, and % columns, `.emas` shows three independently sorted tables (emaDayRows, emaWeekRows, emaMonthRows) with Symbol and % columns, `.miscStats` shows non-sortable aggregate statistics (e.g., % of watchlist within 5% of High). A 13th quarter is fetched as a reference price so during-quarter yields data for all 12 displayed quarters. View model (`QuarterlyPanelViewModel`) stores data (`storedWatchlist`, `storedQuotes`, `storedQuarterPrices`, `storedForwardPEData`, `storedCurrentForwardPEs`, `storedSwingLevelEntries`, `storedRSIValues`, `storedEMAEntries`) so rows recompute when toggling modes via `switchMode()`.

**Live updates:** During market hours, percent changes update each refresh cycle (~15s) using `quote.price` (regular market price, never pre/post). Format: `+12.34%` / `-5.67%` / `--` (missing). Color-coded green/red/secondary.

**Sortable columns:** Symbol, High/Current (% from highest close in price modes, current forward P/E in P/E mode), and each quarter column. Click header to sort ascending; click again to toggle descending. Switching columns resets to ascending. Nil values sort before any value. Column headers are pinned during vertical scrolling via `LazyVStack(pinnedViews: [.sectionHeaders])`.

**Row highlighting:** Config-highlighted symbols (`config.highlightedSymbols`) get a persistent colored background row using `highlightColor` and `highlightOpacity`. These cannot be toggled off by clicking. Non-config rows can be click-toggled on/off for readability. `ColorMapping` enum in AppInfrastructure.swift provides shared color name mapping for both NSColor and SwiftUI Color.

**Forward P/E mode:** Filters to equity symbols only (symbols with at least one non-empty P/E entry). Shows "Current" column (current forward P/E from v7 API, always secondary color) and quarter columns (historical P/E as of quarter end). Color: green when P/E decreased vs prior quarter, red when increased, secondary when no prior value.

**Price Breaks mode:** Combined mode (`isPriceBreaksMode`) with side-by-side layout — "Breakout" table on the left, "Breakdown" table on the right, each independently scrollable with its own title and column headers. Sorted independently. No High column, no quarter columns. Columns: Symbol (sortable), Date (sortable, "M/d/yy" format), % (sortable), RSI (sortable, daily RSI-14 color-coded >70 red / <30 green). Symbols with both breakout and breakdown data appear in both tables with unique IDs (`symbol-breakout`, `symbol-breakdown`). Header shows "X breakout, Y breakdown" count.

**5 EMAs mode:** Five-column layout (`isEMAsMode`) — "5-Day", "5-Week", "5-Month", "All Three", and "5W Cross" tables side by side. First four tables show symbols whose current price is above the respective 5-period EMA. "All Three" shows only symbols appearing in all three timeframe tables. "5W Cross" shows symbols whose most recent weekly close crossed above the 5-week EMA after one or more weeks below; "Wks" column shows weeks-below count (green for 2+, secondary for 1). Columns: Symbol (sortable), % or Wks (sortable). Sorted independently. Header shows "X day, Y week, Z month, N all, M cross" count. Unique IDs use `symbol-ema-day`, `symbol-ema-week`, `symbol-ema-month`, `symbol-ema-all`, `symbol-ema-cross`.

Key methods: `loadQuarterlyCache()`, `fetchMissingQuarterlyPrices()`, `showQuarterlyPanel()`

## News Headlines

Actor-based `NewsService` fetches from Yahoo Finance RSS and CNBC RSS concurrently via TaskGroup. Requests include a user-agent header (required by both feeds to avoid 429/403 responses). `RSSParser` (XMLParserDelegate) parses XML with dual date format support (RFC 2822 + ISO 8601). Headlines deduplicated via Jaccard word similarity (threshold: 0.6). Cache-busted with timestamp query parameter. Up to 6 clickable headlines displayed with proportional font; top-from-source headlines use bold variant.

## Menu Bar Features

### Cycling Display
Rotates through watchlist symbols at `menuBarRotationInterval` during regular hours. Shows `menuBarAssetWhenClosed` crypto asset otherwise.

### Dropdown Menu
- **Market status** — Colored dot indicator (green/orange/red), bold state text, schedule with holiday name
- **Countdown** — Shows last refresh time and seconds until next: `"Last: 10:32 AM · Next in 12s"`
- **Index marquee** — `MarqueeView` custom NSView scrolling at ~32px/sec with seamless looping. Bold index names, regular weight values. Ping animation on data refresh.
- **News headlines** — Proportional font (headlineFont/headlineFontBold). Top-from-source uses highlight background.
- **Ticker list** — Sorted by `defaultSort`, shows market cap/percent/YTD/highest close/extended hours. Uses `HighlightConfig` for ping and persistent highlight styling.
- **Submenus** — Edit Watchlist, Extra Stats, Config (edit/reload/reset/clear cache), Closed Market Display, Sort By, Debug

### Color Helpers
- `priceChangeColor(_:neutral:)` — green/red/neutral using `TradingHours.nearZeroThreshold`
- `ColorMapping.nsColor(from:)` — config string to NSColor (shared, in AppInfrastructure.swift)
- `ColorMapping.color(from:)` — config string to SwiftUI Color via `Color(nsColor:)` bridge
- `StockQuote` extensions: `displayColor`, `highlightColor`, `extendedHoursColor`, `ytdColor`, `highestCloseColor`
- YTD/highest close zero-change uses `.labelColor` (adapts to light/dark mode)

### Symbol Validation
`YahooSymbolValidator` makes a real API request, checks 200 status + valid `regularMarketPrice`.

### Debug Window (Cmd+Opt+D)
Shows API requests from last 60 seconds. Copy buttons for URL, request headers, response body (JSON pretty-printed). Auto-refreshes every 1s while open.

## Configuration

Location: `~/.stockticker/config.json` (auto-created on first launch)

| Field | Type | Default |
|-------|------|---------|
| `watchlist` | `[String]` (max 128) | 40+ symbols |
| `menuBarRotationInterval` | `Int` (seconds) | `5` |
| `refreshInterval` | `Int` (seconds) | `15` |
| `sortDirection` | `String` | `"percentDesc"` |
| `menuBarAssetWhenClosed` | `String` | `"BTC-USD"` |
| `indexSymbols` | `[IndexSymbol]` | SPX, DJI, NDX, VIX, RUT, BTC |
| `alwaysOpenMarkets` | `[IndexSymbol]` | BTC, ETH, SOL, DOGE, XRP |
| `highlightedSymbols` | `[String]` | `["SPY"]` |
| `highlightColor` | `String` | `"yellow"` |
| `highlightOpacity` | `Double` | `0.25` |
| `showNewsHeadlines` | `Bool` | `true` |
| `newsRefreshInterval` | `Int` (seconds) | `300` |

Saved with `prettyPrinted` and `sortedKeys`. Supports legacy field names via `decodeLegacy()` helper.

Sort options: `tickerAsc`/`Desc`, `marketCapAsc`/`Desc`, `percentAsc`/`Desc`, `ytdAsc`/`Desc`, `highAsc`/`Desc`

Highlight colors: `yellow`, `green`, `blue`, `red`, `orange`, `purple`, `pink`, `cyan`, `teal`, `gray`, `brown`

Closed market assets: `SPY`, `BTC-USD`, `ETH-USD`, `XRP-USD`, `DOGE-USD`, `SOL-USD`

Editing: menu bar → Edit Watchlist (Cmd+,), Config → Edit Config / Reload Config / Reset Config to Default

## App Entry Point

```swift
@main
struct StockTickerApp: App {
    @StateObject private var menuBarController = MenuBarController()
    var body: some Scene {
        Settings { EmptyView() }
    }
}
```

`MenuBarController` instantiated as `@StateObject` (kept alive for app lifetime). Empty `Settings` scene required for SwiftUI App protocol. All UI managed through the menu bar.

## Common Tasks

### Add a new config option
1. Add property to `WatchlistConfig` struct
2. Handle in `init(from decoder:)` with `decodeIfPresent` and default (or `decodeLegacy` if migrating a field name)
3. Add to `encode(to:)`
4. Update UI in `MenuBarController` if needed

### Add a new menu item
1. Create in `setupMenu()` or a `createXxxSubmenu()` method
2. Add `@objc` action method on `MenuBarController`
3. Wire up target/action

### Modify ticker display
- Menu bar: `TickerDisplayBuilder.menuBarTitle(for:showExtendedHours:)`
- Dropdown: `TickerDisplayBuilder.tickerTitle(quote:highlight:)` with `HighlightConfig`
- YTD section: `TickerDisplayBuilder.appendYTDSection()`
- Highest close section: `TickerDisplayBuilder.appendHighestCloseSection()`
- Extended hours: `TickerDisplayBuilder.appendExtendedHoursSection()`

### Change API data source
- Modify `StockService.fetchChartData()` and response models in `StockData.swift`

### Add a new display font
- Add to `MenuItemFactory` as a static property
- Reference from display methods in `TickerDisplayBuilder.swift`

## Opaque Window Pattern

SwiftUI views in NSHostingView can have transparency issues on macOS. `OpaqueContainerView` draws a solid `windowBackgroundColor` beneath SwiftUI content. NSMenu uses system vibrancy which cannot be disabled.

## Clean Code Principles

1. **Meaningful Names** — Names reveal intent without comments
2. **Functions Do One Thing** — Small, focused, single-responsibility functions
3. **DRY** — Single source of truth; `decodeLegacy`, `CacheStorage<T>`, `HighlightConfig`, `ColorMapping`, shared `TradingHours` constants, `APIEndpoints`
4. **Single Responsibility** — Extracted SortOption, MarqueeView, MenuItemFactory, MenuBarController+Cache, TimerManager, TickerDisplayBuilder, QuoteFetchCoordinator, StockService extensions, pure WatchlistOperations
5. **Boy Scout Rule** — Leave code cleaner than found
6. **Minimize Comments** — Comments explain *why* (intent, warnings), never *what*
7. **No Side Effects** — Pure functions for sorting, formatting, operations
8. **Fail Fast** — Guard clauses, early returns, error logging on file I/O
9. **KISS/YAGNI** — No premature abstraction
10. **Write Tests** — Protocol-based DI enables comprehensive testing; 30 test files with mock doubles
