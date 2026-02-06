# StockTicker

![macOS 13+](https://img.shields.io/badge/macOS-13%2B-blue)
![Swift 5.9+](https://img.shields.io/badge/Swift-5.9%2B-orange)
![License: MIT](https://img.shields.io/badge/License-MIT-green)

A lightweight macOS menu bar app for tracking stocks, ETFs, and crypto with real-time quotes, YTD performance, and financial news.

## Features

**Real-time watchlist** — Track up to 50 symbols with live price, change, percent change, and year-to-date performance. Symbols rotate in the menu bar during market hours.

**Scrolling index marquee** — SPX, DJI, NDX, VIX, RUT, and BTC scroll across the top of the dropdown. Switches to crypto (BTC, ETH, SOL, DOGE, XRP) when the market is closed.

**Extended hours data** — Pre-market and after-hours price changes displayed alongside regular session data when available.

**Financial news** — Top headlines from Yahoo Finance and CNBC RSS feeds, clickable to open in your browser.

**Smart fetching** — Skips stock API calls on weekends, holidays, and after hours. Only crypto symbols refresh when the market is closed.

**Customizable highlights** — Background color highlighting for key symbols with configurable color and opacity.

**Market schedule** — NYSE open/close status with countdown timer and holiday awareness.

**Debug window** — Inspect API requests with full URL, headers, and response body (Cmd+Opt+D).

## How It Works

StockTicker lives in your macOS menu bar. During market hours, it cycles through your watchlist symbols showing the current price and percent change. Click the menu bar item to see the full dropdown.

When the market is open:

```
 NYSE: ● Open • 9:30 AM - 4:00 PM ET
 Last: 10:32 AM · Next in 12s
 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 SPX +0.52%    DJI +0.31%    NDX +0.84%    VIX -2.10%
 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 Fed signals potential rate pause amid data
 Tech stocks rally on strong earnings beat
 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 SPY    $585.50   +$2.30   +0.39%   YTD: +4.25%
 QQQ    $512.80   +$4.15   +0.82%   YTD: +6.10%   AH: +0.12%
 XLK    $210.35   +$1.80   +0.86%   YTD: +5.40%
 IWM    $225.10   -$0.45   -0.20%   YTD: +1.85%
 IBIT   $52.30    +$0.90   +1.75%   YTD: +8.20%
 ...
```

When the market is closed, the menu bar shows your selected crypto asset (default: BTC-USD) and the marquee switches to 24/7 crypto markets:

```
 NYSE: ● Closed • Weekend
 Last: 8:15 PM · Next in 12s
 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 BTC +1.20%    ETH +0.85%    SOL +2.30%    DOGE -0.50%
 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 ...
```

## Quick Start

```bash
git clone <repo-url> && cd StockTicker
./install.sh
```

The install script builds the app, copies it to `/Applications`, and launches it. StockTicker appears in your menu bar (no Dock icon).

## Configuration

Edit via the menu: click the menu bar item, then use **Edit Watchlist** for symbols or **Config > Edit Config** for the full JSON file. Changes take effect after selecting **Config > Reload Config** or restarting the app.

Config file location: `~/.stockticker/config.json` (auto-created on first launch)

| Option | Description | Default |
|--------|-------------|---------|
| `watchlist` | Symbols to track (max 50) | `["SPY", "QQQ", "XLK", ...]` |
| `menuBarRotationInterval` | Seconds between menu bar symbol rotation | `5` |
| `refreshInterval` | Seconds between API refreshes | `15` |
| `defaultSort` | Dropdown sort order | `percentDesc` |
| `menuBarAssetWhenClosed` | Asset shown when market is closed | `BTC-USD` |
| `indexSymbols` | Index symbols for marquee (regular hours) | SPX, DJI, NDX, VIX, RUT, BTC |
| `alwaysOpenMarkets` | 24/7 markets for marquee when closed | BTC, ETH, SOL, DOGE, XRP |
| `highlightedSymbols` | Symbols with background highlight | `["SPY"]` |
| `highlightColor` | Highlight color name | `yellow` |
| `highlightOpacity` | Highlight transparency (0.0-1.0) | `0.25` |
| `showNewsHeadlines` | Show news section in dropdown | `true` |
| `newsRefreshInterval` | Seconds between news refreshes | `300` |

<details>
<summary>Default config.json</summary>

```json
{
  "alwaysOpenMarkets": ["BTC", "ETH", "SOL", "DOGE", "XRP"],
  "defaultSort": "percentDesc",
  "highlightColor": "yellow",
  "highlightOpacity": 0.25,
  "highlightedSymbols": ["SPY"],
  "indexSymbols": ["SPX", "DJI", "NDX", "VIX", "RUT", "BTC"],
  "menuBarAssetWhenClosed": "BTC-USD",
  "menuBarRotationInterval": 5,
  "refreshInterval": 15,
  "watchlist": ["SPY", "QQQ", "XLK", "IWM", "IBIT", "ETHA", "GLD", "SLV", "VXUS"]
}
```

</details>

<details>
<summary>Sort options</summary>

| Option | Description |
|--------|-------------|
| `tickerAsc` / `tickerDesc` | Sort by symbol name |
| `changeAsc` / `changeDesc` | Sort by dollar change |
| `percentAsc` / `percentDesc` | Sort by percent change |
| `ytdAsc` / `ytdDesc` | Sort by YTD percent change |

</details>

<details>
<summary>Highlight colors</summary>

`yellow`, `green`, `blue`, `red`, `orange`, `purple`, `pink`, `cyan`, `teal`, `gray`, `brown`

</details>

<details>
<summary>Closed market display assets</summary>

`SPY`, `BTC-USD`, `ETH-USD`, `XRP-USD`, `DOGE-USD`, `SOL-USD`

</details>

## Architecture

The app follows clean code principles with protocol-based dependency injection, actor-based concurrency for thread safety, and comprehensive test coverage. See [CLAUDE.md](CLAUDE.md) for the full architecture guide, file dependency map, and design patterns.

**14 source files** | **12 test files** | **Swift/SwiftUI + AppKit**

## Development

**Prerequisites:** macOS 13+ (Ventura), Xcode 15+

```bash
# Run tests
xcodebuild test -project StockTicker.xcodeproj -scheme StockTicker -destination 'platform=macOS'

# Build release
xcodebuild -project StockTicker.xcodeproj -scheme StockTicker -configuration Release build

# Install to /Applications and launch
./install.sh

# Uninstall (optionally removes config)
./uninstall.sh
```

## Data Sources

- **Stock/ETF/crypto quotes** — Yahoo Finance Chart API (v8)
- **News headlines** — Yahoo Finance RSS, CNBC Top News RSS
- **YTD prices** — Cached locally at `~/.stockticker/ytd-cache.json`

## Troubleshooting

| Issue | Solution |
|-------|----------|
| App not in menu bar | Check if running: `pgrep -l StockTicker` |
| Shows "--" for a symbol | Invalid symbol or temporary network issue |
| Config changes not applied | Select **Config > Reload Config** from the menu |
| Build fails | Ensure Xcode CLI tools: `xcode-select -s /Applications/Xcode.app/Contents/Developer` |
| No YTD data | YTD prices are fetched on first launch of each calendar year |
| News not showing | Check `showNewsHeadlines` is `true` in config |
| High CPU usage | Increase `refreshInterval` in config (default: 15s) |

## License

MIT
