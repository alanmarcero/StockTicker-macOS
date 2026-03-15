from datetime import datetime, timezone

from src.worker.stats import (
    compute_ytd_pct,
    compute_highest_close_pct,
    compute_lowest_close_pct,
    compute_stats,
)


def _ts(year, month, day):
    return int(datetime(year, month, day, tzinfo=timezone.utc).timestamp())


class TestComputeYtdPct:

    def test_known_dec31_close(self):
        closes = [100.0, 101.0, 105.0, 112.0]
        timestamps = [
            _ts(2025, 12, 30),
            _ts(2025, 12, 31),
            _ts(2026, 1, 2),
            _ts(2026, 1, 3),
        ]

        result = compute_ytd_pct(closes, timestamps)

        # (112 - 101) / 101 * 100 = 10.89
        assert result == 10.89

    def test_negative_ytd(self):
        closes = [200.0, 190.0]
        timestamps = [_ts(2025, 12, 31), _ts(2026, 1, 2)]

        result = compute_ytd_pct(closes, timestamps)

        assert result == -5.0

    def test_ipo_after_dec31_returns_none(self):
        closes = [50.0, 55.0, 60.0]
        timestamps = [_ts(2026, 2, 1), _ts(2026, 2, 2), _ts(2026, 2, 3)]

        result = compute_ytd_pct(closes, timestamps)

        assert result is None

    def test_insufficient_data_returns_none(self):
        assert compute_ytd_pct([100.0], [_ts(2026, 1, 2)]) is None

    def test_empty_returns_none(self):
        assert compute_ytd_pct([], []) is None

    def test_uses_last_close_of_prev_year(self):
        closes = [90.0, 95.0, 100.0, 110.0]
        timestamps = [
            _ts(2025, 12, 29),
            _ts(2025, 12, 30),
            _ts(2025, 12, 31),
            _ts(2026, 1, 2),
        ]

        result = compute_ytd_pct(closes, timestamps)

        # (110 - 100) / 100 * 100 = 10.0
        assert result == 10.0


class TestComputeHighestClosePct:

    def test_at_high(self):
        closes = [90.0, 95.0, 100.0]

        pct, high = compute_highest_close_pct(closes)

        assert high == 100.0
        assert pct == 0.0

    def test_below_high(self):
        closes = [90.0, 100.0, 95.0]

        pct, high = compute_highest_close_pct(closes)

        assert high == 100.0
        assert pct == -5.0

    def test_empty_returns_none(self):
        assert compute_highest_close_pct([]) is None


class TestComputeLowestClosePct:

    def test_uses_last_252_closes(self):
        # 300 closes, min in the first 48 (outside 252 window)
        closes = [10.0] + [200.0] * 299
        closes[100] = 50.0  # inside 252 window

        pct, low = compute_lowest_close_pct(closes)

        assert low == 50.0

    def test_fewer_than_252_uses_all(self):
        closes = [80.0, 100.0, 90.0]

        pct, low = compute_lowest_close_pct(closes)

        assert low == 80.0
        # (90 - 80) / 80 * 100 = 12.5
        assert pct == 12.5

    def test_at_low(self):
        closes = [100.0, 90.0, 80.0]

        pct, low = compute_lowest_close_pct(closes)

        assert low == 80.0
        assert pct == 0.0

    def test_empty_returns_none(self):
        assert compute_lowest_close_pct([]) is None


class TestComputeStats:

    def test_returns_all_fields(self):
        closes = [100.0, 105.0, 110.0, 108.0]
        timestamps = [
            _ts(2025, 12, 31),
            _ts(2026, 1, 2),
            _ts(2026, 1, 3),
            _ts(2026, 1, 6),
        ]

        result = compute_stats(closes, timestamps)

        assert result is not None
        assert result["close"] == 108.0
        assert "ytdPct" in result
        assert "highPct" in result
        assert "high3yr" in result
        assert "lowPct" in result
        assert "low52wk" in result

    def test_empty_returns_none(self):
        assert compute_stats([], []) is None

    def test_single_close_returns_none(self):
        assert compute_stats([100.0], [_ts(2026, 1, 2)]) is None

    def test_no_prev_year_omits_ytd(self):
        closes = [50.0, 55.0]
        timestamps = [_ts(2026, 2, 1), _ts(2026, 2, 2)]

        result = compute_stats(closes, timestamps)

        assert result is not None
        assert "ytdPct" not in result
        assert "highPct" in result
        assert "lowPct" in result
