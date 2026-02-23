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

## Source Files (41 files, ~8,451 lines)

```
StockTickerApp.swift             (19L)   Entry point, creates MenuBarController, single-instance guard
MenuBarView.swift                (955L)  Main controller: menu bar UI, state management, two-tier universe fetching with Finnhub routing
MenuBarController+Cache.swift    (486L)  Extension: YTD, quarterly, forward P/E, consolidated daily analysis, sneak peek EMA refresh, backfill scheduler coordination, and market cap cache coordination with shared helpers
BackfillScheduler.swift          (236L)  Staggered backfill actor: prioritized cache population (~15 req/min) with cancellation, BackfillCaches struct
TimerManager.swift               (101L)  Timer lifecycle management with delegate pattern
StockService.swift               (249L)  Yahoo Finance API client (actor), chart v8 methods, SymbolRouting enum
StockService+MarketCap.swift     (88L)   Extension: market cap + forward P/E via v7 quote API with crumb auth, batched in chunks of 50
StockService+Historical.swift    (388L)  Extension: historical price fetching (YTD, quarterly, daily analysis consolidation) with Finnhub routing + Yahoo fallback
StockService+ForwardPE.swift     (51L)   Extension: historical forward P/E ratios via timeseries API
StockService+Finnhub.swift       (82L)   Extension: Finnhub candle API fetch methods (daily candles, closes, historical close) + real-time quote fetch
StockService+EMA.swift           (223L)  Extension: 5-day/week EMA fetch + weekly crossover + below-count + above-count with Finnhub routing + Yahoo fallback
StockData.swift                  (553L)  Data models: StockQuote, TradingSession, TradingHours, Formatting, v7/timeseries response models, FinnhubCandleResponse, FinnhubQuoteResponse
MarketSchedule.swift             (291L)  NYSE holiday/hours calculation, MarketState enum
TickerConfig.swift               (312L)  Config loading/saving, protocols, legacy backward compat, universe field, finnhubApiKey
TickerEditorView.swift           (541L)  SwiftUI watchlist editor, symbol validation, pure operations
RequestLogger.swift              (334L)  API request logging (actor), LoggingHTTPClient with retry (skips 429), 1-hour counters, errors-only entries (last 100)
DebugWindow.swift                (315L)  API errors window with endpoint filter buttons, injected RequestLogger
SortOption.swift                 (58L)   Sort option enum with config parsing and sorting logic
MarqueeView.swift                (126L)  Scrolling index marquee NSView with ping animation
MenuItemFactory.swift            (31L)   Factory for creating styled NSMenuItems and font constants
NewsService.swift                (134L)  RSS feed fetcher for financial news (actor)
NewsData.swift                   (148L)  NewsItem model, RSSParser, NewsSource enum
YTDCache.swift                   (99L)   Year-to-date price cache manager (actor)
QuarterlyCache.swift             (187L)  Quarter calculation helpers, quarterly price cache (actor)
QuarterlyPanelModels.swift        (65L)   Extra Stats data models: QuarterlyRow, MiscStat, QuarterlyViewMode, QuarterlySortColumn
QuarterlyPanelView.swift         (635L)  Extra Stats window: SwiftUI view, controller
QuarterlyPanelViewModel.swift     (428L)  Extra Stats view model: row building, sorting, highlights, misc stats, universe labels
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
EMAAnalysis.swift                (97L)   Pure 5-period EMA algorithm (SMA seed + iterative) + weekly crossover detection + weeks-below counting + periods-above counting
EMACache.swift                   (130L)  EMA cache manager (actor), daily refresh, sneak peek refresh, 2 timeframes + crossover + below-count + above-count per symbol
ThrottledTaskGroup.swift         (50L)   Bounded concurrency utility with Backfill, FinnhubBackfill, and FinnhubQuote throttle modes
```

## Test Files (36 files, ~12,158 lines)

All source files have corresponding test files. Key test files: `StockServiceTests.swift` (1263L), `QuarterlyPanelTests.swift` (1717L), `TickerConfigTests.swift` (829L), `StockDataTests.swift` (749L), `NewsServiceTests.swift` (712L), `EMACacheTests.swift` (466L), `QuarterlyCacheTests.swift` (481L). Shared helpers in `TestUtilities.swift` (MockDateProvider, date creation).

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

### Constants & Pure Functions
All magic numbers extracted into private namespaced enums (e.g., `Layout`, `Timing`, `TradingHours`, `Formatting`, `LayoutConfig`). Pure stateless enums: `WatchlistOperations`, `SortOption`, `QuarterCalculation`, `TickerDisplayBuilder`, `QuoteFetchCoordinator`, `SwingAnalysis`, `RSIAnalysis`, `EMAAnalysis` (SMA seed + iterative EMA, crossover detection, weeks-below counting, periods-above counting), `SymbolRouting`, `ColorMapping`, `Formatting`.

### Shared Patterns
- `CacheStorage<T: Codable>` — generic cache file I/O used by all 7 cache actors. `CacheTimestamp` provides ISO8601 formatting and daily refresh logic.
- `HighlightConfig` — batches 5 highlight parameters; used by MenuBarView and QuarterlyPanelView.
- `decodeLegacy()` — backward-compatible config field name decoding (`tickers` → `watchlist`).
- `WatchlistEditorState` clears callbacks in `save()`/`cancel()` to prevent retain cycles.

## API Integration

### APIs
- **Finnhub Candle** — `GET /api/v1/stock/candle?symbol={SYM}&resolution={D|W}&from={UNIX}&to={UNIX}`. Returns `c` (closes), `t` (timestamps), `s` (status). Used for daily analysis + weekly EMA. Rate limit: 60 req/min.
- **Finnhub Quote** — `GET /api/v1/quote?symbol={SYM}`. Real-time universe equity quotes. Max 50/cycle, overflow falls back to Yahoo.
- **Yahoo Chart v8** — `GET /v8/finance/chart/{SYM}?interval=1m&range=1d&includePrePost=true`. Price data for watchlist + indices + crypto.
- **Yahoo Quote v7** — `GET /v7/finance/quote?symbols={SYMS}&crumb={CRUMB}`. Market cap + forward P/E. Requires crumb/cookie auth (auto-managed). Batched in chunks of 50.
- **Yahoo Timeseries** — `GET /ws/fundamentals-timeseries/v1/finance/timeseries/{SYM}?type=quarterlyForwardPeRatio`. Historical forward P/E ratios. No auth required.

### HTTP Client
`LoggingHTTPClient` wraps `HTTPClient` protocol (conformed by URLSession). Logs all requests to `RequestLogger` actor. Retry: 1 retry after 0.5s on non-2xx (skips 429, skips during pre/after-hours). Body capped at 50KB.

### Fetching Strategy

**Market-aware:** Open = fetch watchlist (30s) + universe (~120s, 4th cycle). Pre/After-hours = watchlist only. Closed = skip (crypto only via `alwaysOpenMarkets`). Universe refresh only while Extra Stats visible.

**Initial load** fetches ALL symbols regardless of market state (ensures weekend data). Subsequent refreshes use smart fetching. Config reload resets `hasCompletedInitialLoad`, clears universe state, restarts `BackfillScheduler`.

**Startup:** Caches loaded from disk (no API calls), then `BackfillScheduler` fills missing entries at ~15 req/min to avoid Yahoo 429s.

**Extended hours:** `calculateExtendedHoursData()` computes change from regular price to latest indicator price; only populates above `TradingHours.extendedHoursPriceThreshold`. Weekend: forces `yahooMarketState = "CLOSED"`, no Pre/AH labels.

## Caches (`~/.stockticker/`)

All caches are actor-based, use `CacheStorage<T>` for file I/O, and inject `DateProvider` for testability. Caches load from disk on startup (no API calls); missing entries filled by `BackfillScheduler`.

| Cache | File | Invalidation | Key Fields |
|-------|------|-------------|------------|
| **YTD** | `ytd-cache.json` | Year rollover | `prices: {symbol: Double}` |
| **Quarterly** | `quarterly-cache.json` | New quarter completes | `quarters: {qId: {symbol: Double}}` |
| **Highest Close** | `highest-close-cache.json` | Quarter range + daily | `prices: {symbol: Double}` (max close over 3yr) |
| **Forward P/E** | `forward-pe-cache.json` | Quarter range only | `symbols: {symbol: {qId: Double}}` (permanent, no daily refresh) |
| **Swing Level** | `swing-level-cache.json` | Quarter range + daily | `entries: {symbol: {breakoutPrice, breakoutDate, breakdownPrice, breakdownDate}}` |
| **RSI** | `rsi-cache.json` | Daily | `values: {symbol: Double}` (RSI-14, Wilder's smoothing) |
| **EMA** | `ema-cache.json` | Daily | See EMA Tracking below |

**Forward P/E special:** Immutable historical facts. API failures return `nil` (not cached, retried). API success with no data stored as `{}` to avoid refetching.

## EMA Tracking

5-period EMA across daily (5-day) and weekly (5-week) timeframes. `EMACacheEntry` fields: `day`, `week`, `weekCrossoverWeeksBelow`, `weekBelowCount`, `dayAboveCount`, `weekAboveCount` (all optional). Daily invalidated daily; API: `range=1mo&interval=1d` + `range=6mo&interval=1wk` per symbol.

**Algorithm:** `EMAAnalysis.calculate()` — SMA seed + iterative EMA (multiplier `2/(period+1)`). `detectWeeklyCrossover()` — cross above 5W EMA after 3+ weeks below. `countWeeksBelow()` — consecutive weeks at/below EMA. `countPeriodsAbove()` — consecutive periods strictly above EMA. Crossover uses completed weekly bars only; `isCurrentWeekSneakPeek(now:)` allows Friday 2-4 PM ET preview.

**Sneak peek:** Friday 2-4 PM ET, `needsSneakPeekRefresh()` re-fetches weekly EMA every 5 min. Daily EMAs preserved from cache.

**Retry:** Missing EMA/Forward P/E retried in batches of 5 every ~120s. `fetchEMAEntry` returns nil on total failure (retried next cycle).

## Consolidated Daily Analysis

One chart v8 call (`interval=1d`, 3yr range) per symbol produces `DailyAnalysisResult` with 5 data points: `highestClose`, `swingLevelEntry`, `rsi`, `dailyEMA`, `dailyAboveCount`. Reduces ~1,500 API calls to ~500 for universe symbols. `fetchMissingDailyAnalysis()` unions missing symbols across 4 caches, fetches once, distributes results. Daily EMA values + above counts passed to `batchFetchEMAValues()` to skip redundant daily fetch during weekly EMA phase. Market state extracted from SPY quote via `QuoteFetchCoordinator.extractMarketState()`.

## Extra Stats (Cmd+Opt+Q)

Standalone window with six view modes via segmented picker. Uses 12 most recent completed quarters (3 years). Displays `extraStatsSymbols` (watchlist + universe). Sortable columns with pinned headers. Config-highlighted symbols get persistent colored background (can't be toggled off); non-config rows click-toggleable. Highlights persist across all view modes.

**View modes** (`QuarterlyViewMode`):
- **Since Quarter** — `(currentPrice - Q_end) / Q_end`
- **During Quarter** — `(Q_end - Q_prev_end) / Q_prev_end` (13th quarter fetched as reference)
- **Forward P/E** — historical P/E per quarter end, equity symbols only. Green = decreased, red = increased.
- **Price Breaks** — side-by-side Breakout/Breakdown tables with Symbol, Date ("M/d/yy"), %, RSI columns. IDs: `symbol-breakout`/`symbol-breakdown`.
- **5 EMAs** — four tables: "5-Day" (days above as "12d"), "5-Week" (weeks above as "4w"), "5W Cross" (crossover weeks-below), "Below 5W" (weeks below 3+). Integer+suffix in green. IDs: `symbol-ema-day`/`-week`/`-cross`/`-below`.
- **Misc Stats** — aggregate statistics (e.g., % of symbols within 5% of High).

View model stores data so rows recompute on mode toggle via `switchMode()`. Live updates every ~30s using `quote.price` (never pre/post).

## Menu Bar Features

Rotates watchlist symbols at `menuBarRotationInterval` during regular hours; shows `menuBarAssetWhenClosed` otherwise. Dropdown: market status dot, countdown timer, index marquee (`MarqueeView` ~32px/sec), news headlines (CNBC RSS, Jaccard dedup), ticker list with `HighlightConfig`, submenus (Edit Watchlist, Extra Stats, Config, Sort By, API Errors).

Color helpers: `priceChangeColor()`, `ColorMapping.nsColor(from:)`/`.color(from:)`, `StockQuote` extensions (`displayColor`, `ytdColor`, `highestCloseColor`). Symbol validation via `YahooSymbolValidator`. API Errors window (Cmd+Opt+D): last 100 errors, 1-hour counters, auto-refresh.

## Configuration

Location: `~/.stockticker/config.json` (auto-created on first launch)

| Field | Type | Default |
|-------|------|---------|
| `watchlist` | `[String]` (max 128) | 40+ symbols |
| `menuBarRotationInterval` | `Int` (seconds) | `5` |
| `refreshInterval` | `Int` (seconds) | `30` |
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

## Common Tasks

- **New config option:** Add to `WatchlistConfig` struct → `init(from decoder:)` with `decodeIfPresent` → `encode(to:)` → UI in `MenuBarController`
- **New menu item:** `setupMenu()` or `createXxxSubmenu()` → `@objc` action → wire target/action
- **Ticker display:** `TickerDisplayBuilder` static methods (`menuBarTitle`, `tickerTitle`, `appendYTDSection`, etc.)
- **API data source:** `StockService.fetchChartData()` + response models in `StockData.swift`

## AWS EMA Scanner (`aws-scanner/`)

Serverless weekly scanner: detects 5-week EMA crossovers and counts consecutive days/weeks above EMA across ~10,000 US equities/ETFs. Ports `EMAAnalysis.swift` to Python. ~2,101 lines (4 source, 5 test, 9 Terraform, 1 workflow).

**Architecture:** EventBridge (Friday 2 PM ET) → Orchestrator Lambda (chunks 50, enqueues SQS) → Worker Lambda (reserved concurrency 1, sequential, 180s timeout) → S3 (batch + aggregated results) → CloudFront.

**Worker flow:** Per symbol: fetch daily candles (`range=1mo&interval=1d`) + weekly candles (`range=6mo&interval=1wk`), compute crossover/below/above counts. Partial success OK (daily fail still processes weekly and vice versa). Both fail → error. Returns 5-tuple: `(crossovers, below, dayAbove, weekAbove, errors)`.

**Output files:** `results/latest.json` (crossovers), `results/latest-below.json` (below 3+ weeks), `results/latest-above.json` (day/week above counts sorted by count desc), `results/{date}.json` (archive).

**Key decisions:** Reserved concurrency 1 respects Yahoo rate limits. 1s sleep between symbols. Stdlib only (urllib, json). Below threshold = 3 weeks. Sneak peek always true (runs Friday 2 PM).

**Key functions:** `ema.count_periods_above()` — consecutive periods where close > EMA (strict), from most recent bar backwards. `yahoo.fetch_daily_candles()` — daily chart data for above-count computation.

**Verification:** `cd aws-scanner && python3 -m pytest tests/ -v`

**Deployment:** GitHub Actions on `aws-scanner/**` changes. Secrets: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION`, `TF_STATE_BUCKET`, `TF_LOCK_TABLE`. Manual: `aws lambda invoke --function-name ema-scanner-orchestrator /dev/stdout`

**Symbol list:** `symbols/us-equities.txt` (~10,096). Sources: NASDAQ Screener API, SEC EDGAR Company Tickers, curated ETF list. Filter: remove warrants/units/rights/preferred/test symbols, convert `/` to `.`, deduplicate.
