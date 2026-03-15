import json
import time
import urllib.request
from typing import Optional

BASE_URL = "https://query1.finance.yahoo.com/v8/finance/chart"
TIMESERIES_URL = "https://query2.finance.yahoo.com/ws/fundamentals-timeseries/v1/finance/timeseries"
USER_AGENT = "Mozilla/5.0"
TIMEOUT_SECONDS = 10


def fetch_daily_candles(symbol: str) -> Optional[tuple[list[float], list[int]]]:
    return _fetch_candles(symbol, range_param="1mo", interval="1d")


def fetch_weekly_candles(symbol: str) -> Optional[tuple[list[float], list[int]]]:
    return _fetch_candles(symbol, range_param="6mo", interval="1wk")


def fetch_monthly_candles(symbol: str) -> Optional[tuple[list[float], list[int]]]:
    return _fetch_candles(symbol, range_param="2y", interval="1wk")


def fetch_stats_candles(symbol: str) -> Optional[tuple[list[float], list[int]]]:
    return _fetch_candles(symbol, range_param="3y", interval="1d")


def _fetch_candles(symbol: str, range_param: str, interval: str) -> Optional[tuple[list[float], list[int]]]:
    url = f"{BASE_URL}/{symbol}?range={range_param}&interval={interval}"
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})

    try:
        with urllib.request.urlopen(request, timeout=TIMEOUT_SECONDS) as response:
            data = json.loads(response.read())
    except (OSError, ValueError) as err:
        print(f"[yahoo] {symbol}: {err}")
        return None

    return _parse_response(data)


def fetch_vix_candles() -> Optional[tuple[list[float], list[int]]]:
    return _fetch_candles("^VIX", range_param="3y", interval="1d")


def fetch_forward_pe(symbol: str) -> tuple[Optional[float], Optional[dict]]:
    """Fetch forward P/E ratio from Yahoo Timeseries API.

    Returns (current_pe, pe_history) where pe_history maps quarter labels
    like "Q3'25" to P/E values.
    """
    now = int(time.time())
    two_years_ago = now - 2 * 365 * 86400
    url = (
        f"{TIMESERIES_URL}/{symbol}"
        f"?type=quarterlyForwardPeRatio"
        f"&period1={two_years_ago}&period2={now}"
    )
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})

    try:
        with urllib.request.urlopen(request, timeout=TIMEOUT_SECONDS) as response:
            data = json.loads(response.read())
    except (OSError, ValueError) as err:
        print(f"[yahoo] {symbol} forward PE: {err}")
        return None, None

    current = _parse_forward_pe(data)
    history = _parse_forward_pe_history(data)
    return current, history


def _parse_forward_pe(data: dict) -> Optional[float]:
    try:
        results = data["timeseries"]["result"]
        for result in results:
            entries = result.get("quarterlyForwardPeRatio")
            if entries:
                last = entries[-1]
                return round(last["reportedValue"]["raw"], 2)
    except (KeyError, IndexError, TypeError):
        pass
    return None


def _parse_forward_pe_history(data: dict) -> Optional[dict]:
    """Parse all quarterly forward P/E entries into a dict of quarter labels."""
    try:
        results = data["timeseries"]["result"]
        for result in results:
            entries = result.get("quarterlyForwardPeRatio")
            if not entries:
                continue
            history = {}
            for entry in entries:
                date_str = entry.get("asOfDate", "")
                raw = entry.get("reportedValue", {}).get("raw")
                if not date_str or raw is None:
                    continue
                parts = date_str.split("-")
                if len(parts) != 3:
                    continue
                month = int(parts[1])
                year = int(parts[0])
                quarter_num = (month - 1) // 3 + 1
                short_year = str(year)[-2:]
                label = f"Q{quarter_num}'{short_year}"
                history[label] = round(raw, 2)
            return history if history else None
    except (KeyError, IndexError, TypeError, ValueError):
        pass
    return None


def _parse_response(data: dict) -> Optional[tuple[list[float], list[int]]]:
    try:
        result = data["chart"]["result"][0]
        raw_timestamps = result["timestamp"]
        raw_closes = result["indicators"]["quote"][0]["close"]
    except (KeyError, IndexError, TypeError):
        return None

    pairs = [
        (close, ts)
        for close, ts in zip(raw_closes, raw_timestamps)
        if close is not None
    ]

    if not pairs:
        return None

    closes = [close for close, _ in pairs]
    timestamps = [ts for _, ts in pairs]

    return closes, timestamps
