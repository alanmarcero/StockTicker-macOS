# StockTicker

A macOS menu bar app for tracking stock and ETF prices with real-time updates, YTD tracking, and financial news.

## Features

- **Menu bar cycling** - rotates through your watchlist symbols
- **Scrolling index marquee** - SPX, DJI, NDX, VIX, RUT, BTC (switches to crypto when market closed)
- **YTD price tracking** - year-to-date percentage change for all symbols
- **Pre-market/after-hours pricing** - extended hours data when available
- **News headlines** - top financial news from Yahoo Finance and CNBC RSS feeds
- **Highlighted symbols** - customizable background highlight for key symbols
- **Market status** - NYSE schedule with countdown to open/close
- **Crypto fallback** - shows selected crypto asset when market is closed
- **Smart fetching** - skips stock API calls when market is closed (weekends/holidays/nights)
- **Debug window** - API request logging with copy buttons (⌘⌥D)

## Screenshots

The app lives in your menu bar and shows a dropdown with all your tracked symbols:

```
NYSE: OPEN • 9:30 AM - 4:00 PM ET
Refreshing in 12s
[SPX +0.5%   DJI +0.3%   NDX +0.8%   VIX -2.1%   RUT +0.4%   BTC +1.2%]
────────────────────────────────────────
📰 Fed signals potential rate pause...
📰 Tech stocks rally on earnings...
────────────────────────────────────────
SPY   $585.50   +$2.30   +0.39%   YTD: +4.25%
QQQ   $512.80   +$4.15   +0.82%   YTD: +6.10%
AAPL  $185.25   -$1.20   -0.64%   YTD: +2.15%
...
```

## Requirements

- macOS 13.0 (Ventura) or later
- Xcode 15+ (for building)

## Installation

```bash
./install.sh
```

The script builds the app, installs to `/Applications`, and launches it.

## Uninstall

```bash
./uninstall.sh
```

## Configuration

**File:** `~/.stockticker/config.json` (auto-created on first launch)

| Option | Description | Default |
|--------|-------------|---------|
| `watchlist` | Symbols to track (max 40) | `["SPY", "QQQ", ...]` |
| `menuBarRotationInterval` | Seconds between menu bar symbol rotation | `5` |
| `refreshInterval` | Seconds between API refreshes | `15` |
| `defaultSort` | Dropdown sort order | `percentDesc` |
| `menuBarAssetWhenClosed` | Asset shown in menu bar when closed/after-hours | `BTC-USD` |
| `indexSymbols` | Index symbols for marquee (regular hours) | SPX, DJI, NDX, VIX, RUT, BTC |
| `alwaysOpenMarkets` | 24/7 markets shown in marquee when not regular hours | BTC, ETH, SOL, DOGE, XRP |
| `highlightedSymbols` | Symbols to highlight in dropdown | `["SPY"]` |
| `highlightColor` | Highlight background color | `yellow` |
| `highlightOpacity` | Highlight transparency (0.0-1.0) | `0.25` |

### Sort Options

| Option | Description |
|--------|-------------|
| `tickerAsc` / `tickerDesc` | Sort by symbol name |
| `changeAsc` / `changeDesc` | Sort by price change |
| `percentAsc` / `percentDesc` | Sort by percent change |
| `ytdAsc` / `ytdDesc` | Sort by YTD percent change |

### Highlight Colors

`yellow`, `green`, `blue`, `red`, `orange`, `purple`, `pink`, `cyan`, `teal`, `gray`, `brown`

### Menu Bar Assets (Closed Market Display)

`SPY`, `BTC-USD`, `ETH-USD`, `XRP-USD`, `DOGE-USD`, `SOL-USD`

### Editing

- **Watchlist:** Click menu bar → Edit Watchlist...
- **Full config:** Click menu bar → Edit Config...
- **Reload:** Click menu bar → Reload Config
- **Debug window:** ⌘⌥D or menu bar → Show Debug Window

## Data Sources

- **Stock/ETF quotes:** Yahoo Finance API (v8 Chart)
- **News headlines:** Yahoo Finance RSS, CNBC RSS feeds
- **YTD prices:** Cached locally in `~/.stockticker/ytd-cache.json`

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Not in menu bar | Run: `pgrep -l StockTicker` to check if running |
| Shows "--" | Invalid symbol or network issue |
| Config changes not applied | Select Reload Config from menu |
| Build fails | Run: `xcode-select -s /Applications/Xcode.app/Contents/Developer` |
| No YTD data | YTD prices are fetched on first launch of each year |

## Development

### Build & Test

```bash
# Run tests
xcodebuild test -project StockTicker.xcodeproj -scheme StockTicker -destination 'platform=macOS'

# Build release
xcodebuild -project StockTicker.xcodeproj -scheme StockTicker -configuration Release build
```

### Architecture

- **Protocol-based DI** - All services use protocols for testability
- **Actor-based concurrency** - Thread-safe services (`StockService`, `NewsService`, `YTDCacheManager`)
- **Clean code principles** - Small functions, meaningful names, no side effects

## License

MIT
