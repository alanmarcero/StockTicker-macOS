# Stonks

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
pgrep -x Stonks && echo "App is running"
```

## Source Files (41 files, ~8,368 lines)

```
StockTickerApp.swift             (12L)   Entry point, creates MenuBarController
MenuBarView.swift                (960L)  Main controller: menu bar UI, state management, two-tier universe fetching with Finnhub routing
MenuBarController+Cache.swift    (476L)  Extension: YTD, quarterly, forward P/E, consolidated daily analysis, sneak peek EMA refresh, backfill scheduler coordination, and market cap cache coordination with shared helpers
BackfillScheduler.swift          (263L)  Staggered backfill actor: prioritized cache population (~15 req/min) with cancellation, BackfillCaches struct
TimerManager.swift               (101L)  Timer lifecycle management with delegate pattern
StockService.swift               (249L)  Yahoo Finance API client (actor), chart v8 methods, SymbolRouting enum
StockService+MarketCap.swift     (88L)   Extension: market cap + forward P/E via v7 quote API with crumb auth, batched in chunks of 50
StockService+Historical.swift    (450L)  Extension: historical price fetching (YTD, quarterly, daily analysis consolidation) with Finnhub routing + Yahoo fallback
StockService+ForwardPE.swift     (51L)   Extension: historical forward P/E ratios via timeseries API
StockService+Finnhub.swift       (82L)   Extension: Finnhub candle API fetch methods (daily candles, closes, historical close) + real-time quote fetch
StockService+EMA.swift           (215L)  Extension: 5-day/week EMA fetch + weekly crossover + below-count with Finnhub routing + Yahoo fallback
StockData.swift                  (553L)  Data models: StockQuote, TradingSession, TradingHours, Formatting, v7/timeseries response models, FinnhubCandleResponse, FinnhubQuoteResponse
MarketSchedule.swift             (291L)  NYSE holiday/hours calculation, MarketState enum
TickerConfig.swift               (312L)  Config loading/saving, protocols, legacy backward compat, universe field, finnhubApiKey
TickerEditorView.swift           (541L)  SwiftUI watchlist editor, symbol validation, pure operations
RequestLogger.swift              (316L)  API request logging (actor), LoggingHTTPClient with retry (skips 429), error queries, endpoint counts
DebugWindow.swift                (306L)  Debug window with error indicator, errors-only filter, endpoint counts, injected RequestLogger
SortOption.swift                 (58L)   Sort option enum with config parsing and sorting logic
MarqueeView.swift                (126L)  Scrolling index marquee NSView with ping animation
MenuItemFactory.swift            (31L)   Factory for creating styled NSMenuItems and font constants
NewsService.swift                (134L)  RSS feed fetcher for financial news (actor)
NewsData.swift                   (148L)  NewsItem model, RSSParser, NewsSource enum
YTDCache.swift                   (99L)   Year-to-date price cache manager (actor)
QuarterlyCache.swift             (187L)  Quarter calculation helpers, quarterly price cache (actor)
QuarterlyPanelModels.swift        (65L)   Extra Stats data models: QuarterlyRow, MiscStat, QuarterlyViewMode, QuarterlySortColumn
QuarterlyPanelView.swift         (626L)  Extra Stats window: SwiftUI view, controller
QuarterlyPanelViewModel.swift     (430L)  Extra Stats view model: row building, sorting, highlights, misc stats, universe labels
LayoutConfig.swift               (80L)   Centralized layout constants
AppInfrastructure.swift           (78L)   OpaqueContainerView, FileSystemProtocol, WorkspaceProtocol, ColorMapping
CacheStorage.swift               (56L)   Generic cache file I/O helper and CacheTimestamp utilities (used by YTD, quarterly, highest close, forward P/E, swing level, RSI caches)
TickerDisplayBuilder.swift       (181L)  Ticker display formatting, color helpers, HighlightConfig
QuoteFetchCoordinator.swift      (123L)  Stateless fetch orchestration with FetchResult, market state extraction from quotes
HighestCloseCache.swift          (103L)  Highest daily close cache manager (actor), daily refresh
ForwardPECache.swift             (89L)   Forward P/E ratio cache manager (actor), permanent per-quarter cache
SwingAnalysis.swift              (73L)   Pure swing analysis algorithm (breakout/breakdown detection with indices)
SwingLevelCache.swift            (110L)  Swing level cache manager (actor), daily refresh
RSIAnalysis.swift                (37L)   Pure RSI-14 algorithm (Wilder's smoothing method)
RSICache.swift                   (87L)   RSI cache manager (actor), daily refresh
EMAAnalysis.swift                (72L)   Pure 5-period EMA algorithm (SMA seed + iterative) + weekly crossover detection + weeks-below counting
EMACache.swift                   (119L)  EMA cache manager (actor), daily refresh, sneak peek refresh, 2 timeframes + crossover + below-count per symbol
ThrottledTaskGroup.swift         (50L)   Bounded concurrency utility with Backfill, FinnhubBackfill, and FinnhubQuote throttle modes
```

## Test Files (36 files, ~11,909 lines)

```
StockDataTests.swift             (749L)  Quote calculations, session detection, formatting, market cap, highest close, timeseries, yahooMarketState
StockServiceTests.swift          (1239L) API mocking, fetch operations, extended hours, v7 response decoding, daily analysis, forward P/E, EMA with pre-computed daily, crossover timing, Finnhub quote routing
MarketScheduleTests.swift        (271L)  Holiday calculations, market state, schedules
TickerConfigTests.swift          (829L)  Config load/save, encoding, legacy backward compat, universe field, finnhubApiKey
TickerEditorStateTests.swift     (314L)  Editor state machine, validation
TickerListOperationsTests.swift  (212L)  Pure watchlist function tests
TickerValidatorTests.swift       (406L)  Symbol validation, HTTP mocking
TickerAddErrorTests.swift        (95L)   Error enum and result type tests
MenuBarViewTests.swift           (224L)  SortOption tests, sorting with quotes (market cap, YTD)
MarqueeViewTests.swift           (106L)  Config constants, layer setup, scrolling, ping animation
MenuItemFactoryTests.swift       (141L)  Font tests, disabled/action/submenu item creation
YTDCacheTests.swift              (289L)  Cache load/save, year rollover, DateProvider injection
QuarterlyCacheTests.swift        (481L)  Quarter calculations, cache operations, pruning, quarterStartTimestamp
QuarterlyPanelTests.swift        (1699L) Row computation, sorting, direction toggling, missing data, highlighting, view modes, highest close, forward P/E, price breaks with dates, RSI, EMA, crossover, below-5W, misc stats, universe labels
ColorMappingTests.swift          (52L)   Color name mapping, case insensitivity, NSColor/SwiftUI bridge
NewsServiceTests.swift           (712L)  RSS parsing, deduplication, multi-source fetching
LayoutConfigTests.swift          (97L)   Layout constant validation
RequestLoggerTests.swift         (125L)  Error count/last error queries, clear reset, 429 no-retry, 500 retry
TimerManagerTests.swift          (129L)  Timer lifecycle, delegate callbacks, start/stop
TestUtilities.swift              (59L)   Shared test helpers (MockDateProvider, date creation)
DebugViewModelTests.swift        (119L)  DebugViewModel refresh/clear/endpoint counts/errors-only filter with injected logger
CacheStorageTests.swift          (101L)  Generic cache load/save with MockFileSystem
TickerDisplayBuilderTests.swift  (230L)  Menu bar title, ticker title, highlights, color helpers, highest close
QuoteFetchCoordinatorTests.swift (310L)  Fetch modes, FetchResult correctness, market state extraction, MockStockService
HighestCloseCacheTests.swift     (334L)  Cache load/save, invalidation, daily refresh, missing symbols
ForwardPECacheTests.swift        (255L)  Forward P/E cache load/save, invalidation, missing symbols, empty dict handling
SwingAnalysisTests.swift         (147L)  Swing analysis algorithm: empty, steady, threshold detection, multiple swings, index tracking
SwingLevelCacheTests.swift       (371L)  Swing level cache load/save, invalidation, daily refresh, missing symbols, nil values
RSIAnalysisTests.swift           (97L)   RSI algorithm: empty, insufficient, all gains/losses, alternating, trends, custom period
RSICacheTests.swift              (230L)  RSI cache load/save, missing symbols, daily refresh, clear
EMAAnalysisTests.swift           (189L)  EMA algorithm: empty, insufficient, SMA, known sequence, constant, custom period, trends, weekly crossover detection, weeks-below counting
EMACacheTests.swift              (466L)  EMA cache load/save, missing symbols, daily refresh, sneak peek refresh, clear, nil values, crossover field
SymbolRoutingTests.swift         (71L)   Symbol routing: historical always Yahoo, isFinnhubCompatible, partition splits for quote routing
FinnhubResponseTests.swift       (144L)  Finnhub candle + quote response decoding: valid, no_data, null fields, empty arrays, isValid
ThrottledTaskGroupTests.swift    (129L)  Bounded concurrency: empty, all succeed, nil exclusion, max concurrency, single item, custom delay, Backfill + FinnhubBackfill + FinnhubQuote constants
BackfillSchedulerTests.swift     (423L)  Phase ordering, cancellation, cached symbol skipping, batch notifications, daily analysis distribution, weekly EMA completion
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
├── QuoteFetchCoordinator.swift (QuoteFetchCoordinator, FetchResult)
└── BackfillScheduler.swift (BackfillScheduler, BackfillCaches)

BackfillScheduler.swift
├── StockService.swift (StockServiceProtocol)
├── YTDCache.swift (YTDCacheManager)
├── QuarterlyCache.swift (QuarterlyCacheManager, QuarterCalculation, QuarterInfo)
├── HighestCloseCache.swift (HighestCloseCacheManager)
├── ForwardPECache.swift (ForwardPECacheManager)
├── SwingLevelCache.swift (SwingLevelCacheManager)
├── RSICache.swift (RSICacheManager)
├── EMACache.swift (EMACacheManager)
└── StockData.swift (DailyAnalysisResult, SwingLevelCacheEntry, EMACacheEntry)

StockService.swift
├── StockService+MarketCap.swift (market cap + forward P/E extension)
├── StockService+Finnhub.swift (Finnhub candle API extension)
├── StockService+Historical.swift (historical price + daily analysis with Finnhub routing)
├── StockService+ForwardPE.swift (forward P/E timeseries extension)
├── StockService+EMA.swift (5-day/week EMA with Finnhub routing)
├── ThrottledTaskGroup.swift (bounded concurrency for batch methods)
├── StockData.swift (StockQuote, TradingSession, YahooChartResponse, TradingHours)
└── RequestLogger.swift (LoggingHTTPClient, HTTPClient)

TickerDisplayBuilder.swift
├── StockData.swift (StockQuote, TradingHours)
├── MenuItemFactory.swift (MenuItemFactory)
└── LayoutConfig.swift (LayoutConfig.Ticker)

QuoteFetchCoordinator.swift
├── StockService.swift (StockServiceProtocol)
└── StockData.swift (StockQuote)

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
├── RSIAnalysis.swift (RSIAnalysis)
└── EMAAnalysis.swift (EMAAnalysis)

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

### Bounded Concurrency (ThrottledTaskGroup)
`ThrottledTaskGroup.map()` limits concurrent API calls (configurable concurrency and delay). Four modes: **default** (5 concurrent, 100ms delay) for real-time quote refresh, **Backfill** (1 concurrent, 2s delay) for Yahoo cache population, **FinnhubBackfill** (5 concurrent, 200ms delay) for Finnhub cache population, and **FinnhubQuote** (5 concurrent, 200ms delay, max 50 symbols/cycle) for Finnhub real-time universe quotes. Batch methods partition symbols by source via `SymbolRouting.partition()` and run both API groups in parallel. 429 responses are not retried by `LoggingHTTPClient`.

### Staggered Backfill (BackfillScheduler)
`BackfillScheduler` actor runs a single background `Task` loop that populates caches one symbol at a time with configurable delay (default 4s = ~15 req/min). Phases run in priority order: YTD → daily analysis → weekly EMA → forward P/E → quarterly. Each phase queries the relevant cache for missing symbols and skips already-cached data. Results are saved to disk after each symbol, so progress survives app restarts. `onBatchComplete` callback fires every 10 symbols to update `@Published` properties. Config reload or cache clear cancels the running backfill and restarts with the new symbol set. `BackfillCaches` struct bundles references to all 7 cache actors. First run with ~500 S&P symbols takes ~8.5 hours; subsequent runs only fetch new/missing symbols.

### Symbol Routing (Dual-API Architecture)
`SymbolRouting` enum routes API calls between Finnhub and Yahoo Finance. **Historical data** (candles) always uses Yahoo — Finnhub's candle endpoint requires a paid tier. **Real-time universe quotes** use Finnhub `/quote` for equities/ETFs (AAPL, SPY) and Yahoo for indices (^GSPC) and crypto (BTC-USD). `isFinnhubCompatible()` checks symbol type; `partition()` splits symbol lists for quote routing. When `finnhubApiKey` is nil, all symbols route to Yahoo (graceful degradation).

### Two-Tier Symbol Sets
- `allCacheSymbols` — deduplicated union of watchlist + universe + index symbols. Used by YTD, highest close, swing, RSI, EMA cache fetchers.
- `extraStatsSymbols` — deduplicated union of watchlist + universe. Used by quarterly and forward P/E cache fetchers, and as the symbol list passed to Extra Stats.

### Actors for Thread Safety
- `StockService` — concurrent quote fetching via ThrottledTaskGroup
- `NewsService` — concurrent RSS fetching via TaskGroup
- `RequestLogger` — thread-safe request log storage
- `YTDCacheManager` — thread-safe YTD price cache
- `QuarterlyCacheManager` — thread-safe quarterly price cache
- `HighestCloseCacheManager` — thread-safe highest close price cache
- `ForwardPECacheManager` — thread-safe forward P/E ratio cache
- `SwingLevelCacheManager` — thread-safe swing level (breakout/breakdown) cache
- `RSICacheManager` — thread-safe RSI value cache
- `EMACacheManager` — thread-safe EMA value cache (2 timeframes per symbol)

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
- `EMAAnalysis` — stateless enum with pure 5-period EMA calculation (SMA seed), weekly crossover detection, and weeks-below counting
- `SymbolRouting` — stateless enum with `isFinnhubCompatible(_:)`, `historicalSource(for:finnhubApiKey:)`, and `partition(_:finnhubApiKey:)` for dual-API routing

### Callback Cleanup
`WatchlistEditorState` explicitly clears callbacks to prevent retain cycles. Called in `save()`, `cancel()`, and when window closes.

### HighlightConfig
Batches 5 highlight parameters into a single struct with `resolve()`, `withPingBackground()`, `withPingDisabled()` helpers. Defined in `TickerDisplayBuilder.swift`, used by both MenuBarView and QuarterlyPanelView.

### Generic CacheStorage\<T\>
Eliminates duplicate load/save file I/O in YTDCacheManager, QuarterlyCacheManager, HighestCloseCacheManager, ForwardPECacheManager, SwingLevelCacheManager, RSICacheManager, and EMACacheManager. Single `CacheStorage<T: Codable>` struct handles JSON encoding/decoding, directory creation, and error logging. `CacheTimestamp` enum provides shared ISO8601 formatting and daily refresh logic.

### Legacy Config Decoding
`decodeLegacy()` extension on `KeyedDecodingContainer` handles backward-compatible field names (e.g. `tickers` → `watchlist`, `cycleInterval` → `menuBarRotationInterval`). Two overloads: required (throws) and optional (with default).

## API Integration

### Finnhub Stock Candle API — Historical Prices (Equities/ETFs)
```
GET https://finnhub.io/api/v1/stock/candle?symbol={SYM}&resolution={D|W|M}&from={UNIX}&to={UNIX}&token={KEY}
```

Response: `{"c":[closes...],"t":[timestamps...],"s":"ok"}`. We only use `c` (closes), `t` (timestamps), and `s` (status). Closes are non-nullable `[Double]`. Status `"ok"` = valid data, `"no_data"` = no data for range. Used for daily analysis, highest close, swing levels, RSI, and EMA (weekly) for equity and ETF symbols. Requires `finnhubApiKey` in config. Rate limit: 60 req/min.

### Finnhub Quote API — Real-Time Universe Quotes (Equities/ETFs)
```
GET https://finnhub.io/api/v1/quote?symbol={SYM}
```

Response: `{"c":263.84,"d":-0.51,"dp":-0.1929,"h":264.48,"l":262.29,"o":263.21,"pc":264.35,"t":1771519213}`. Fields: `c` = current price, `pc` = previous close, `d` = change, `dp` = change%. Returns zeros for crypto/unknown symbols. Used for universe equity quotes during market hours (routed via `SymbolRouting.partition()`). Staggered: max 50 symbols per refresh cycle (~60s) to stay under 60 req/min limit. Overflow equity symbols fall back to Yahoo for that cycle. Auth via `X-Finnhub-Token` header.

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

Batch request for symbols via `fetchQuoteFields()`. Symbols chunked into batches of 50 to avoid URL length rejection (important for universe-scale ~500 symbols). Fetched each refresh cycle alongside chart data. Response: `YahooQuoteResponse` → `QuoteResponseData` → `[QuoteResult]`.

### Yahoo Finance Fundamentals Timeseries API — Historical Forward P/E
```
https://query2.finance.yahoo.com/ws/fundamentals-timeseries/v1/finance/timeseries/{SYMBOL}?type=quarterlyForwardPeRatio&period1={P1}&period2={P2}
```

No authentication required. One call per symbol (throttled to 20 concurrent via `ThrottledTaskGroup`). Returns quarterly forward P/E ratios with `asOfDate` (e.g. "2024-12-31") mapped to quarter identifiers (e.g. "Q4-2024"). Response: `YahooTimeseriesResponse` → `TimeseriesResult` → `[TimeseriesData]` → `[ForwardPeEntry]`.

### HTTP Client Architecture
```
HTTPClient (protocol) ─── data(from:) + data(for:) interface
    │
URLSession (conforms) ─── raw network layer
    │
LoggingHTTPClient (wraps HTTPClient)
    ├── Logs all requests to RequestLogger actor
    ├── buildSuccessEntry() extracts headers/body into log entries
    ├── Retry: 1 retry after 0.5s on non-2xx or network error (skips 429)
    ├── Skips retries during pre-market/after-hours
    └── Response body capped at ResponseLimits.maxBodySize (50KB)
    │
StockService, NewsService, YahooSymbolValidator (consumers)
    └── All default to LoggingHTTPClient()
```

Individual request retry — if fetching AAPL, MSFT, GOOGL and MSFT fails, only MSFT retries.

### Smart Fetching (Market Hours Aware)

| Market State | Watchlist | Universe | Index Marquee | Menu Bar |
|--------------|-----------|----------|---------------|----------|
| Closed | Skip | Skip | `alwaysOpenMarkets` | `menuBarAssetWhenClosed` |
| Pre-Market | Fetch | Skip | `alwaysOpenMarkets` | `menuBarAssetWhenClosed` |
| Open | Fetch (15s) | Fetch (~60s) | `indexSymbols` | Cycle through watchlist |
| After-Hours | Fetch | Skip | `alwaysOpenMarkets` | `menuBarAssetWhenClosed` |

Universe refresh only runs while Extra Stats window is visible, every 4th refresh cycle (~60s). Universe equity symbols route to Finnhub `/quote` (max 50/cycle); indices, crypto, and overflow equities use Yahoo chart v8.

### Initial Load vs Subsequent Refreshes

Two-phase strategy controlled by `hasCompletedInitialLoad`:

1. **Initial load** — Fetches ALL symbols (watchlist + universe) regardless of market state. Ensures users see data on weekends. Universe quotes fetched via `ThrottledTaskGroup` (max 20 concurrent).
2. **Subsequent refreshes** — Smart fetching based on market state. Watchlist every 15s, universe every ~60s (4th cycle) while Extra Stats is open and market is open. Only crypto refreshes when closed.

Weekend handling:
- Yahoo API may return "POST" on weekends (from Friday's after-hours)
- App forces `yahooMarketState = "CLOSED"` on weekends
- Extended hours labels (Pre/AH) not shown on weekends

Config reload resets `hasCompletedInitialLoad = false`, clears universe state (`universeQuotes`, `universeMarketCaps`, `universeForwardPEs`), cancels the running backfill, refreshes `@Published` properties from disk caches, and restarts the `BackfillScheduler`.

**Startup cache strategy:** All caches are loaded from disk (no API calls), then `BackfillScheduler` is started to gradually fill missing entries at ~15 req/min. This avoids the burst of hundreds of API calls that triggers Yahoo 429 rate limits with large universes (~500 S&P symbols).

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

Key methods: `loadHighestCloseCache()`, `attachHighestClosesToQuotes()` (fetching consolidated into daily analysis)

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

**Permanent cache:** Quarter-end P/E values are immutable historical facts. No daily refresh. Only fetches on startup for missing symbols or when quarter range changes (new quarter completes). Symbols with no P/E data (API success, no entries) stored as empty `{}` to avoid refetching. API failures (non-200, network error) return `nil` and are NOT cached — they remain "missing" and are retried on the next fetch cycle.

**API:** One timeseries call per symbol for the full 3-year range. Batch fetch via ThrottledTaskGroup (max 20 concurrent).

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

Key methods: `loadSwingLevelCache()` (fetching consolidated into daily analysis)

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

Key methods: `loadRSICache()` (fetching consolidated into daily analysis)

## EMA Tracking

5-period Exponential Moving Average across two timeframes: daily (5-day) and weekly (5-week). Displayed in the Extra Stats "5 EMAs" tab — two side-by-side tables showing symbols whose current price is above the EMA for each timeframe, plus crossover and below-5W tables.

Cached at `~/.stockticker/ema-cache.json`:

```json
{
  "lastUpdated": "2026-02-17T12:00:00Z",
  "entries": {
    "AAPL": { "day": 150.2, "week": 148.5, "weekCrossoverWeeksBelow": 3, "weekBelowCount": null },
    "BTC-USD": { "day": null, "week": null, "weekCrossoverWeeksBelow": null, "weekBelowCount": null }
  }
}
```

**Flow:** App startup loads cache → checks daily freshness → fetches missing symbols → values passed to Extra Stats 5 EMAs tab.

**Invalidation:** Daily refresh clears entries so fresh EMAs are computed from latest bars.

**API:** Two chart v8 calls per symbol:
- Daily: `range=1mo&interval=1d` (~20 bars)
- Weekly: `range=6mo&interval=1wk` (~26 bars)

Both fetched concurrently via `async let`. Batch fetch via `ThrottledTaskGroup` over symbols (max 20 concurrent).

**Algorithm:** `EMAAnalysis.calculate()` — SMA of first `period` values as seed, then iterative EMA with multiplier `2/(period+1)` = 0.3333 for period 5. `EMAAnalysis.detectWeeklyCrossover()` — computes full EMA series, detects most recent weekly close crossing above 5-week EMA after 3+ weeks below (1-2 weeks is chop); returns weeks-below count or nil. `EMAAnalysis.countWeeksBelow()` — computes full EMA series, returns consecutive weeks the last close has been at or below the EMA (nil when above). Crossover detection uses only completed weekly bars via timestamp-based filtering — `completedWeeklyBarCount(timestamps:now:)` excludes bars from the current calendar week. The only exception is the "sneak peek" window: `isCurrentWeekSneakPeek(now:)` returns true on Friday 2PM–4PM ET only, allowing the current week's bar to preview potential crossovers before the week closes. Below-count uses all weekly bars including the current incomplete week, so mid-week drops are reflected immediately.

**Failure resilience:** `fetchEMAEntry` returns `nil` when both EMA values (day, week) are nil (total API failure). `ThrottledTaskGroup.map` excludes nil results, so failed symbols remain "missing" and are retried on the next fetch cycle. Partial success (e.g., daily succeeds but weekly fails) is stored with non-nil fields.

**Cache retry:** Missing EMA and Forward P/E entries are retried in batches of 5 every 4th refresh cycle (~60s). This produces ~15 API calls per cycle (5 EMA × 2 timeframes + 5 Forward P/E) = 0.25 req/sec sustained rate.

**Sneak peek refresh:** On Friday 2-4 PM ET, `needsSneakPeekRefresh()` triggers a re-fetch of weekly EMA data every 5 minutes. This ensures crossover/below-count detection includes the current week's incomplete bar during the sneak peek window (`isCurrentWeekSneakPeek` in StockService+EMA.swift) and stays current as prices move. Daily EMAs are preserved from the existing cache to avoid redundant API calls.

Key methods: `loadEMACache()`, `refreshEMAForSneakPeek()` (daily EMA consolidated into daily analysis; weekly fetched separately)

## Consolidated Daily Analysis

Four per-symbol daily-interval API calls (highest close, swing levels, RSI, daily EMA) are consolidated into a single chart v8 call via `DailyAnalysisResult` and `fetchDailyAnalysis(symbol:period1:period2:)`. This reduces ~1,500 API calls per daily refresh for 500 universe symbols.

**`DailyAnalysisResult`** bundles all 4 data points from one `period1={3yr}&period2={now}&interval=1d` response:
- `highestClose` — `max()` of all valid closes
- `swingLevelEntry` — `SwingAnalysis.analyze()` with timestamps for date formatting
- `rsi` — `RSIAnalysis.calculate()` (750 bars gives better warm-up than 250)
- `dailyEMA` — `EMAAnalysis.calculate()` (converges identically with more data)

**Cache coordination:** `fetchMissingDailyAnalysis()` computes the union of missing symbols across all 4 caches, makes ONE `batchFetchDailyAnalysis` call, then distributes results to individual cache actors. Daily EMA values are passed to `batchFetchEMAValues(symbols:dailyEMAs:)` to skip the daily chart call during weekly EMA fetching.

**`refreshDailyAnalysisIfNeeded()`** checks all 4 caches for daily staleness, clears whichever need it, then calls `fetchMissingDailyAnalysis()`.

**Market state optimization:** `QuoteFetchCoordinator.extractMarketState(from:symbol:)` extracts `yahooMarketState` from the SPY quote already being fetched, eliminating a redundant `fetchMarketState("SPY")` call every 15s refresh. `StockQuote.yahooMarketState` stores the raw Yahoo market state string from the chart v8 meta response.

Key methods: `fetchDailyAnalysis()`, `batchFetchDailyAnalysis()`, `fetchMissingDailyAnalysis()`, `refreshDailyAnalysisIfNeeded()`, `extractMarketState()`

## Extra Stats (Cmd+Opt+Q)

Standalone window with six view modes (segmented picker): **Since Quarter** shows percent change from each quarter's end to current price; **During Quarter** shows percent change within each quarter (start to end); **Forward P/E** shows historical forward P/E ratios per quarter end; **Price Breaks** shows two headed sub-tables — Breakout (percent from highest significant high) and Breakdown (percent from lowest significant low) via swing analysis; **5 EMAs** shows tables of symbols above their 5-day and 5-week EMAs with % above, plus crossover and below-5W tables; **Misc Stats** shows aggregate statistics across the watchlist (e.g., % of symbols within 5% of their highest close). Uses 12 most recent completed quarters (3 years). Cached at `~/.stockticker/quarterly-cache.json`:

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

**Fetching strategy:** Per-quarter sequential, per-symbol parallel via ThrottledTaskGroup (max 20 concurrent). Cache saved after each quarter (preserves progress if interrupted). First run scales with symbol count (~500 symbols x 13 quarters for full universe); subsequent runs only fetch new symbols or newly completed quarters.

**Universe support:** Extra Stats always displays `extraStatsSymbols` (deduplicated union of watchlist + universe). Quotes are merged from both `quotes` (watchlist) and `universeQuotes` (universe-only symbols), with watchlist taking precedence for overlapping symbols. Misc Stats labels adapt: "% of symbols" when universe active, "% of watchlist" otherwise.

**View modes:** `QuarterlyViewMode` enum (in `QuarterlyPanelModels`) — `.sinceQuarter` computes `(currentPrice - Q_end) / Q_end`, `.duringQuarter` computes `(Q_end - Q_prev_end) / Q_prev_end`, `.forwardPE` shows raw P/E values per quarter end, `.priceBreaks` shows two independently sorted tables (breakoutRows and breakdownRows) with Symbol, Date, and % columns, `.emas` shows two independently sorted tables (emaDayRows, emaWeekRows) with Symbol and % columns plus a crossover table, `.miscStats` shows non-sortable aggregate statistics (e.g., % of symbols within 5% of High). A 13th quarter is fetched as a reference price so during-quarter yields data for all 12 displayed quarters. View model (`QuarterlyPanelViewModel`) stores data (`storedWatchlist`, `storedQuotes`, `storedQuarterPrices`, `storedForwardPEData`, `storedCurrentForwardPEs`, `storedSwingLevelEntries`, `storedRSIValues`, `storedEMAEntries`) so rows recompute when toggling modes via `switchMode()`.

**Live updates:** During market hours, percent changes update each refresh cycle (~15s) using `quote.price` (regular market price, never pre/post). Format: `+12.34%` / `-5.67%` / `--` (missing). Color-coded green/red/secondary.

**Sortable columns:** Symbol, High/Current (% from highest close in price modes, current forward P/E in P/E mode), and each quarter column. Click header to sort ascending; click again to toggle descending. Switching columns resets to ascending. Nil values sort before any value. Column headers are pinned during vertical scrolling via `LazyVStack(pinnedViews: [.sectionHeaders])`.

**Row highlighting:** Config-highlighted symbols (`config.highlightedSymbols`) get a persistent colored background row using `highlightColor` and `highlightOpacity`. These cannot be toggled off by clicking. Non-config rows can be click-toggled on/off for readability. `ColorMapping` enum in AppInfrastructure.swift provides shared color name mapping for both NSColor and SwiftUI Color. Click-toggled highlights persist across all view modes in the Extra Stats window — the `highlightedSymbols` set is shared by the view model, so highlighting a symbol in one mode (e.g., 5 EMAs) keeps it highlighted when switching to another mode (e.g., Since Quarter, Price Breaks). In multi-table modes, the highlight appears across all sibling tables simultaneously. This lets users track a symbol's stats across every view.

**Forward P/E mode:** Filters to equity symbols only (symbols with at least one non-empty P/E entry). Shows "Current" column (current forward P/E from v7 API, always secondary color) and quarter columns (historical P/E as of quarter end). Color: green when P/E decreased vs prior quarter, red when increased, secondary when no prior value.

**Price Breaks mode:** Combined mode (`isPriceBreaksMode`) with side-by-side layout — "Breakout" table on the left, "Breakdown" table on the right, each independently scrollable with its own title and column headers. Sorted independently. No High column, no quarter columns. Columns: Symbol (sortable), Date (sortable, "M/d/yy" format), % (sortable), RSI (sortable, daily RSI-14 color-coded >70 red / <30 green). Symbols with both breakout and breakdown data appear in both tables with unique IDs (`symbol-breakout`, `symbol-breakdown`). Header shows "X breakout, Y breakdown" count.

**5 EMAs mode:** Four-column layout (`isEMAsMode`) — "5-Day", "5-Week", "5W Cross", and "Below 5W" tables side by side. First two tables show symbols whose current price is above the respective 5-period EMA. "5W Cross" shows symbols whose most recent weekly close crossed above the 5-week EMA after 3+ weeks below; "Wks" column shows weeks-below count (green). "Below 5W" shows symbols at or below the 5-week EMA for 3+ consecutive weeks (including current incomplete week); "Wks" column shows weeks-below count (green). Columns: Symbol (sortable), % or Wks (sortable). Sorted independently. Header shows "X day, Y week, Z cross, W below" count. Unique IDs use `symbol-ema-day`, `symbol-ema-week`, `symbol-ema-cross`, `symbol-ema-below`.

Key methods: `loadQuarterlyCache()`, `fetchMissingQuarterlyPrices()`, `showQuarterlyPanel()`

## News Headlines

Actor-based `NewsService` fetches from CNBC RSS via TaskGroup. Requests include a user-agent header (required to avoid 429/403 responses). `RSSParser` (XMLParserDelegate) parses XML with dual date format support (RFC 2822 + ISO 8601). Headlines deduplicated via Jaccard word similarity (threshold: 0.6). Cache-busted with timestamp query parameter. Up to 5 clickable headlines displayed with proportional font; top-from-source headlines use bold variant.

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
| `universe` | `[String]` | `[]` |
| `finnhubApiKey` | `String?` | `nil` |
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
3. **DRY** — Single source of truth; `decodeLegacy`, `CacheStorage<T>`, `ThrottledTaskGroup` (+ `Backfill`/`FinnhubBackfill`/`FinnhubQuote` constants), `HighlightConfig`, `ColorMapping`, shared `TradingHours` constants, `APIEndpoints`, `SymbolRouting`
4. **Single Responsibility** — Extracted SortOption, MarqueeView, MenuItemFactory, MenuBarController+Cache, TimerManager, TickerDisplayBuilder, QuoteFetchCoordinator, StockService extensions, pure WatchlistOperations
5. **Boy Scout Rule** — Leave code cleaner than found
6. **Minimize Comments** — Comments explain *why* (intent, warnings), never *what*
7. **No Side Effects** — Pure functions for sorting, formatting, operations
8. **Fail Fast** — Guard clauses, early returns, error logging on file I/O
9. **KISS/YAGNI** — No premature abstraction
10. **Write Tests** — Protocol-based DI enables comprehensive testing; 33 test files with mock doubles
