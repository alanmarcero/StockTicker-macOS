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

## Source Files (42 files, ~8,781 lines)

```
StockTickerApp.swift             (19L)   Entry point, creates MenuBarController, single-instance guard
MenuBarView.swift                (982L)  Main controller: menu bar UI, state management, two-tier universe fetching with Finnhub routing, scanner data fetch trigger
MenuBarController+Cache.swift    (499L)  Extension: YTD, quarterly, forward P/E, consolidated daily analysis (watchlist-scoped, re-entrancy guarded), sneak peek EMA refresh (watchlist-scoped), market close daily EMA refresh, backfill scheduler coordination, and market cap cache coordination with shared helpers
BackfillScheduler.swift          (238L)  Staggered backfill actor: prioritized cache population (~15 req/min) with cancellation, BackfillCaches struct
TimerManager.swift               (101L)  Timer lifecycle management with delegate pattern
StockService.swift               (249L)  Yahoo Finance API client (actor), chart v8 methods, SymbolRouting enum
StockService+MarketCap.swift     (95L)   Extension: market cap + forward P/E via v7 quote API with crumb auth, batched in chunks of 50
StockService+Historical.swift    (388L)  Extension: historical price fetching (YTD, quarterly, daily analysis consolidation) with Finnhub routing + Yahoo fallback
StockService+ForwardPE.swift     (51L)   Extension: historical forward P/E ratios via timeseries API
StockService+Finnhub.swift       (83L)   Extension: Finnhub candle API fetch methods (daily candles, closes, historical close) + real-time quote fetch
StockService+EMA.swift           (224L)  Extension: 5-day/week EMA fetch + weekly crossover + crossdown + below-count + above-count with Finnhub routing + Yahoo fallback
StockData.swift                  (553L)  Data models: StockQuote, TradingSession, TradingHours, Formatting, v7/timeseries response models, FinnhubCandleResponse, FinnhubQuoteResponse
MarketSchedule.swift             (291L)  NYSE holiday/hours calculation, MarketState enum
TickerConfig.swift               (318L)  Config loading/saving, protocols, legacy backward compat, universe field, finnhubApiKey, scannerBaseURL
TickerEditorView.swift           (541L)  SwiftUI watchlist editor, symbol validation, pure operations
RequestLogger.swift              (339L)  API request logging (actor), LoggingHTTPClient with retry (skips 429), 1-hour counters, errors-only entries (last 100), Scanner endpoint classification
DebugWindow.swift                (315L)  API errors window with endpoint filter buttons, injected RequestLogger
SortOption.swift                 (58L)   Sort option enum with config parsing and sorting logic
MarqueeView.swift                (126L)  Scrolling index marquee NSView with ping animation
MenuItemFactory.swift            (31L)   Factory for creating styled NSMenuItems and font constants
ScannerService.swift             (119L)  AWS scanner API client (actor), fetches EMA crossover/crossdown/above/below data from CloudFront, feature-flagged via scannerBaseURL
NewsService.swift                (135L)  RSS feed fetcher for financial news (actor)
NewsData.swift                   (148L)  NewsItem model, RSSParser, NewsSource enum
YTDCache.swift                   (99L)   Year-to-date price cache manager (actor)
QuarterlyCache.swift             (217L)  Quarter calculation helpers, quarterly price cache (actor), no-data symbol tracking
QuarterlyPanelModels.swift        (79L)   Extra Stats data models: QuarterlyRow, MiscStat, QuarterlyViewMode, QuarterlySortColumn, QuarterlyPanelData DTO
QuarterlyPanelView.swift         (630L)  Extra Stats window: SwiftUI view, controller
QuarterlyPanelViewModel.swift     (474L)  Extra Stats view model: row building, sorting, highlights, misc stats, universe labels, scanner data merge
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
EMAAnalysis.swift                (123L)  Pure 5-period EMA algorithm (SMA seed + iterative) + weekly crossover/crossdown detection + weeks-below counting + periods-above counting
EMACache.swift                   (171L)  EMA cache manager (actor), daily refresh, market close refresh, sneak peek refresh, 2 timeframes + crossover + crossdown + below-count + above-count per symbol
ThrottledTaskGroup.swift         (50L)   Bounded concurrency utility with Backfill, FinnhubBackfill, and FinnhubQuote throttle modes
```

## Test Files (37 files, ~13,043 lines)

All source files have corresponding test files. Key test files: `StockServiceTests.swift` (1263L), `QuarterlyPanelTests.swift` (1895L), `TickerConfigTests.swift` (881L), `StockDataTests.swift` (749L), `NewsServiceTests.swift` (712L), `EMACacheTests.swift` (622L), `QuarterlyCacheTests.swift` (632L), `ScannerServiceTests.swift` (276L). Shared helpers in `TestUtilities.swift` (MockDateProvider, date creation).

## Design Patterns

### Dependency Injection (Protocol-Based)
All major components use protocols for testability: `StockServiceProtocol` / `HTTPClient`, `NewsServiceProtocol`, `ScannerServiceProtocol`, `TimerManagerDelegate`, `FileSystemProtocol` / `WorkspaceProtocol`, `SymbolValidator`, `DateProvider` (injectable time used by MarketSchedule and all 7 cache managers), `URLOpener` / `WindowProvider`.

### Bounded Concurrency (ThrottledTaskGroup)
Four modes: **default** (5 concurrent, 100ms) for real-time quotes, **Backfill** (1 concurrent, 2s) for Yahoo cache population, **FinnhubBackfill** (5 concurrent, 200ms), **FinnhubQuote** (5 concurrent, 200ms, max 50/cycle). `SymbolRouting.partition()` splits symbols by API source.

### Two-Tier Symbol Sets
- `allCacheSymbols` — watchlist + universe + index symbols. Used by YTD, highest close, swing, RSI, EMA caches.
- `extraStatsSymbols` — watchlist + universe. Used by quarterly, forward P/E caches, and Extra Stats.

### Key Shared Patterns
- `CacheStorage<T: Codable>` — generic file I/O for all 7 cache actors
- `HighlightConfig` — batches highlight parameters for MenuBarView and QuarterlyPanelView
- `QuarterlyPanelData` — DTO bundling 9 data fields passed to Extra Stats view model/controller
- All actors for thread safety; `@MainActor` for state management classes

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
| `scannerBaseURL` | `String` | `""` (empty = disabled) |
| `showNewsHeadlines` | `Bool` | `true` |
| `newsRefreshInterval` | `Int` (seconds) | `300` |

Saved with `prettyPrinted` and `sortedKeys`. Supports legacy field names via `decodeLegacy()`.

## Common Tasks

- **New config option:** Add to `WatchlistConfig` struct → `init(from decoder:)` with `decodeIfPresent` → `encode(to:)` → UI in `MenuBarController`
- **New menu item:** `setupMenu()` or `createXxxSubmenu()` → `@objc` action → wire target/action
- **Ticker display:** `TickerDisplayBuilder` static methods (`menuBarTitle`, `tickerTitle`, `appendYTDSection`, etc.)
- **API data source:** `StockService.fetchChartData()` + response models in `StockData.swift`

## AWS EMA Scanner (`aws-scanner/`)

Serverless weekly scanner: detects 5-week EMA crossovers/crossdowns and counts days/weeks above EMA across ~10,000 US equities/ETFs. Ports `EMAAnalysis.swift` to Python. ~2,164 lines.

**Architecture:** EventBridge (Friday 2 PM ET) → Orchestrator Lambda → SQS → Worker Lambda (reserved concurrency 1) → S3 → CloudFront.

**Verification:** `cd aws-scanner && python3 -m pytest tests/ -v`

**Deployment:** GitHub Actions on `aws-scanner/**` changes. Manual: `aws lambda invoke --function-name ema-scanner-orchestrator /dev/stdout`
