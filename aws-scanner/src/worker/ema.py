from typing import Optional

DEFAULT_PERIOD = 5


def _build_ema_series(closes: list[float], period: int) -> list[float]:
    sma = sum(closes[:period]) / period
    multiplier = 2.0 / (period + 1)
    ema = sma
    series = [ema]

    for i in range(period, len(closes)):
        ema = (closes[i] - ema) * multiplier + ema
        series.append(ema)

    return series


def calculate(closes: list[float], period: int = DEFAULT_PERIOD) -> Optional[float]:
    if len(closes) < period:
        return None

    return _build_ema_series(closes, period)[-1]


def detect_weekly_crossover(closes: list[float], period: int = DEFAULT_PERIOD) -> Optional[int]:
    if len(closes) < period + 1:
        return None

    ema_series = _build_ema_series(closes, period)
    last_index = len(ema_series) - 1
    if last_index < 1:
        return None

    ema_offset = period - 1

    if closes[ema_offset + last_index] <= ema_series[last_index] * 1.01:
        return None

    # Count consecutive weeks below EMA before the current candle
    weeks_below = 0
    for i in range(last_index - 1, -1, -1):
        if closes[ema_offset + i] > ema_series[i]:
            break
        weeks_below += 1

    return weeks_below if weeks_below > 0 else None


def detect_weekly_crossdown(closes: list[float], period: int = DEFAULT_PERIOD) -> Optional[int]:
    if len(closes) < period + 1:
        return None

    ema_series = _build_ema_series(closes, period)
    last_index = len(ema_series) - 1
    if last_index < 1:
        return None

    ema_offset = period - 1

    if closes[ema_offset + last_index] >= ema_series[last_index] * 0.99:
        return None

    # Count consecutive weeks above EMA before the current candle
    weeks_above = 0
    for i in range(last_index - 1, -1, -1):
        if closes[ema_offset + i] <= ema_series[i]:
            break
        weeks_above += 1

    return weeks_above if weeks_above > 0 else None


def count_periods_below(closes: list[float], period: int = DEFAULT_PERIOD) -> Optional[int]:
    if len(closes) < period + 1:
        return None

    ema_series = _build_ema_series(closes, period)
    last_index = len(ema_series) - 1
    if last_index < 0:
        return None

    ema_offset = period - 1

    if closes[ema_offset + last_index] > ema_series[last_index]:
        return None

    weeks_below = 1
    for i in range(last_index - 1, -1, -1):
        if closes[ema_offset + i] > ema_series[i]:
            break
        weeks_below += 1

    return weeks_below


def count_periods_above(closes: list[float], period: int = DEFAULT_PERIOD) -> Optional[int]:
    if len(closes) < period + 1:
        return None

    ema_series = _build_ema_series(closes, period)
    last_index = len(ema_series) - 1
    if last_index < 0:
        return None

    ema_offset = period - 1

    if closes[ema_offset + last_index] <= ema_series[last_index]:
        return None

    periods_above = 1
    for i in range(last_index - 1, -1, -1):
        if closes[ema_offset + i] <= ema_series[i]:
            break
        periods_above += 1

    return periods_above
