import pytest

from src.worker.ema import DEFAULT_PERIOD, calculate, count_periods_above, count_weeks_below, detect_weekly_crossover


def test_calculate_empty_closes_returns_none():
    result = calculate(closes=[])
    assert result is None


def test_calculate_insufficient_data_returns_none():
    closes = [100.0, 101.0, 102.0, 103.0]
    result = calculate(closes=closes)
    assert result is None


def test_calculate_exactly_period_returns_sma():
    closes = [10.0, 20.0, 30.0, 40.0, 50.0]
    result = calculate(closes=closes)
    assert result == 30.0


def test_calculate_known_sequence_returns_correct_ema():
    closes = [10.0, 20.0, 30.0, 40.0, 50.0, 60.0]
    result = calculate(closes=closes)
    assert result == pytest.approx(40.0, abs=0.01)


def test_calculate_constant_values_returns_constant():
    closes = [50.0] * 10
    result = calculate(closes=closes)
    assert result == 50.0


def test_calculate_custom_period():
    closes = [10.0, 20.0, 30.0, 40.0]
    result = calculate(closes=closes, period=3)
    assert result == pytest.approx(30.0, abs=0.01)


def test_calculate_uptrend_ema_rises():
    closes = [100.0, 105.0, 110.0, 115.0, 120.0, 125.0, 130.0, 135.0]
    result = calculate(closes=closes)
    assert result > 110.0


def test_calculate_downtrend_ema_falls():
    closes = [135.0, 130.0, 125.0, 120.0, 115.0, 110.0, 105.0, 100.0]
    result = calculate(closes=closes)
    assert result < 125.0


def test_default_period_is_5():
    assert DEFAULT_PERIOD == 5


def test_detect_weekly_crossover_no_data_returns_none():
    result = detect_weekly_crossover(closes=[])
    assert result is None


def test_detect_weekly_crossover_insufficient_data_returns_none():
    result = detect_weekly_crossover(closes=[100.0, 101.0, 102.0, 103.0, 104.0])
    assert result is None


def test_detect_weekly_crossover_no_crossover_all_above_returns_none():
    closes = [10.0, 20.0, 30.0, 40.0, 50.0, 60.0, 70.0, 80.0, 90.0, 100.0]
    result = detect_weekly_crossover(closes=closes)
    assert result is None


def test_detect_weekly_crossover_no_crossover_all_below_returns_none():
    closes = [100.0, 90.0, 80.0, 70.0, 60.0, 50.0, 40.0, 30.0, 20.0, 10.0]
    result = detect_weekly_crossover(closes=closes)
    assert result is None


def test_detect_weekly_crossover_crossover_one_week_below():
    closes = [50.0, 52.0, 54.0, 56.0, 58.0, 56.0, 53.0, 56.0]
    result = detect_weekly_crossover(closes=closes)
    assert result == 1


def test_detect_weekly_crossover_crossover_three_weeks_below():
    closes = [100.0, 102.0, 104.0, 106.0, 108.0, 100.0, 101.0, 101.0, 106.0]
    result = detect_weekly_crossover(closes=closes)
    assert result == 3


def test_detect_weekly_crossover_crossover_at_boundary():
    closes = [50.0, 48.0, 46.0, 44.0, 42.0, 48.0]
    result = detect_weekly_crossover(closes=closes)
    assert result == 1


def test_count_weeks_below_no_data_returns_none():
    result = count_weeks_below(closes=[])
    assert result is None


def test_count_weeks_below_insufficient_data_returns_none():
    result = count_weeks_below(closes=[100.0, 101.0, 102.0, 103.0, 104.0])
    assert result is None


def test_count_weeks_below_above_ema_returns_none():
    closes = [10.0, 20.0, 30.0, 40.0, 50.0, 60.0, 70.0, 80.0, 90.0, 100.0]
    result = count_weeks_below(closes=closes)
    assert result is None


def test_count_weeks_below_one_week_below():
    closes = [50.0, 52.0, 54.0, 56.0, 58.0, 56.0, 53.0]
    result = count_weeks_below(closes=closes)
    assert result == 1


def test_count_weeks_below_three_weeks_below():
    closes = [100.0, 102.0, 104.0, 106.0, 108.0, 100.0, 101.0, 101.0]
    result = count_weeks_below(closes=closes)
    assert result == 3


def test_count_weeks_below_at_boundary():
    closes = [50.0, 52.0, 54.0, 56.0, 58.0, 50.0]
    result = count_weeks_below(closes=closes)
    assert result == 1


def test_count_periods_above_empty_closes_returns_none():
    result = count_periods_above(closes=[])
    assert result is None


def test_count_periods_above_insufficient_data_returns_none():
    result = count_periods_above(closes=[100.0, 101.0, 102.0, 103.0, 104.0])
    assert result is None


def test_count_periods_above_below_ema_returns_none():
    closes = [100.0, 90.0, 80.0, 70.0, 60.0, 50.0, 40.0, 30.0, 20.0, 10.0]
    result = count_periods_above(closes=closes)
    assert result is None


def test_count_periods_above_one_above():
    closes = [50.0, 52.0, 54.0, 56.0, 58.0, 56.0, 53.0, 56.0]
    result = count_periods_above(closes=closes)
    assert result == 1


def test_count_periods_above_uptrend():
    closes = [10.0, 20.0, 30.0, 40.0, 50.0, 60.0, 70.0, 80.0, 90.0, 100.0]
    result = count_periods_above(closes=closes)
    assert result == 6


def test_count_periods_above_boundary():
    closes = [50.0, 48.0, 46.0, 44.0, 42.0, 48.0]
    result = count_periods_above(closes=closes)
    assert result == 1


def test_count_periods_above_equal_to_ema_returns_none():
    closes = [50.0] * 10
    result = count_periods_above(closes=closes)
    assert result is None
