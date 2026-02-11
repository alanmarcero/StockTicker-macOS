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

## Source Files (19 files, ~4,781 lines)

```
StockTickerApp.swift             (12L)   Entry point, creates MenuBarController
MenuBarView.swift                (1023L) Main controller: menu bar UI, timers, state, display styling
MenuBarController+Cache.swift    (87L)   Extension: YTD and quarterly cache coordination methods
StockService.swift               (259L)  Yahoo Finance API client (actor)
StockData.swift                  (381L)  Data models: StockQuote, TradingSession, TradingHours, API types
MarketSchedule.swift             (291L)  NYSE holiday/hours calculation, MarketState enum
TickerConfig.swift               (375L)  Config loading/saving, OpaqueContainerView, ColorMapping, protocols
TickerEditorView.swift           (541L)  SwiftUI watchlist editor, symbol validation, pure operations
RequestLogger.swift              (248L)  API request logging (actor), LoggingHTTPClient with retry
DebugWindow.swift                (251L)  Debug window with copy buttons for URL/request/response
SortOption.swift                 (58L)   Sort option enum with config parsing and sorting logic
MarqueeView.swift                (126L)  Scrolling index marquee NSView with ping animation
MenuItemFactory.swift            (31L)   Factory for creating styled NSMenuItems and font constants
NewsService.swift                (130L)  RSS feed fetcher for financial news (actor)
NewsData.swift                   (153L)  NewsItem model, RSSParser, NewsSource enum
YTDCache.swift                   (130L)  Year-to-date price cache manager (actor)
QuarterlyCache.swift             (206L)  Quarter calculation helpers, quarterly price cache (actor)
QuarterlyPanelView.swift         (402L)  Quarterly performance window: view model, SwiftUI view, controller
LayoutConfig.swift               (77L)   Centralized layout constants
```

## Test Files (18 files, ~5,427 lines)

```
StockDataTests.swift          (475L)  Quote calculations, session detection, formatting
StockServiceTests.swift       (288L)  API mocking, fetch operations, extended hours
MarketScheduleTests.swift     (290L)  Holiday calculations, market state, schedules
TickerConfigTests.swift       (714L)  Config load/save, encoding, legacy backward compat
TickerEditorStateTests.swift  (314L)  Editor state machine, validation
TickerListOperationsTests.swift (212L) Pure watchlist function tests
TickerValidatorTests.swift    (406L)  Symbol validation, HTTP mocking
TickerAddErrorTests.swift     (95L)   Error enum and result type tests
MenuBarViewTests.swift        (202L)  SortOption tests, sorting with quotes (including YTD)
MarqueeViewTests.swift        (106L)  Config constants, layer setup, scrolling, ping animation
MenuItemFactoryTests.swift    (141L)  Font tests, disabled/action/submenu item creation
YTDCacheTests.swift           (360L)  Cache load/save, year rollover, DateProvider injection
QuarterlyCacheTests.swift     (494L)  Quarter calculations, cache operations, pruning
QuarterlyPanelTests.swift     (459L)  Row computation, sorting, direction toggling, missing data, highlighting, view modes
ColorMappingTests.swift       (52L)   Color name mapping, case insensitivity, NSColor/SwiftUI bridge
NewsServiceTests.swift        (832L)  RSS parsing, deduplication, multi-source fetching
LayoutConfigTests.swift       (98L)   Layout constant validation
TestUtilities.swift           (59L)   Shared test helpers (MockDateProvider, date creation)
```

## File Dependencies

```
StockTickerApp.swift
└── MenuBarView.swift (MenuBarController)

MenuBarView.swift (MenuBarController)
├── MenuBarController+Cache.swift (cache coordination extension)
├── StockService.swift (StockServiceProtocol)
├── NewsService.swift (NewsServiceProtocol)
├── TickerConfig.swift (WatchlistConfigManager, WatchlistConfig, ColorMapping)
├── MarketSchedule.swift (MarketSchedule, MarketState)
├── StockData.swift (StockQuote, TradingSession, TradingHours)
├── SortOption.swift (SortOption)
├── MarqueeView.swift (MarqueeView, MarqueeConfig)
├── MenuItemFactory.swift (MenuItemFactory)
├── YTDCache.swift (YTDCacheManager)
├── QuarterlyCache.swift (QuarterlyCacheManager, QuarterCalculation, QuarterInfo)
├── QuarterlyPanelView.swift (QuarterlyPanelWindowController)
├── TickerEditorView.swift (WatchlistEditorWindowController)
└── DebugWindow.swift (DebugWindowController)

StockService.swift
├── StockData.swift (StockQuote, TradingSession, YahooChartResponse, TradingHours)
└── RequestLogger.swift (LoggingHTTPClient, HTTPClient)

NewsService.swift
├── NewsData.swift (NewsItem, RSSParser)
└── RequestLogger.swift (LoggingHTTPClient)

TickerConfig.swift
└── LayoutConfig.swift (LayoutConfig.Watchlist.maxSize)

TickerEditorView.swift
├── StockData.swift (YahooChartResponse)
├── TickerConfig.swift (WatchlistConfig.maxWatchlistSize)
└── RequestLogger.swift (LoggingHTTPClient)

QuarterlyPanelView.swift
├── QuarterlyCache.swift (QuarterInfo, QuarterlySortColumn)
├── StockData.swift (StockQuote)
├── TickerConfig.swift (OpaqueContainerView)
└── LayoutConfig.swift (LayoutConfig.QuarterlyWindow)

QuarterlyCache.swift
└── TickerConfig.swift (FileSystemProtocol, DateProvider)

DebugWindow.swift
└── RequestLogger.swift (RequestLogger, RequestLogEntry)
```

## Design Patterns

### Dependency Injection (Protocol-Based)
All major components use protocols for testability:
- `StockServiceProtocol` / `HTTPClient` — network layer
- `NewsServiceProtocol` — news fetching
- `FileSystemProtocol` / `WorkspaceProtocol` — file operations
- `SymbolValidator` — symbol validation
- `DateProvider` — injectable time (used by MarketSchedule, YTDCacheManager, QuarterlyCacheManager)
- `URLOpener` / `WindowProvider` — UI abstraction

### Actors for Thread Safety
- `StockService` — concurrent quote fetching via TaskGroup
- `NewsService` — concurrent RSS fetching via TaskGroup
- `RequestLogger` — thread-safe request log storage
- `YTDCacheManager` — thread-safe YTD price cache
- `QuarterlyCacheManager` — thread-safe quarterly price cache

### State Management
- `MenuBarController` — `@MainActor`, `@Published` properties, drives all UI
- `WatchlistEditorState` — `@MainActor` ObservableObject for editor window
- `DebugViewModel` — `@MainActor` ObservableObject, auto-refreshes every 1s
- `QuarterlyPanelViewModel` — `@MainActor` ObservableObject for quarterly performance window

### Constants in Private Enums
All magic numbers are extracted into namespaced enums:
- `Layout`, `Strings`, `Timing`, `MenuTag`, `TickerInsertIndex` (MenuBarView)
- `MarqueeConfig` (MarqueeView)
- `DebugWindowSize`, `DebugTiming` (DebugWindow)
- `WindowSize`, `WindowTiming` (TickerEditorView)
- `ResponseLimits`, `RetryConfig` (RequestLogger)
- `TradingHours` (StockData — shared across codebase)
- `LayoutConfig` (centralized layout dimensions)
- `QuarterlyWindow`, `QuarterlyFormatting` (QuarterlyPanelView)

### Pure Functions
- `WatchlistOperations` — symbol add/remove/sort operations
- `SortOption.sort()` — sorting with quote context
- Color helpers: `priceChangeColor()`, `ColorMapping.nsColor(from:)`, `ColorMapping.color(from:)`
- Formatting: `formatCurrency()`, `formatSignedPercent()`
- `QuarterCalculation` — quarter date math, identifier/label generation

### Callback Cleanup
`WatchlistEditorState` explicitly clears callbacks to prevent retain cycles. Called in `save()`, `cancel()`, and when window closes.

### HighlightConfig
Batches 5 highlight parameters into a single struct with `resolve()`, `withPingBackground()`, `withPingDisabled()` helpers.

### Legacy Config Decoding
`decodeLegacy()` extension on `KeyedDecodingContainer` handles backward-compatible field names (e.g. `tickers` → `watchlist`, `cycleInterval` → `menuBarRotationInterval`). Two overloads: required (throws) and optional (with default).

## API Integration

### Yahoo Finance Chart API (v8)
```
https://query1.finance.yahoo.com/v8/finance/chart/{SYMBOL}?interval=1m&range=1d&includePrePost=true
```

### HTTP Client Architecture
```
HTTPClient (protocol) ─── data(from:) interface
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

Config reload resets `hasCompletedInitialLoad = false` and calls `fetchMissingYTDPrices()` and `fetchMissingQuarterlyPrices()`.

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

## Quarterly Performance (Cmd+Opt+Q)

Standalone window with two view modes (segmented picker): **Since Quarter** shows percent change from each quarter's end to current price; **During Quarter** shows percent change within each quarter (start to end). Uses 12 most recent completed quarters (3 years). Cached at `~/.stockticker/quarterly-cache.json`:

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

**View modes:** `QuarterlyViewMode` enum — `.sinceQuarter` computes `(currentPrice - Q_end) / Q_end`, `.duringQuarter` computes `(Q_end - Q_prev_end) / Q_prev_end`. A 13th quarter is fetched as a reference price so during-quarter yields data for all 12 displayed quarters. View model stores data (`storedWatchlist`, `storedQuotes`, `storedQuarterPrices`) so rows recompute when toggling modes via `switchMode()`.

**Live updates:** During market hours, percent changes update each refresh cycle (~15s) using `quote.price` (regular market price, never pre/post). Format: `+12.34%` / `-5.67%` / `--` (missing). Color-coded green/red/secondary.

**Sortable columns:** Click header to sort ascending; click again to toggle descending. Switching columns resets to ascending. Nil values sort before any value. Column headers are pinned during vertical scrolling via `LazyVStack(pinnedViews: [.sectionHeaders])`.

**Row highlighting:** Config-highlighted symbols (`config.highlightedSymbols`) get a persistent colored background row using `highlightColor` and `highlightOpacity`. These cannot be toggled off by clicking. Non-config rows can be click-toggled on/off for readability. `ColorMapping` enum in TickerConfig.swift provides shared color name mapping for both NSColor and SwiftUI Color.

Key methods: `loadQuarterlyCache()`, `fetchMissingQuarterlyPrices()`, `showQuarterlyPanel()`

## News Headlines

Actor-based `NewsService` fetches from Yahoo Finance RSS and CNBC RSS concurrently via TaskGroup. `RSSParser` (XMLParserDelegate) parses XML with dual date format support (RFC 2822 + ISO 8601). Headlines deduplicated via Jaccard word similarity (threshold: 0.6). Cache-busted with timestamp query parameter. Up to 6 clickable headlines displayed with proportional font; top-from-source headlines use bold variant.

## Menu Bar Features

### Cycling Display
Rotates through watchlist symbols at `menuBarRotationInterval` during regular hours. Shows `menuBarAssetWhenClosed` crypto asset otherwise.

### Dropdown Menu
- **Market status** — Colored dot indicator (green/orange/red), bold state text, schedule with holiday name
- **Countdown** — Shows last refresh time and seconds until next: `"Last: 10:32 AM · Next in 12s"`
- **Index marquee** — `MarqueeView` custom NSView scrolling at ~32px/sec with seamless looping. Bold index names, regular weight values. Ping animation on data refresh.
- **News headlines** — Proportional font (headlineFont/headlineFontBold). Top-from-source uses highlight background.
- **Ticker list** — Sorted by `defaultSort`, shows price/change/percent/YTD/extended hours. Uses `HighlightConfig` for ping and persistent highlight styling.
- **Submenus** — Edit Watchlist, Quarterly Performance, Config (edit/reload/reset), Closed Market Display, Sort By, Debug

### Color Helpers
- `priceChangeColor(_:neutral:)` — green/red/neutral using `TradingHours.nearZeroThreshold`
- `ColorMapping.nsColor(from:)` — config string to NSColor (shared, in TickerConfig.swift)
- `ColorMapping.color(from:)` — config string to SwiftUI Color via `Color(nsColor:)` bridge
- `StockQuote` extensions: `displayColor`, `highlightColor`, `extendedHoursColor`, `ytdColor`
- YTD zero-change uses `.labelColor` (adapts to light/dark mode)

### Symbol Validation
`YahooSymbolValidator` makes a real API request, checks 200 status + valid `regularMarketPrice`.

### Debug Window (Cmd+Opt+D)
Shows API requests from last 60 seconds. Copy buttons for URL, request headers, response body (JSON pretty-printed). Auto-refreshes every 1s while open.

## Configuration

Location: `~/.stockticker/config.json` (auto-created on first launch)

| Field | Type | Default |
|-------|------|---------|
| `watchlist` | `[String]` (max 64) | 40+ symbols |
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

Sort options: `tickerAsc`/`Desc`, `changeAsc`/`Desc`, `percentAsc`/`Desc`, `ytdAsc`/`Desc`

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
- Menu bar: `makeMenuBarAttributedTitle(for:)`
- Dropdown: `buildTickerAttributedTitle(quote:highlight:)` with `HighlightConfig`
- YTD section: `appendYTDSection()`
- Extended hours: `appendExtendedHoursSection()`

### Change API data source
- Modify `StockService.fetchChartData()` and response models in `StockData.swift`

### Add a new display font
- Add to `MenuItemFactory` as a static property
- Reference from display methods in `MenuBarView.swift`

## Opaque Window Pattern

SwiftUI views in NSHostingView can have transparency issues on macOS. `OpaqueContainerView` draws a solid `windowBackgroundColor` beneath SwiftUI content. NSMenu uses system vibrancy which cannot be disabled.

## Clean Code Principles

1. **Meaningful Names** — Names reveal intent without comments
2. **Functions Do One Thing** — Small, focused, single-responsibility functions
3. **DRY** — Single source of truth; `decodeLegacy`, `ensureClosedMarketSymbol`, `HighlightConfig`, `ColorMapping`, shared `TradingHours` constants
4. **Single Responsibility** — Extracted SortOption, MarqueeView, MenuItemFactory, MenuBarController+Cache, pure WatchlistOperations
5. **Boy Scout Rule** — Leave code cleaner than found
6. **Minimize Comments** — Comments explain *why* (intent, warnings), never *what*
7. **No Side Effects** — Pure functions for sorting, formatting, operations
8. **Fail Fast** — Guard clauses, early returns, error logging on file I/O
9. **KISS/YAGNI** — No premature abstraction
10. **Write Tests** — Protocol-based DI enables comprehensive testing; 18 test files with mock doubles
