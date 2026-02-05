# StockTicker

A macOS menu bar app for tracking stock and ETF prices. Built with Swift/SwiftUI.

## Architecture Overview

```
StockTickerApp.swift     - Entry point, creates MenuBarController
MenuBarView.swift        - Main controller: menu bar UI, timers, state management
StockService.swift       - Yahoo Finance API client (actor-based)
StockData.swift          - Data models: StockQuote, TradingSession, TradingHours, API response types
MarketSchedule.swift     - NYSE holiday/hours calculation
TickerConfig.swift       - Config loading/saving, OpaqueContainerView
TickerEditorView.swift   - SwiftUI watchlist editor window
RequestLogger.swift      - API request logging (actor-based), stores headers/body
DebugWindow.swift        - Debug window with copy buttons for URL/request/response
SortOption.swift         - Sort option enum with config parsing and sorting logic
MarqueeView.swift        - Scrolling index marquee NSView with ping animation
MenuItemFactory.swift    - Factory for creating styled NSMenuItems
NewsService.swift        - RSS feed fetcher for financial news (actor-based)
NewsData.swift           - NewsItem model and RSS XML parsing
YTDCache.swift           - Year-to-date price cache manager (actor-based)
LayoutConfig.swift       - Centralized layout constants
```

## File Dependencies & Connections

```
StockTickerApp.swift
└── MenuBarView.swift (MenuBarController)

MenuBarView.swift (MenuBarController)
├── StockService.swift (StockServiceProtocol) - fetches quotes
├── NewsService.swift (NewsServiceProtocol) - fetches news headlines
├── TickerConfig.swift (WatchlistConfigManager, WatchlistConfig) - loads/saves config
├── MarketSchedule.swift (MarketSchedule, MarketState) - market status display
├── StockData.swift (StockQuote, TradingSession) - quote display
├── SortOption.swift (SortOption) - dropdown sorting
├── MarqueeView.swift (MarqueeView, MarqueeConfig) - scrolling index line
├── MenuItemFactory.swift (MenuItemFactory) - menu item creation
├── YTDCache.swift (YTDCacheManager) - YTD price caching
├── TickerEditorView.swift (WatchlistEditorWindowController) - edit watchlist
└── DebugWindow.swift (DebugWindowController) - debug window

StockService.swift
├── StockData.swift (StockQuote, TradingSession, YahooChartResponse, TradingHours)
└── RequestLogger.swift (LoggingHTTPClient, HTTPClient)

NewsService.swift
├── NewsData.swift (NewsItem, RSSParser)
└── RequestLogger.swift (LoggingHTTPClient)

StockData.swift
└── TradingHours - shared trading hours constants (used by MarketSchedule)

MarketSchedule.swift
├── StockData.swift (TradingHours) - trading hours constants
└── MarketState, MarketHoliday, MarketScheduleStrings - market state types

TickerConfig.swift
├── LayoutConfig.swift (LayoutConfig.Watchlist.maxSize)
└── WatchlistConfig, WatchlistConfigManager, ClosedMarketAsset, IndexSymbol

TickerEditorView.swift
├── StockData.swift (YahooChartResponse) - symbol validation
├── TickerConfig.swift (WatchlistConfig.maxWatchlistSize)
├── RequestLogger.swift (LoggingHTTPClient) - validation requests
└── WatchlistOperations, SymbolAddResult, SymbolAddError - pure functions

DebugWindow.swift
└── RequestLogger.swift (RequestLogger, RequestLogEntry)

RequestLogger.swift
├── RequestLogEntry - log entry model (URL, headers, response body)
├── RequestLogger (actor) - stores entries, auto-prunes after 60s
└── LoggingHTTPClient - wraps HTTPClient with logging and retry

YTDCache.swift
├── YTDCacheData - Codable cache model (year, lastUpdated, prices)
├── YTDCacheManager (actor) - load/save/query YTD prices
└── DateProvider protocol - injectable date for testing
```

## Test File Coverage

```
StockDataTests.swift
├── StockQuoteTests - quote calculations, session detection, formatting
├── TradingSessionTests - Yahoo state parsing
└── FormattingTests - currency/percent formatting

StockServiceTests.swift
├── MockHTTPClient - test double
└── Tests for fetchQuote, fetchQuotes, fetchMarketState

MarketScheduleTests.swift
├── MockDateProvider - test double
└── Tests for holidays, market state, schedules

TickerConfigTests.swift
├── MockFileSystem, MockWorkspace - test doubles
├── IndexSymbolTests, ClosedMarketAssetTests
├── WatchlistConfigTests - encoding/decoding
└── WatchlistConfigManagerTests - load/save

TickerEditorStateTests.swift
├── MockSymbolValidator - test double
└── Tests for editor state machine

TickerListOperationsTests.swift
└── Pure function tests for WatchlistOperations

TickerValidatorTests.swift
├── MockHTTPClient - test double
└── YahooSymbolValidatorTests

TickerAddErrorTests.swift
└── SymbolAddError, SymbolAddResult tests

MenuBarViewTests.swift
├── SortOptionTests - from config string, raw values
└── SortOptionSortTests - sorting with quotes (including YTD)

MarqueeViewTests.swift
├── MarqueeConfigTests - config constants validation
└── MarqueeViewTests - layer setup, scrolling, ping animation

MenuItemFactoryTests.swift
├── Font tests - monospaced fonts
├── Disabled item tests
├── Action item tests
└── Submenu tests

YTDCacheTests.swift
├── MockYTDDateProvider, MockYTDFileSystem - test doubles
├── Load/save tests
├── Year rollover tests
├── Missing symbols tests
└── DateProvider injection tests

NewsServiceTests.swift
├── MockHTTPClient - test double
├── RSS parsing tests
└── News fetching tests
```

## Key Design Patterns

### Dependency Injection
All major components use protocol-based DI for testability:
- `StockServiceProtocol` / `HTTPClient` - network layer
- `NewsServiceProtocol` - news fetching
- `FileSystemProtocol` / `WorkspaceProtocol` - file operations
- `SymbolValidator` - symbol validation
- `DateProvider` - time-based testing (used by MarketSchedule, YTDCacheManager)
- `URLOpener` / `WindowProvider` - UI abstraction

### Actors for Thread Safety
- `StockService` - fetches quotes concurrently with TaskGroup
- `NewsService` - fetches RSS feeds concurrently
- `RequestLogger` - thread-safe request logging
- `YTDCacheManager` - thread-safe YTD price cache

### State Management
- `MenuBarController` is `@MainActor`, uses `@Published` properties
- `WatchlistEditorState` - ObservableObject for editor window
- `DebugViewModel` - auto-refreshes every 1s, starts/stops with view lifecycle

### Callback Cleanup Pattern
`WatchlistEditorState` explicitly clears callbacks to prevent retain cycles:
```swift
func clearCallbacks() {
    self.onSaveCallback = nil
    self.onCancelCallback = nil
}
```
Called in `save()`, `cancel()`, and when window closes.

### HighlightConfig Pattern
Batches highlight parameters to reduce repetition in `buildTickerAttributedTitle()`:
```swift
private struct HighlightConfig {
    let isPingHighlighted: Bool
    let pingBackgroundColor: NSColor?
    let isPersistentHighlighted: Bool
    let persistentHighlightColor: NSColor
    let persistentHighlightOpacity: Double

    func resolve(defaultColor: NSColor) -> (foreground: NSColor, background: NSColor?)
    func withPingBackground(_ color: NSColor?) -> HighlightConfig
    func withPingDisabled() -> HighlightConfig
}
```

## API Integration

Uses Yahoo Finance Chart API v8:
```
https://query1.finance.yahoo.com/v8/finance/chart/{SYMBOL}?interval=1m&range=1d&includePrePost=true
```

Key behaviors:
- Concurrent fetching via `TaskGroup`
- Extended hours data calculated from chart indicators (fallback when API doesn't provide directly)
- `LoggingHTTPClient` wraps all requests for debugging and retry logic
- Logs auto-prune after 60 seconds

### HTTP Client Architecture

```
HTTPClient (protocol) ─── defines data(from:) interface
    │
URLSession (conforms) ─── raw network layer
    │
LoggingHTTPClient (wraps HTTPClient)
    ├── Logs all requests to RequestLogger
    ├── Retry logic: 1 retry after 0.5s delay on failure
    ├── Retries on non-2xx status codes OR network errors
    └── Skips retries during pre-market/after-hours (extended hours data less critical)
    │
StockService, NewsService, YahooSymbolValidator (consumers)
    └── All default to LoggingHTTPClient()
```

Individual request retry - if fetching AAPL, MSFT, GOOGL and MSFT fails, only MSFT retries.

### Smart Fetching (Market Hours Aware)

Fetching and display behavior changes based on market state:

| Market State | Watchlist | Index Marquee | Menu Bar |
|--------------|-----------|---------------|----------|
| Closed | Skip | `alwaysOpenMarkets` | `menuBarAssetWhenClosed` |
| Pre-Market | Fetch | `alwaysOpenMarkets` | `menuBarAssetWhenClosed` |
| Open | Fetch | `indexSymbols` | Cycle through watchlist |
| After-Hours | Fetch | `alwaysOpenMarkets` | `menuBarAssetWhenClosed` |

Uses `MarketSchedule.getTodaySchedule()` to determine state (handles weekends, holidays).

The marquee display (`isRegularMarketClosed`) uses `currentMarketState` (Yahoo API state) to ensure consistency with the rest of the UI.

### Initial Load vs Subsequent Refreshes

The app uses a two-phase fetching strategy controlled by `hasCompletedInitialLoad`:

1. **Initial load (app startup)** - Fetches ALL symbols (watchlist + indexes + crypto) regardless of market state. This ensures users see their portfolio data even on weekends (Friday's closing prices).

2. **Subsequent refreshes** - Uses smart fetching based on market state. On weekends, only crypto symbols are fetched since stock prices don't change.

Weekend handling:
- Yahoo API may return "POST" on weekends (from Friday's after-hours)
- App forces `yahooMarketState = "CLOSED"` on weekends regardless of API response
- Extended hours labels (Pre/AH) are not shown on weekends

Config reload (`reloadConfig()`) resets `hasCompletedInitialLoad = false` to trigger a full refresh, and also calls `fetchMissingYTDPrices()` to ensure newly added symbols get YTD data.

### Selective Ping Animation

The ping/highlight animation only triggers for symbols that were actually fetched:
```swift
let watchlistSymbolsToHighlight = config.watchlist.filter { fetchedSymbols.contains($0) }
watchlistSymbolsToHighlight.forEach { highlightIntensity[$0] = 1.0 }
```
On weekends, only crypto symbols in the watchlist will ping when refreshed.

### Extended Hours Calculation

`StockService.calculateExtendedHoursData()` computes pre/post market changes:
1. Gets latest close price from chart indicators (`includePrePost=true`)
2. Uses time-based session detection as fallback when Yahoo returns "CLOSED"
3. Calculates change from regular market price to current indicator price
4. Only populates when price difference > 0.001 (avoids floating point issues)

## YTD Price Tracking

Year-to-date prices are cached locally and displayed alongside each symbol.

### Cache Location
`~/.stockticker/ytd-cache.json`

### Cache Structure
```json
{
  "year": 2026,
  "lastUpdated": "2026-01-15T12:00:00Z",
  "prices": {
    "AAPL": 185.50,
    "SPY": 475.25
  }
}
```

### YTD Flow
1. **App startup**: `loadYTDCache()` loads cache, checks year rollover, fetches missing prices
2. **Config reload**: `fetchMissingYTDPrices()` fetches YTD for newly added symbols
3. **Each refresh**: `attachYTDPricesToQuotes()` attaches cached YTD prices to quotes
4. **Year change**: Cache automatically clears on first launch of new year

### Key Methods
- `loadYTDCache()` - Initial load with year rollover check
- `fetchMissingYTDPrices()` - Batch fetch for symbols not in cache
- `attachYTDPricesToQuotes()` - Attach YTD start prices to quote objects

## News Headlines

Financial news from RSS feeds displayed in the dropdown menu.

### Data Sources
- Yahoo Finance RSS: `https://finance.yahoo.com/news/rssindex`
- CNBC Top News: `https://www.cnbc.com/id/100003114/device/rss/rss.html`

### NewsService
Actor-based service that:
1. Fetches RSS feeds concurrently via TaskGroup
2. Parses XML using `RSSParser` (XMLParser delegate)
3. Deduplicates headlines by similarity
4. Returns top headlines sorted by publish date

### Display
- Up to 6 clickable headlines in dropdown
- Clicking opens article in default browser
- Headlines truncated to `LayoutConfig.Headlines.maxLength` characters

## Configuration

Location: `~/.stockticker/config.json`

Key fields:
- `watchlist` - symbols to track (max 40)
- `menuBarRotationInterval` - seconds between menu bar symbol rotation (default: 5)
- `refreshInterval` - seconds between API calls (default: 15)
- `defaultSort` - dropdown sort order
- `menuBarAssetWhenClosed` - asset shown in menu bar when market is closed/after-hours (default: BTC-USD)
- `indexSymbols` - bottom row indexes during regular hours (SPX, DJI, NDX, VIX, RUT, BTC)
- `alwaysOpenMarkets` - 24/7 markets shown in marquee when regular market is not open (default: BTC, ETH, SOL, DOGE, XRP)
- `highlightedSymbols` - symbols with background highlight
- `highlightColor` / `highlightOpacity` - highlight appearance

Supports backward compatibility with legacy field names (`tickers`, `indexTickers`, `highlightedTickers`, `cycleInterval`).

### Default Values
```swift
watchlist: ["SPY", "QQQ", "XLK", "IWM", "IBIT", "ETHA", "GLD", "SLV", "VXUS"]
menuBarRotationInterval: 5
refreshInterval: 15
defaultSort: "percentDesc"
menuBarAssetWhenClosed: .bitcoin (BTC-USD)
indexSymbols: SPX (^GSPC), DJI (^DJI), NDX (^IXIC), VIX (^VIX), RUT (^RUT), BTC (BTC-USD)
alwaysOpenMarkets: BTC, ETH, SOL, DOGE, XRP
highlightedSymbols: ["SPY"]
highlightColor: "yellow"
highlightOpacity: 0.25
```

### JSON Output
Config saved with `prettyPrinted` and `sortedKeys` for readability.

## Menu Bar Features

1. **Cycling display** - rotates through watchlist symbols at `menuBarRotationInterval`
2. **Dropdown menu**:
   - Market status with schedule and countdown (updates every 1s)
   - Scrolling index marquee (`MarqueeView` - custom NSView, 32px/sec scroll)
   - News headlines (clickable, opens in browser)
   - Sorted ticker list with price/change/YTD (configurable via `defaultSort`)
   - Extended hours data (Pre/AH) when available
   - Highlight flash on data refresh (fades over time)
3. **When market closed** - shows selected crypto asset

### MarqueeView (Index Line)
Custom `NSView` that scrolls the index ticker line horizontally:
- Ticker scrolls at ~32px/sec (8px every 0.25s)
- Seamless looping via duplicate text rendering
- Highlight ping effect on data refresh
- Extracted to separate file with `MarqueeConfig` constants

### Symbol Validation
`YahooSymbolValidator` validates symbols before adding to watchlist:
1. Makes real API request to Yahoo Finance
2. Checks for 200 status code
3. Verifies response has valid `regularMarketPrice`
4. Returns `false` for invalid/unknown symbols

### Debug Window (⌘⌥D)
Shows API requests from the last 60 seconds with:
- Timestamp, method, status code, duration, response size
- Full URL
- Copy buttons for each request:
  - **Copy URL** - Just the URL string
  - **Copy Request** - Method, URL, and request headers
  - **Copy Response** - Status, duration, size, response headers, and body (JSON pretty-printed)

`RequestLogEntry` stores:
- `requestHeaders: [String: String]` - HTTP request headers
- `responseHeaders: [String: String]` - HTTP response headers
- `responseBody: String?` - Response body (capped at 50KB)

Helper methods for copying:
- `copyableRequest` - Formatted request string
- `copyableResponse` - Formatted response with pretty-printed JSON
- `formattedRequestHeaders` / `formattedResponseHeaders` - Sorted header lists

## Testing

Comprehensive test suite using XCTest:
- `StockServiceTests` - API mocking
- `StockDataTests` - model logic, time-based session detection
- `MarketScheduleTests` - holiday calculations
- `TickerConfigTests` - config loading/saving
- `TickerEditorStateTests` - editor state machine
- `TickerListOperationsTests` - pure watchlist functions
- `TickerValidatorTests` - symbol validation
- `MenuBarViewTests` - sort options (including YTD sorts)
- `MarqueeViewTests` - marquee config and view behavior
- `MenuItemFactoryTests` - menu item factory methods
- `YTDCacheTests` - YTD cache with mock DateProvider
- `NewsServiceTests` - RSS parsing and news fetching

Run tests: `xcodebuild test -project StockTicker.xcodeproj -scheme StockTicker -destination 'platform=macOS'`

## Build & Install

```bash
./install.sh   # Builds, installs to /Applications, launches
./uninstall.sh # Removes app and optionally config
```

Requirements: macOS 13+ (Ventura), Xcode 15+

The app runs as `LSUIElement` (no dock icon, menu bar only).

### App Entry Point
`StockTickerApp.swift` is minimal:
```swift
@main
struct StockTickerApp: App {
    @StateObject private var menuBarController = MenuBarController()
    var body: some Scene {
        Settings { EmptyView() }
    }
}
```
- `MenuBarController` is instantiated as `@StateObject` (kept alive for app lifetime)
- Empty `Settings` scene required for SwiftUI App protocol
- All UI is in the menu bar, managed by `MenuBarController`

## Verification Steps

After completing any code changes, run these steps to verify:

```bash
# 1. Run tests
xcodebuild test -project StockTicker.xcodeproj -scheme StockTicker -destination 'platform=macOS'

# 2. Build release
xcodebuild -project StockTicker.xcodeproj -scheme StockTicker -configuration Release build

# 3. Uninstall
pkill -x StockTicker 2>/dev/null || true
rm -rf /Applications/StockTicker.app

# 4. Install
./install.sh

# 5. Confirm running
pgrep -x StockTicker && echo "App is running"
```

## Clean Code Principles

This codebase follows these 10 clean code principles:

### 1. Meaningful Names
Names reveal intent. Variables, functions, and classes tell you *why they exist*, *what they do*, and *how they're used* without needing comments.

### 2. Functions Do One Thing
Each function performs a single task. Small, focused functions are easier to test, name, and understand.

### 3. DRY (Don't Repeat Yourself)
Every piece of knowledge has a single, unambiguous representation. No duplicated code.

### 4. Single Responsibility Principle
A class or module has only one reason to change. Concerns are separated into distinct units.

### 5. Boy Scout Rule
Leave code cleaner than you found it. Incremental improvements prevent rot.

### 6. Minimize Comments, Maximize Clarity
Self-documenting code with clear names and structure. Comments only for *why* (intent, warnings), never *what*.

### 7. Avoid Side Effects
Functions do what their name promises and nothing more. No hidden state changes.

### 8. Fail Fast, Handle Errors Explicitly
Errors handled at appropriate levels. Error handling separated from happy-path logic.

### 9. Keep It Simple (KISS/YAGNI)
Prefer the simplest solution. No over-engineering or premature abstraction.

### 10. Write Tests
Tests document behavior, enable refactoring, and catch regressions. F.I.R.S.T.: Fast, Independent, Repeatable, Self-validating, Timely.

## Code Conventions

- Constants in private enums (`Layout`, `Timing`, `MarqueeConfig`, `DebugWindowSize`, `WindowSize`, etc.)
- Extensions for color helpers and attributed strings
- Pure functions in `WatchlistOperations` for testability
- Callbacks cleared explicitly to prevent retain cycles

### SortOption Pattern
`SortOption` enum (extracted to `SortOption.swift`) encapsulates sorting logic with config string parsing:
```swift
SortOption.from(configString: "percentDesc")  // Parse from config
sortOption.sort(symbols, using: quotes)        // Apply sort
```
Sorts: `tickerAsc`, `tickerDesc`, `changeAsc`, `changeDesc`, `percentAsc`, `percentDesc`, `ytdAsc`, `ytdDesc`

### Color Helpers
- `colorFromString(_:)` - converts config string ("yellow", "blue", etc.) to NSColor
- `priceChangeColor(_:neutral:)` - returns green/red/neutral based on change value
- `StockQuote` extensions: `displayColor`, `highlightColor`, `extendedHoursColor`, `ytdColor`

### Opaque Window Pattern
SwiftUI views hosted in NSHostingView can have transparency issues on macOS. Use `OpaqueContainerView` as a wrapper:
```swift
let hostingView = NSHostingView(rootView: mySwiftUIView)
hostingView.autoresizingMask = [.width, .height]

let opaqueContainer = OpaqueContainerView(frame: windowFrame)
hostingView.frame = opaqueContainer.bounds
opaqueContainer.addSubview(hostingView)

window.contentView = opaqueContainer
```
This draws a solid `windowBackgroundColor` beneath the SwiftUI content, eliminating transparency.

Note: NSMenu uses macOS system vibrancy which cannot be disabled. The menu dropdown will always have the standard macOS translucent appearance.

## Common Tasks

### Add a new config option
1. Add property to `WatchlistConfig` struct
2. Handle in `init(from decoder:)` with `decodeIfPresent` for defaults
3. Add to `encode(to:)`
4. Update UI in `MenuBarController` if needed

### Add a new menu item
1. Create in `setupMenu()` or relevant submenu creator
2. Add `@objc` action method
3. Wire up target/action

### Modify ticker display
- Menu bar: `makeMenuBarAttributedTitle(for:)`
- Dropdown: `buildTickerAttributedTitle(quote:highlight:)` with HighlightConfig

### Change API data source
- Modify `StockService.fetchChartData` and response models in `StockData.swift`

## Recent Clean Code Improvements

The following cleanup was performed applying clean code principles:

### Earlier Refactoring
1. **Removed unused v7 Yahoo API models** (YAGNI) - `YahooQuoteResponse`, `QuoteResult`, `QuoteError`, `QuoteData` were never used; app only uses v8 Chart API

2. **Unified trading hours constants** (DRY) - Created `TradingHours` enum in `StockData.swift`, removed duplicate `MarketHours` from `MarketSchedule.swift`. Both `StockQuote.currentTimeBasedSession()` and `MarketSchedule.calculateMarketState()` now use shared constants.

3. **Improved variable names** (Meaningful Names) - Renamed `q` to `validQuote` in `MenuBarView.buildFullIndexAttributedString()`

4. **Extracted display strings** - Created `MarketScheduleStrings` for schedule display text, separating data from presentation

5. **Centralized retry logic** (DRY) - Added retry logic to `LoggingHTTPClient` so all API requests automatically retry once on failure. Single implementation benefits all consumers (`StockService`, `YahooSymbolValidator`).

### Component Extraction (Single Responsibility)
6. **Extracted SortOption.swift** - Moved `SortOption` enum from MenuBarView.swift to dedicated file with config string parsing and sorting logic.

7. **Extracted MarqueeView.swift** - Moved `MarqueeView` class and `MarqueeConfig` constants from MenuBarView.swift to dedicated file.

8. **Extracted MenuItemFactory.swift** - Moved menu item factory methods and font constants from MenuBarView.swift to dedicated file.

### DRY Improvements
9. **Created `ensureClosedMarketSymbol(in:)` helper** - Replaced 3 duplicate occurrences of symbol-checking logic in `refreshAllQuotes()` with single helper function.

10. **Created `HighlightConfig` struct** - Batched 5 highlight parameters into single struct with helper methods (`resolve`, `withPingBackground`, `withPingDisabled`), reducing parameter passing in `buildTickerAttributedTitle()`.

11. **Extracted `appendYTDSection()` and `appendExtendedHoursSection()`** - Split 78-line `buildTickerAttributedTitle()` into focused helper methods.

### Bug Fixes
12. **YTD prices for newly added symbols** - Extracted `fetchMissingYTDPrices()` from `loadYTDCache()` and call it in `reloadConfig()` so newly added watchlist symbols get YTD data immediately without requiring app restart.

### Testability Improvements
13. **Added DateProvider injection to YTDCacheManager** - Enables testing year rollover logic with mock dates.

14. **Added comprehensive tests** - `MarqueeViewTests`, `MenuItemFactoryTests`, `YTDCacheTests` with mock dependencies.
