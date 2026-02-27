# Stonks

![macOS 13+](https://img.shields.io/badge/macOS-13%2B-blue)
![Swift 5.9+](https://img.shields.io/badge/Swift-5.9%2B-orange)
![License: MIT](https://img.shields.io/badge/License-MIT-green)

A macOS menu bar app for tracking stocks, ETFs, and crypto with real-time quotes, extended hours data, technical analysis, and financial news.

## Features

- **Watchlist** — Track up to 128 symbols with live price, change %, market cap, YTD %, distance from 3-year high, and distance from 52-week low. Symbols rotate in the menu bar during market hours.
- **Scrolling index marquee** — SPX, DJI, NDX, VIX, RUT, and BTC scroll across the top of the dropdown. Switches to crypto (BTC, ETH, SOL, DOGE, XRP) when the market is closed.
- **Extended hours** — Pre-market and after-hours price changes displayed alongside regular session data. Sortable by AH % (visible after 3:45 PM ET).
- **Financial news** — Top headlines from Yahoo Finance and CNBC, clickable to open in your browser.
- **Smart fetching** — Skips stock API calls on weekends, holidays, and after hours. Only crypto refreshes when the market is closed.
- **Persistent highlights** — Background color highlighting for key symbols with configurable color and opacity.
- **Market schedule** — NYSE open/close status with countdown timer and holiday awareness.
- **Finnhub integration** — Optional Finnhub API key routes equity/ETF data through Finnhub with Yahoo fallback.

### Extra Stats Window (`Cmd+Opt+Q`)

- **Since Quarter / During Quarter** — Percent change across the last 12 quarters. "Since Quarter" shows quarter-end to current price; "During Quarter" shows within-quarter performance.
- **Forward P/E** — Forward P/E ratio history by quarter (requires Finnhub API key).
- **Price Breaks** — Swing analysis showing breakout/breakdown levels with dates and RSI(14).
- **5 EMAs** — Daily/weekly EMA crossover/crossdown detection, consecutive closes above/below 5-period EMA. Supports AWS scanner data for ~10K US equities.
- **Misc Stats** — Aggregate stats: % near 3-year high, average YTD, % above/below 5-week EMA, average/median forward P/E.

### Other Windows

- **Edit Watchlist** (`Cmd+,`) — Add, remove, and reorder symbols.
- **API Errors** (`Cmd+Opt+D`) — Inspect API request/response details for debugging.

## Quick Start

```bash
git clone <repo-url> && cd StockTicker
./install.sh
```

Builds the app, copies to `/Applications`, and launches. Runs in the menu bar (no Dock icon).

**Prerequisites:** macOS 13+ (Ventura), Xcode 15+

## Configuration

Config file: `~/.stockticker/config.json` (auto-created on first launch)

Edit via the menu: **Config > Edit Config** for full JSON, or **Edit Watchlist** for symbols. Changes apply after **Config > Reload Config** or restart.

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `watchlist` | `[String]` | 41 symbols | Symbols to track (max 128) |
| `universe` | `[String]` | `[]` | Extended symbol list for Extra Stats analysis |
| `refreshInterval` | `Int` | `30` | Seconds between API refreshes |
| `menuBarRotationInterval` | `Int` | `5` | Seconds between menu bar symbol rotation |
| `sortDirection` | `String` | `"percentDesc"` | Default sort order (see sort options) |
| `menuBarAssetWhenClosed` | `String` | `"bitcoin"` | Menu bar display when market is closed |
| `indexSymbols` | `[{symbol, displayName}]` | SPX, DJI, NDX, VIX, RUT, BTC | Index marquee symbols |
| `alwaysOpenMarkets` | `[{symbol, displayName}]` | BTC, ETH, SOL, DOGE, XRP | Crypto marquee when closed |
| `highlightedSymbols` | `[String]` | `["SPY"]` | Symbols with persistent background highlight |
| `highlightColor` | `String` | `"yellow"` | Highlight color name |
| `highlightOpacity` | `Double` | `0.25` | Highlight transparency (0.0–1.0) |
| `showNewsHeadlines` | `Bool` | `true` | Show news section in dropdown |
| `newsRefreshInterval` | `Int` | `300` | Seconds between news refreshes |
| `finnhubApiKey` | `String` | `""` | Finnhub API key (free at finnhub.io) |
| `scannerBaseURL` | `String` | `""` | CloudFront URL for AWS EMA scanner results |

<details>
<summary>Sort options</summary>

`tickerAsc` / `tickerDesc`, `marketCapAsc` / `marketCapDesc`, `percentAsc` / `percentDesc`, `ytdAsc` / `ytdDesc`, `highAsc` / `highDesc`, `lowAsc` / `lowDesc`, `extendedAsc` / `extendedDesc`

</details>

<details>
<summary>Highlight colors</summary>

`yellow`, `orange`, `red`, `pink`, `purple`, `blue`, `cyan`, `teal`, `green`, `gray`, `brown`

</details>

<details>
<summary>Closed market display options</summary>

`SPY`, `bitcoin`, `ethereum`, `xrp`, `dogecoin`, `solana`

</details>

## Data Sources

- **Yahoo Finance** — Real-time quotes, historical closes, market cap, forward P/E history, YTD prices
- **Finnhub** (optional) — Equity/ETF quotes and historical data when API key is configured
- **AWS EMA Scanner** (optional) — Weekly 5-EMA crossover/crossdown analysis for ~10K US equities
- **Yahoo Finance RSS / CNBC RSS** — Financial news headlines

## Development

```bash
# Run tests
xcodebuild test -project StockTicker.xcodeproj -scheme StockTicker -destination 'platform=macOS'

# Build release
xcodebuild -project StockTicker.xcodeproj -scheme StockTicker -configuration Release build

# Install / uninstall
./install.sh
./uninstall.sh
```

## License

MIT
