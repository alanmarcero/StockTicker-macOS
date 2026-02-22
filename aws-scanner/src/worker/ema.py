from typing import Optional

DEFAULT_PERIOD = 5


def calculate(closes: list[float], period: int = DEFAULT_PERIOD) -> Optional[float]:
    if len(closes) < period:
        return None

    sma = sum(closes[:period]) / period

    if len(closes) == period:
        return sma

    multiplier = 2.0 / (period + 1)
    ema = sma

    for i in range(period, len(closes)):
        ema = (closes[i] - ema) * multiplier + ema

    return ema


def detect_weekly_crossover(closes: list[float], period: int = DEFAULT_PERIOD) -> Optional[int]:
    if len(closes) < period + 1:
        return None

    multiplier = 2.0 / (period + 1)
    ema = sum(closes[:period]) / period
    ema_values = [ema]

    for i in range(period, len(closes)):
        ema = (closes[i] - ema) * multiplier + ema
        ema_values.append(ema)

    last = len(ema_values) - 1
    if last < 1:
        return None

    offset = period - 1

    if not (closes[offset + last] > ema_values[last] and closes[offset + last - 1] <= ema_values[last - 1]):
        return None

    weeks_below = 1
    for j in range(last - 2, -1, -1):
        if closes[offset + j] > ema_values[j]:
            break
        weeks_below += 1

    return weeks_below


def count_weeks_below(closes: list[float], period: int = DEFAULT_PERIOD) -> Optional[int]:
    if len(closes) < period + 1:
        return None

    multiplier = 2.0 / (period + 1)
    ema = sum(closes[:period]) / period
    ema_values = [ema]

    for i in range(period, len(closes)):
        ema = (closes[i] - ema) * multiplier + ema
        ema_values.append(ema)

    last = len(ema_values) - 1
    if last < 0:
        return None

    offset = period - 1

    if closes[offset + last] > ema_values[last]:
        return None

    weeks_below = 1
    for j in range(last - 1, -1, -1):
        if closes[offset + j] > ema_values[j]:
            break
        weeks_below += 1

    return weeks_below
