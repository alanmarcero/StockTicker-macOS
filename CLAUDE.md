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

## Architecture

42 source files (~8,800 lines), 37 test files (~13,000 lines). All source files have corresponding tests. Shared test helpers in `TestUtilities.swift`.

**Core flow:** `MenuBarView` (main controller) → `StockService` (Yahoo/Finnhub APIs) → cache actors → UI. `MenuBarController+Cache` coordinates all cache refresh cycles. `BackfillScheduler` handles staggered cache population.

**Key modules:**
- `StockService` + extensions: API client split by concern (historical, EMA, market cap, Finnhub, forward P/E)
- `StockData.swift`: All data models (StockQuote, API response types)
- `QuarterlyPanel{View,ViewModel,Models}`: Extra Stats window
- `ScannerService`: AWS scanner API client (CloudFront), feature-flagged via `scannerBaseURL`
- 7 cache actors: YTD, Quarterly, HighestClose, ForwardPE, SwingLevel, RSI, EMA
- Pure analysis: `EMAAnalysis`, `SwingAnalysis`, `RSIAnalysis`
- `TickerConfig`: Config at `~/.stockticker/config.json`, saved with `prettyPrinted`/`sortedKeys`

## Design Patterns

- **Protocol-based DI** for all major components (services, caches, file system, date provider)
- **Actor isolation** for thread safety; `@MainActor` for state management
- **`ThrottledTaskGroup`** — bounded concurrency with 4 modes (default, Backfill, FinnhubBackfill, FinnhubQuote). `SymbolRouting.partition()` splits symbols by API source.
- **Two-tier symbol sets:** `allCacheSymbols` (watchlist + universe + indices) for most caches; `extraStatsSymbols` (watchlist + universe) for quarterly/forward P/E/Extra Stats
- **`CacheStorage<T: Codable>`** — generic file I/O shared by all 7 cache actors
- **`QuarterlyPanelData`** — DTO bundling data fields passed to Extra Stats view model/controller

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
