import json
import urllib.request
from typing import Optional

BASE_URL = "https://query1.finance.yahoo.com/v8/finance/chart"
USER_AGENT = "Mozilla/5.0"
TIMEOUT_SECONDS = 10


def fetch_daily_candles(symbol: str) -> Optional[tuple[list[float], list[int]]]:
    url = f"{BASE_URL}/{symbol}?range=1mo&interval=1d"
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})

    try:
        with urllib.request.urlopen(request, timeout=TIMEOUT_SECONDS) as response:
            data = json.loads(response.read())
    except (OSError, ValueError) as err:
        print(f"[yahoo] {symbol}: {err}")
        return None

    return _parse_response(data)


def fetch_weekly_candles(symbol: str) -> Optional[tuple[list[float], list[int]]]:
    url = f"{BASE_URL}/{symbol}?range=6mo&interval=1wk"
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})

    try:
        with urllib.request.urlopen(request, timeout=TIMEOUT_SECONDS) as response:
            data = json.loads(response.read())
    except (OSError, ValueError) as err:
        print(f"[yahoo] {symbol}: {err}")
        return None

    return _parse_response(data)


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
