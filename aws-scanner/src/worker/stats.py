from datetime import datetime, timezone
from typing import Optional


def compute_ytd_pct(closes: list[float], timestamps: list[int]) -> Optional[float]:
    """Return YTD % change from last close of previous year to current close."""
    if len(closes) < 2:
        return None

    current_year = datetime.fromtimestamp(timestamps[-1], tz=timezone.utc).year
    prev_year = current_year - 1

    dec31_close = None
    for close, ts in zip(closes, timestamps):
        dt = datetime.fromtimestamp(ts, tz=timezone.utc)
        if dt.year == prev_year:
            dec31_close = close

    if dec31_close is None:
        return None

    return round((closes[-1] - dec31_close) / dec31_close * 100, 2)


def compute_highest_close_pct(closes: list[float]) -> Optional[tuple[float, float]]:
    """Return (pct from 3yr high, the high value). Pct is negative or zero."""
    if not closes:
        return None
    high = max(closes)
    pct = round((closes[-1] - high) / high * 100, 2)
    return pct, high


def compute_lowest_close_pct(closes: list[float]) -> Optional[tuple[float, float]]:
    """Return (pct above 52wk low, the low value) using last 252 closes."""
    if not closes:
        return None
    window = closes[-252:] if len(closes) >= 252 else closes
    low = min(window)
    pct = round((closes[-1] - low) / low * 100, 2)
    return pct, low


def compute_stats(closes: list[float], timestamps: list[int]) -> Optional[dict]:
    """Compute YTD/High/Low stats. Returns None if insufficient data."""
    if len(closes) < 2:
        return None

    result = {"close": round(closes[-1], 2)}

    ytd = compute_ytd_pct(closes, timestamps)
    if ytd is not None:
        result["ytdPct"] = ytd

    high_result = compute_highest_close_pct(closes)
    if high_result is not None:
        result["highPct"] = high_result[0]
        result["high3yr"] = round(high_result[1], 2)

    low_result = compute_lowest_close_pct(closes)
    if low_result is not None:
        result["lowPct"] = low_result[0]
        result["low52wk"] = round(low_result[1], 2)

    return result
