# StockTicker

A macOS menu bar app for tracking stock and ETF prices with color-coded changes.

## Features

- **Menu bar cycling** - rotates through your watchlist
- **Index line** - SPX, DJI, NDX, VIX, RUT, BTC displayed below dropdown (switches to crypto-only when market closed)
- **Pre-market/after-hours pricing** - extended hours data when available
- **Highlighted symbols** - subtle background highlight for key symbols
- **Market status** - NYSE schedule with countdown to open/close
- **Crypto fallback** - shows selected crypto when market is closed
- **Smart fetching** - skips stock API calls when market is closed (weekends/holidays/nights)
- **Debug window** - API request logging (last 60 seconds)

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
| `watchlist` | Symbols to track (max 32) | `["SPY", "QQQ", ...]` |
| `menuBarRotationInterval` | Seconds between menu bar symbol rotation | `5` |
| `refreshInterval` | Seconds between API refreshes | `15` |
| `defaultSort` | Dropdown sort order | `percentDesc` |
| `menuBarAssetWhenClosed` | Asset shown in menu bar when closed/after-hours | `BTC-USD` |
| `indexSymbols` | Index symbols for bottom row (regular hours) | SPX, DJI, NDX, VIX, RUT, BTC |
| `alwaysOpenMarkets` | 24/7 markets shown in index line when not regular hours | BTC, ETH, SOL, DOGE, XRP |
| `highlightedSymbols` | Symbols to highlight in dropdown | `["SPY"]` |
| `highlightColor` | Highlight background color | `yellow` |
| `highlightOpacity` | Highlight transparency (0.0-1.0) | `0.25` |

### Sort Options

`tickerAsc`, `tickerDesc`, `changeAsc`, `changeDesc`, `percentAsc`, `percentDesc`

### Highlight Colors

`yellow`, `green`, `blue`, `red`, `orange`, `purple`, `gray`

### Menu Bar Assets

`SPY`, `BTC-USD`, `ETH-USD`, `XRP-USD`, `DOGE-USD`, `SOL-USD`

### Editing

- **Watchlist:** Click menu bar > Edit Watchlist...
- **Full config:** Click menu bar > Edit Config...
- **Reload:** Click menu bar > Reload Config

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Not in menu bar | Run: `pgrep -l StockTicker` to check if running |
| Shows "--" | Invalid symbol or network issue |
| Config changes not applied | Select Reload Config from menu |
| Build fails | Run: `xcode-select -s /Applications/Xcode.app/Contents/Developer` |
