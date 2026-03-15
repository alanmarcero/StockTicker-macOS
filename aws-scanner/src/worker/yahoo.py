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


def fetch_forward_pe(symbol: str) -> Optional[float]:
    """Fetch forward P/E ratio from Yahoo Timeseries API."""
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
        return None

    return _parse_forward_pe(data)


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
