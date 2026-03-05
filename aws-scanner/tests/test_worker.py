import json
from unittest.mock import patch, MagicMock

from src.worker.app import (
    lambda_handler,
    _process_batch,
    _aggregate_results,
    _aggregate_to_monthly,
    _invalidate_cache,
    _write_batch_results,
    _write_errors,
)


# -- Shared test data --

# Crossover: 3 weeks below then cross above
CROSSOVER_CLOSES = [100.0, 102.0, 104.0, 106.0, 108.0, 100.0, 101.0, 101.0, 106.0]

# Steady below: 3 weeks below EMA (no crossover)
BELOW_CLOSES = [100.0, 102.0, 104.0, 106.0, 108.0, 100.0, 101.0, 101.0]

# Uptrend: all above EMA (no crossover, no below)
UPTREND_CLOSES = [10.0, 20.0, 30.0, 40.0, 50.0, 60.0, 70.0, 80.0, 90.0, 100.0]

# Crossdown: 4 weeks above then cross below
CROSSDOWN_CLOSES = [10.0, 20.0, 30.0, 40.0, 50.0, 60.0, 70.0, 80.0, 40.0]

# Reusable empty batch for aggregation tests
EMPTY_BATCH = {"symbolsProcessed": 10, "errors": 0, "crossovers": [], "crossdowns": [], "dayBelow": [], "weekBelow": [], "dayAbove": [], "weekAbove": [], "monthCrossovers": [], "monthCrossdowns": [], "monthBelow": [], "monthAbove": []}


def _timestamps_for(closes):
    return list(range(len(closes)))


class TestProcessBatch:

    def setup_method(self):
        self._yahoo_patcher = patch("src.worker.app.yahoo")
        self._time_patcher = patch("src.worker.app.time")
        self.mock_yahoo = self._yahoo_patcher.start()
        self.mock_time = self._time_patcher.start()
        self.mock_yahoo.fetch_daily_candles.return_value = None
        self.mock_yahoo.fetch_monthly_candles.return_value = None

    def teardown_method(self):
        self._time_patcher.stop()
        self._yahoo_patcher.stop()

    def test_crossover_detected(self):
        self.mock_yahoo.fetch_weekly_candles.return_value = (CROSSOVER_CLOSES, _timestamps_for(CROSSOVER_CLOSES))

        crossovers, crossdowns, day_below, week_below, day_above, week_above, month_crossovers, month_crossdowns, month_below, month_above, errors = _process_batch(["TEST"])

        assert len(crossovers) == 1
        assert crossovers[0]["symbol"] == "TEST"
        assert crossovers[0]["close"] == 106.0
        assert crossovers[0]["weeksBelow"] == 3
        assert crossovers[0]["pctAbove"] > 0
        assert len(errors) == 0

    def test_crossover_output_fields(self):
        self.mock_yahoo.fetch_weekly_candles.return_value = (CROSSOVER_CLOSES, _timestamps_for(CROSSOVER_CLOSES))

        crossovers, _, _, _, _, _, _, _, _, _, _ = _process_batch(["AAPL"])

        entry = crossovers[0]
        assert set(entry.keys()) == {"symbol", "close", "ema", "pctAbove", "weeksBelow"}
        assert isinstance(entry["close"], float)
        assert isinstance(entry["ema"], float)
        assert isinstance(entry["pctAbove"], float)
        assert isinstance(entry["weeksBelow"], int)

    def test_crossover_ema_rounded_to_4_decimals(self):
        self.mock_yahoo.fetch_weekly_candles.return_value = (CROSSOVER_CLOSES, _timestamps_for(CROSSOVER_CLOSES))

        crossovers, _, _, _, _, _, _, _, _, _, _ = _process_batch(["X"])

        ema_str = str(crossovers[0]["ema"])
        decimals = ema_str.split(".")[-1] if "." in ema_str else ""
        assert len(decimals) <= 4

    def test_crossover_pct_above_rounded_to_2_decimals(self):
        self.mock_yahoo.fetch_weekly_candles.return_value = (CROSSOVER_CLOSES, _timestamps_for(CROSSOVER_CLOSES))

        crossovers, _, _, _, _, _, _, _, _, _, _ = _process_batch(["X"])

        pct = crossovers[0]["pctAbove"]
        assert pct == round(pct, 2)

    def test_week_below_detected_with_minimum_weeks(self):
        self.mock_yahoo.fetch_weekly_candles.return_value = (BELOW_CLOSES, _timestamps_for(BELOW_CLOSES))

        crossovers, crossdowns, day_below, week_below, day_above, week_above, month_crossovers, month_crossdowns, month_below, month_above, errors = _process_batch(["TEST"])

        assert len(week_below) == 1
        assert week_below[0]["symbol"] == "TEST"
        assert week_below[0]["count"] == 3
        assert week_below[0]["pctBelow"] > 0

    def test_week_below_output_fields(self):
        self.mock_yahoo.fetch_weekly_candles.return_value = (BELOW_CLOSES, _timestamps_for(BELOW_CLOSES))

        _, _, _, week_below, _, _, _, _, _, _, _ = _process_batch(["X"])

        entry = week_below[0]
        assert set(entry.keys()) == {"symbol", "close", "ema", "pctBelow", "count"}

    def test_week_below_not_detected_under_threshold(self):
        closes = [50.0, 52.0, 54.0, 56.0, 58.0, 56.0, 53.0]
        self.mock_yahoo.fetch_weekly_candles.return_value = (closes, _timestamps_for(closes))

        _, _, _, week_below, _, _, _, _, _, _, _ = _process_batch(["TEST"])

        assert len(week_below) == 0

    def test_week_below_two_weeks_not_detected(self):
        closes = [100.0, 102.0, 104.0, 106.0, 108.0, 100.0, 101.0]
        self.mock_yahoo.fetch_weekly_candles.return_value = (closes, _timestamps_for(closes))

        _, _, _, week_below, _, _, _, _, _, _, _ = _process_batch(["TEST"])

        assert len(week_below) == 0

    def test_uptrend_no_crossover_no_below(self):
        self.mock_yahoo.fetch_weekly_candles.return_value = (UPTREND_CLOSES, _timestamps_for(UPTREND_CLOSES))

        crossovers, crossdowns, day_below, week_below, day_above, week_above, month_crossovers, month_crossdowns, month_below, month_above, errors = _process_batch(["BULL"])

        assert len(crossovers) == 0
        assert len(week_below) == 0
        assert len(errors) == 0

    def test_fetch_failure_records_error(self):
        self.mock_yahoo.fetch_weekly_candles.return_value = None

        crossovers, crossdowns, day_below, week_below, day_above, week_above, month_crossovers, month_crossdowns, month_below, month_above, errors = _process_batch(["FAIL"])

        assert len(crossovers) == 0
        assert len(week_below) == 0
        assert len(day_above) == 0
        assert len(week_above) == 0
        assert len(errors) == 1
        assert errors[0]["symbol"] == "FAIL"
        assert "error" in errors[0]

    def test_insufficient_data_skipped_no_error(self):
        self.mock_yahoo.fetch_weekly_candles.return_value = ([100.0, 101.0, 102.0], [1, 2, 3])

        crossovers, crossdowns, day_below, week_below, day_above, week_above, month_crossovers, month_crossdowns, month_below, month_above, errors = _process_batch(["SHORT"])

        assert len(crossovers) == 0
        assert len(week_below) == 0
        assert len(errors) == 0

    def test_multiple_symbols_rate_limited(self):
        self.mock_yahoo.fetch_weekly_candles.return_value = ([50.0] * 10, list(range(10)))

        _process_batch(["A", "B", "C"])

        assert self.mock_time.sleep.call_count == 2
        self.mock_time.sleep.assert_called_with(1)

    def test_single_symbol_no_sleep(self):
        self.mock_yahoo.fetch_weekly_candles.return_value = ([50.0] * 10, list(range(10)))

        _process_batch(["ONLY"])

        self.mock_time.sleep.assert_not_called()

    def test_mixed_success_and_failure(self):
        def weekly_side_effect(symbol):
            if symbol == "FAIL":
                return None
            return (CROSSOVER_CLOSES, _timestamps_for(CROSSOVER_CLOSES))

        self.mock_yahoo.fetch_weekly_candles.side_effect = weekly_side_effect

        crossovers, crossdowns, day_below, week_below, day_above, week_above, month_crossovers, month_crossdowns, month_below, month_above, errors = _process_batch(["OK", "FAIL", "OK2"])

        assert len(crossovers) == 2
        assert len(errors) == 1
        assert errors[0]["symbol"] == "FAIL"

    def test_empty_batch(self):
        crossovers, crossdowns, day_below, week_below, day_above, week_above, month_crossovers, month_crossdowns, month_below, month_above, errors = _process_batch([])

        assert crossovers == []
        assert crossdowns == []
        assert day_below == []
        assert week_below == []
        assert day_above == []
        assert week_above == []
        assert errors == []
        self.mock_yahoo.fetch_weekly_candles.assert_not_called()
        self.mock_yahoo.fetch_daily_candles.assert_not_called()

    def test_all_failures(self):
        self.mock_yahoo.fetch_weekly_candles.return_value = None

        crossovers, crossdowns, day_below, week_below, day_above, week_above, month_crossovers, month_crossdowns, month_below, month_above, errors = _process_batch(["A", "B", "C"])

        assert len(crossovers) == 0
        assert len(week_below) == 0
        assert len(day_above) == 0
        assert len(week_above) == 0
        assert len(errors) == 3

    def test_day_above_detected(self):
        self.mock_yahoo.fetch_daily_candles.return_value = (UPTREND_CLOSES, _timestamps_for(UPTREND_CLOSES))
        self.mock_yahoo.fetch_weekly_candles.return_value = (UPTREND_CLOSES, _timestamps_for(UPTREND_CLOSES))

        _, _, _, _, day_above, _, _, _, _, _, _ = _process_batch(["BULL"])

        assert len(day_above) == 1
        assert day_above[0]["symbol"] == "BULL"
        assert day_above[0]["count"] == 6
        assert day_above[0]["pctAbove"] > 0

    def test_day_above_output_fields(self):
        self.mock_yahoo.fetch_daily_candles.return_value = (UPTREND_CLOSES, _timestamps_for(UPTREND_CLOSES))
        self.mock_yahoo.fetch_weekly_candles.return_value = (UPTREND_CLOSES, _timestamps_for(UPTREND_CLOSES))

        _, _, _, _, day_above, _, _, _, _, _, _ = _process_batch(["X"])

        entry = day_above[0]
        assert set(entry.keys()) == {"symbol", "close", "ema", "pctAbove", "count"}
        assert isinstance(entry["count"], int)

    def test_week_above_detected(self):
        self.mock_yahoo.fetch_weekly_candles.return_value = (UPTREND_CLOSES, _timestamps_for(UPTREND_CLOSES))

        _, _, _, _, _, week_above, _, _, _, _, _ = _process_batch(["BULL"])

        assert len(week_above) == 1
        assert week_above[0]["symbol"] == "BULL"
        assert week_above[0]["count"] == 6
        assert week_above[0]["pctAbove"] > 0

    def test_week_above_output_fields(self):
        self.mock_yahoo.fetch_weekly_candles.return_value = (UPTREND_CLOSES, _timestamps_for(UPTREND_CLOSES))

        _, _, _, _, _, week_above, _, _, _, _, _ = _process_batch(["X"])

        entry = week_above[0]
        assert set(entry.keys()) == {"symbol", "close", "ema", "pctAbove", "count"}

    def test_daily_fail_still_processes_weekly(self):
        self.mock_yahoo.fetch_daily_candles.return_value = None
        self.mock_yahoo.fetch_weekly_candles.return_value = (CROSSOVER_CLOSES, _timestamps_for(CROSSOVER_CLOSES))

        crossovers, _, _, _, _, _, _, _, _, _, errors = _process_batch(["TEST"])

        assert len(crossovers) == 1
        assert len(errors) == 0

    def test_weekly_fail_still_processes_daily(self):
        self.mock_yahoo.fetch_daily_candles.return_value = (UPTREND_CLOSES, _timestamps_for(UPTREND_CLOSES))
        self.mock_yahoo.fetch_weekly_candles.return_value = None

        _, _, _, _, day_above, _, _, _, _, _, errors = _process_batch(["TEST"])

        assert len(day_above) == 1
        assert len(errors) == 0

    def test_all_fetches_fail_records_error(self):
        self.mock_yahoo.fetch_daily_candles.return_value = None
        self.mock_yahoo.fetch_weekly_candles.return_value = None
        self.mock_yahoo.fetch_monthly_candles.return_value = None

        _, _, _, _, _, _, _, _, _, _, errors = _process_batch(["FAIL"])

        assert len(errors) == 1
        assert errors[0]["symbol"] == "FAIL"

    def test_below_ema_not_in_above_lists(self):
        self.mock_yahoo.fetch_daily_candles.return_value = (BELOW_CLOSES, _timestamps_for(BELOW_CLOSES))
        self.mock_yahoo.fetch_weekly_candles.return_value = (BELOW_CLOSES, _timestamps_for(BELOW_CLOSES))

        _, _, _, _, day_above, week_above, _, _, _, _, _ = _process_batch(["BEAR"])

        assert len(day_above) == 0
        assert len(week_above) == 0

    def test_crossdown_detected(self):
        self.mock_yahoo.fetch_weekly_candles.return_value = (CROSSDOWN_CLOSES, _timestamps_for(CROSSDOWN_CLOSES))

        _, crossdowns, _, _, _, _, _, _, _, _, _ = _process_batch(["TEST"])

        assert len(crossdowns) == 1
        assert crossdowns[0]["symbol"] == "TEST"
        assert crossdowns[0]["weeksAbove"] == 4
        assert crossdowns[0]["pctBelow"] >= 0

    def test_crossdown_output_fields(self):
        self.mock_yahoo.fetch_weekly_candles.return_value = (CROSSDOWN_CLOSES, _timestamps_for(CROSSDOWN_CLOSES))

        _, crossdowns, _, _, _, _, _, _, _, _, _ = _process_batch(["X"])

        entry = crossdowns[0]
        assert set(entry.keys()) == {"symbol", "close", "ema", "pctBelow", "weeksAbove"}
        assert isinstance(entry["close"], float)
        assert isinstance(entry["ema"], float)
        assert isinstance(entry["pctBelow"], float)
        assert isinstance(entry["weeksAbove"], int)


class TestAggregateToMonthly:

    def test_groups_by_calendar_month(self):
        # 3 weeks in Jan 2026, 2 weeks in Feb 2026
        closes = [100.0, 101.0, 102.0, 103.0, 104.0]
        timestamps = [
            1735689600,  # 2025-01-01
            1736294400,  # 2025-01-08
            1736899200,  # 2025-01-15
            1738108800,  # 2025-01-29 -> still Jan
            1738713600,  # 2025-02-05
        ]
        # Actually let's use clear month boundaries
        from datetime import datetime, timezone
        ts_jan_1 = int(datetime(2025, 1, 6, tzinfo=timezone.utc).timestamp())
        ts_jan_2 = int(datetime(2025, 1, 13, tzinfo=timezone.utc).timestamp())
        ts_jan_3 = int(datetime(2025, 1, 20, tzinfo=timezone.utc).timestamp())
        ts_feb_1 = int(datetime(2025, 2, 3, tzinfo=timezone.utc).timestamp())
        ts_feb_2 = int(datetime(2025, 2, 10, tzinfo=timezone.utc).timestamp())

        closes = [100.0, 101.0, 102.0, 200.0, 201.0]
        timestamps = [ts_jan_1, ts_jan_2, ts_jan_3, ts_feb_1, ts_feb_2]

        result = _aggregate_to_monthly(closes, timestamps)

        assert len(result) == 2
        assert result[0] == 102.0  # last close in Jan
        assert result[1] == 201.0  # last close in Feb

    def test_single_month(self):
        from datetime import datetime, timezone
        ts1 = int(datetime(2025, 3, 3, tzinfo=timezone.utc).timestamp())
        ts2 = int(datetime(2025, 3, 10, tzinfo=timezone.utc).timestamp())

        result = _aggregate_to_monthly([50.0, 55.0], [ts1, ts2])

        assert result == [55.0]

    def test_empty_input(self):
        assert _aggregate_to_monthly([], []) == []

    def test_six_months_produces_expected_count(self):
        from datetime import datetime, timezone
        # Simulate ~26 weekly candles across 6 months
        closes = []
        timestamps = []
        base = datetime(2025, 1, 6, tzinfo=timezone.utc)
        for i in range(26):
            from datetime import timedelta
            dt = base + timedelta(weeks=i)
            closes.append(100.0 + i)
            timestamps.append(int(dt.timestamp()))

        result = _aggregate_to_monthly(closes, timestamps)

        # Jan through ~July = 6-7 months
        assert 6 <= len(result) <= 7


class TestWriteBatchResults:

    @patch("src.worker.app.s3")
    def test_writes_to_correct_key(self, mock_s3):
        _write_batch_results("mybucket", "2026-02-22", 5, 50, 2, [], [], [], [], [], [], [], [], [], [])

        mock_s3.put_object.assert_called_once()
        kwargs = mock_s3.put_object.call_args[1]
        assert kwargs["Bucket"] == "mybucket"
        assert kwargs["Key"] == "batches/2026-02-22/batch-005.json"

    @patch("src.worker.app.s3")
    def test_batch_index_zero_padded(self, mock_s3):
        _write_batch_results("b", "r", 0, 10, 0, [], [], [], [], [], [], [], [], [], [])
        assert "batch-000.json" in mock_s3.put_object.call_args[1]["Key"]

        _write_batch_results("b", "r", 99, 10, 0, [], [], [], [], [], [], [], [], [], [])
        assert "batch-099.json" in mock_s3.put_object.call_args[1]["Key"]

        _write_batch_results("b", "r", 159, 10, 0, [], [], [], [], [], [], [], [], [], [])
        assert "batch-159.json" in mock_s3.put_object.call_args[1]["Key"]

    @patch("src.worker.app.s3")
    def test_body_contains_all_fields(self, mock_s3):
        crossovers = [{"symbol": "AAPL", "weeksBelow": 3}]
        crossdowns = [{"symbol": "NVDA", "weeksAbove": 5}]
        day_below = [{"symbol": "AMZN", "count": 2}]
        week_below = [{"symbol": "MSFT", "count": 4}]
        day_above = [{"symbol": "GOOG", "count": 5}]
        week_above = [{"symbol": "TSLA", "count": 3}]

        month_crossovers = [{"symbol": "META", "monthsBelow": 2}]
        month_crossdowns = [{"symbol": "NFLX", "monthsAbove": 3}]
        month_below = [{"symbol": "INTC", "count": 4}]
        month_above = [{"symbol": "AMD", "count": 2}]

        _write_batch_results("b", "r", 0, 50, 2, crossovers, crossdowns, day_below, week_below, day_above, week_above, month_crossovers, month_crossdowns, month_below, month_above)

        body = json.loads(mock_s3.put_object.call_args[1]["Body"])
        assert body["batchIndex"] == 0
        assert body["symbolsProcessed"] == 50
        assert body["errors"] == 2
        assert body["crossovers"] == crossovers
        assert body["crossdowns"] == crossdowns
        assert body["dayBelow"] == day_below
        assert body["weekBelow"] == week_below
        assert body["dayAbove"] == day_above
        assert body["weekAbove"] == week_above
        assert body["monthCrossovers"] == month_crossovers
        assert body["monthCrossdowns"] == month_crossdowns
        assert body["monthBelow"] == month_below
        assert body["monthAbove"] == month_above


class TestWriteErrors:

    @patch("src.worker.app.s3")
    def test_writes_to_correct_key(self, mock_s3):
        errors = [{"symbol": "BAD", "error": "fail"}]

        _write_errors("mybucket", "2026-02-22", 3, errors)

        kwargs = mock_s3.put_object.call_args[1]
        assert kwargs["Bucket"] == "mybucket"
        assert kwargs["Key"] == "logs/2026-02-22/errors-003.json"

    @patch("src.worker.app.s3")
    def test_body_is_error_list(self, mock_s3):
        errors = [{"symbol": "A", "error": "x"}, {"symbol": "B", "error": "y"}]

        _write_errors("b", "r", 0, errors)

        body = json.loads(mock_s3.put_object.call_args[1]["Body"])
        assert len(body) == 2
        assert body[0]["symbol"] == "A"


class TestLambdaHandler:

    def setup_method(self):
        self._env_patcher = patch.dict("os.environ", {"BUCKET_NAME": "test-bucket"})
        self._process_patcher = patch("src.worker.app._process_batch")
        self._write_patcher = patch("src.worker.app._write_batch_results")
        self._errors_patcher = patch("src.worker.app._write_errors")
        self._agg_patcher = patch("src.worker.app._aggregate_results")
        self._inv_patcher = patch("src.worker.app._invalidate_cache")
        self._env_patcher.start()
        self.mock_process = self._process_patcher.start()
        self.mock_write = self._write_patcher.start()
        self.mock_errors = self._errors_patcher.start()
        self.mock_agg = self._agg_patcher.start()
        self.mock_invalidate = self._inv_patcher.start()

    def teardown_method(self):
        self._inv_patcher.stop()
        self._agg_patcher.stop()
        self._errors_patcher.stop()
        self._write_patcher.stop()
        self._process_patcher.stop()
        self._env_patcher.stop()

    def _sqs_event(self, messages: list[dict]) -> dict:
        return {
            "Records": [
                {"body": json.dumps(msg)} for msg in messages
            ]
        }

    def test_processes_sqs_message(self):
        self.mock_process.return_value = ([], [], [], [], [], [], [], [], [], [], [])
        event = self._sqs_event([{
            "runId": "2026-02-22",
            "batchIndex": 0,
            "totalBatches": 3,

            "symbols": ["AAPL", "MSFT"],
        }])

        result = lambda_handler(event, None)

        assert result["statusCode"] == 200
        self.mock_process.assert_called_once_with(["AAPL", "MSFT"])
        self.mock_write.assert_called_once()

    def test_last_batch_triggers_aggregation(self):
        self.mock_process.return_value = ([], [], [], [], [], [], [], [], [], [], [])
        event = self._sqs_event([{
            "runId": "2026-02-22",
            "batchIndex": 2,
            "totalBatches": 3,

            "symbols": ["AAPL"],
        }])

        lambda_handler(event, None)

        self.mock_agg.assert_called_once_with("test-bucket", "2026-02-22", 3)

    def test_non_last_batch_skips_aggregation(self):
        self.mock_process.return_value = ([], [], [], [], [], [], [], [], [], [], [])
        event = self._sqs_event([{
            "runId": "2026-02-22",
            "batchIndex": 0,
            "totalBatches": 3,

            "symbols": ["AAPL"],
        }])

        lambda_handler(event, None)

        self.mock_agg.assert_not_called()

    def test_errors_written_when_present(self):
        self.mock_process.return_value = ([], [], [], [], [], [], [], [], [], [], [{"symbol": "BAD", "error": "fail"}])
        event = self._sqs_event([{
            "runId": "2026-02-22",
            "batchIndex": 0,
            "totalBatches": 1,

            "symbols": ["BAD"],
        }])

        lambda_handler(event, None)

        self.mock_errors.assert_called_once()

    def test_errors_not_written_when_empty(self):
        self.mock_process.return_value = ([], [], [], [], [], [], [], [], [], [], [])
        event = self._sqs_event([{
            "runId": "2026-02-22",
            "batchIndex": 0,
            "totalBatches": 1,

            "symbols": ["AAPL"],
        }])

        lambda_handler(event, None)

        self.mock_errors.assert_not_called()

    def test_empty_records(self):
        result = lambda_handler({"Records": []}, None)

        assert result["statusCode"] == 200
        self.mock_process.assert_not_called()

    def test_single_batch_total_triggers_aggregation(self):
        self.mock_process.return_value = ([], [], [], [], [], [], [], [], [], [], [])
        event = self._sqs_event([{
            "runId": "2026-02-22",
            "batchIndex": 0,
            "totalBatches": 1,

            "symbols": ["AAPL"],
        }])

        lambda_handler(event, None)

        self.mock_agg.assert_called_once()

    def test_last_batch_invalidates_cache(self):
        self.mock_process.return_value = ([], [], [], [], [], [], [], [], [], [], [])
        event = self._sqs_event([{
            "runId": "2026-02-22",
            "batchIndex": 2,
            "totalBatches": 3,
            "symbols": ["AAPL"],
        }])

        lambda_handler(event, None)

        self.mock_invalidate.assert_called_once()

    def test_non_last_batch_skips_invalidation(self):
        self.mock_process.return_value = ([], [], [], [], [], [], [], [], [], [], [])
        event = self._sqs_event([{
            "runId": "2026-02-22",
            "batchIndex": 0,
            "totalBatches": 3,
            "symbols": ["AAPL"],
        }])

        lambda_handler(event, None)

        self.mock_invalidate.assert_not_called()


class TestInvalidateCache:

    @patch("src.worker.app.cloudfront")
    @patch.dict("os.environ", {"DISTRIBUTION_ID": "E1234567890"})
    def test_creates_invalidation(self, mock_cf):
        _invalidate_cache()

        mock_cf.create_invalidation.assert_called_once()
        args = mock_cf.create_invalidation.call_args[1]
        assert args["DistributionId"] == "E1234567890"
        assert args["InvalidationBatch"]["Paths"]["Items"] == ["/results/*"]

    @patch("src.worker.app.cloudfront")
    @patch.dict("os.environ", {}, clear=True)
    def test_skips_when_no_distribution_id(self, mock_cf):
        _invalidate_cache()

        mock_cf.create_invalidation.assert_not_called()


class TestAggregateResults:

    def setup_method(self):
        self._read_patcher = patch("src.worker.app._read_json")
        self._put_patcher = patch("src.worker.app._put_json")
        self.mock_read = self._read_patcher.start()
        self.mock_put = self._put_patcher.start()

    def teardown_method(self):
        self._put_patcher.stop()
        self._read_patcher.stop()

    def test_merges_all_batches(self):
        self.mock_read.side_effect = [
            {
                "symbolsProcessed": 50,
                "errors": 1,
                "crossovers": [{"symbol": "AAPL", "weeksBelow": 5}],
                "dayBelow": [{"symbol": "X", "count": 4}],
                "weekBelow": [],
                "dayAbove": [{"symbol": "GOOG", "count": 3}],
                "weekAbove": [],
            },
            {
                "symbolsProcessed": 50,
                "errors": 0,
                "crossovers": [{"symbol": "MSFT", "weeksBelow": 3}],
                "dayBelow": [],
                "weekBelow": [{"symbol": "Y", "count": 5}],
                "dayAbove": [],
                "weekAbove": [{"symbol": "TSLA", "count": 2}],
            },
        ]

        _aggregate_results("test-bucket", "2026-02-22", 2)

        assert self.mock_put.call_count == 7
        latest_data = self.mock_put.call_args_list[0][0][2]
        assert latest_data["symbolsScanned"] == 100
        assert latest_data["errors"] == 1
        assert len(latest_data["crossovers"]) == 2

    def test_crossovers_sorted_by_weeks_below_descending(self):
        self.mock_read.side_effect = [
            {"symbolsProcessed": 50, "errors": 0,
             "crossovers": [{"symbol": "LOW", "weeksBelow": 3}]},
            {"symbolsProcessed": 50, "errors": 0,
             "crossovers": [{"symbol": "HIGH", "weeksBelow": 8}]},
        ]

        _aggregate_results("b", "r", 2)

        crossovers = self.mock_put.call_args_list[0][0][2]["crossovers"]
        assert crossovers[0]["symbol"] == "HIGH"
        assert crossovers[1]["symbol"] == "LOW"

    def test_week_below_sorted_by_count_descending(self):
        self.mock_read.side_effect = [
            {"symbolsProcessed": 50, "errors": 0, "crossovers": [],
             "weekBelow": [{"symbol": "LOW", "count": 3}]},
            {"symbolsProcessed": 50, "errors": 0, "crossovers": [],
             "weekBelow": [{"symbol": "HIGH", "count": 10}]},
        ]

        _aggregate_results("b", "r", 2)

        below_data = self.mock_put.call_args_list[2][0][2]
        assert below_data["weekBelow"][0]["symbol"] == "HIGH"
        assert below_data["weekBelow"][1]["symbol"] == "LOW"

    def test_handles_missing_batch_file(self):
        self.mock_read.side_effect = [
            {"symbolsProcessed": 50, "errors": 0, "crossovers": []},
            None,
        ]

        _aggregate_results("b", "r", 2)

        latest_data = self.mock_put.call_args_list[0][0][2]
        assert latest_data["symbolsScanned"] == 50

    def test_all_batches_missing(self):
        self.mock_read.return_value = None

        _aggregate_results("b", "r", 3)

        latest_data = self.mock_put.call_args_list[0][0][2]
        assert latest_data["symbolsScanned"] == 0
        assert latest_data["errors"] == 0
        assert latest_data["crossovers"] == []

    def test_writes_latest_json(self):
        self.mock_read.return_value = EMPTY_BATCH

        _aggregate_results("mybucket", "2026-02-22", 1)

        assert self.mock_put.call_args_list[0][0][1] == "results/latest.json"

    def test_writes_latest_below_json(self):
        self.mock_read.return_value = EMPTY_BATCH

        _aggregate_results("mybucket", "2026-02-22", 1)

        assert self.mock_put.call_args_list[2][0][1] == "results/latest-below.json"

    def test_writes_latest_above_json(self):
        self.mock_read.return_value = EMPTY_BATCH

        _aggregate_results("mybucket", "2026-02-22", 1)

        assert self.mock_put.call_args_list[3][0][1] == "results/latest-above.json"

    def test_writes_archive_with_date(self):
        self.mock_read.return_value = EMPTY_BATCH

        _aggregate_results("b", "2026-02-22", 1)

        archive_key = self.mock_put.call_args_list[6][0][1]
        assert archive_key.startswith("results/")
        assert ".json" in archive_key

    def test_latest_json_has_required_fields(self):
        self.mock_read.return_value = EMPTY_BATCH

        _aggregate_results("b", "r", 1)

        data = self.mock_put.call_args_list[0][0][2]
        assert set(data.keys()) == {"scanDate", "scanTime", "symbolsScanned", "errors", "crossovers"}

    def test_latest_below_json_has_required_fields(self):
        self.mock_read.return_value = EMPTY_BATCH

        _aggregate_results("b", "r", 1)

        data = self.mock_put.call_args_list[2][0][2]
        assert set(data.keys()) == {"scanDate", "scanTime", "symbolsScanned", "errors", "dayBelow", "weekBelow"}

    def test_latest_above_json_has_required_fields(self):
        self.mock_read.return_value = EMPTY_BATCH

        _aggregate_results("b", "r", 1)

        data = self.mock_put.call_args_list[3][0][2]
        assert set(data.keys()) == {"scanDate", "scanTime", "symbolsScanned", "errors", "dayAbove", "weekAbove"}

    def test_reads_correct_batch_keys(self):
        self.mock_read.return_value = EMPTY_BATCH

        _aggregate_results("mybucket", "2026-02-22", 3)

        read_calls = self.mock_read.call_args_list
        assert read_calls[0][0] == ("mybucket", "batches/2026-02-22/batch-000.json")
        assert read_calls[1][0] == ("mybucket", "batches/2026-02-22/batch-001.json")
        assert read_calls[2][0] == ("mybucket", "batches/2026-02-22/batch-002.json")

    def test_error_counts_accumulate(self):
        self.mock_read.side_effect = [
            {"symbolsProcessed": 50, "errors": 3, "crossovers": []},
            {"symbolsProcessed": 50, "errors": 7, "crossovers": []},
            {"symbolsProcessed": 50, "errors": 5, "crossovers": []},
        ]

        _aggregate_results("b", "r", 3)

        latest_data = self.mock_put.call_args_list[0][0][2]
        assert latest_data["errors"] == 15
        assert latest_data["symbolsScanned"] == 150

    def test_day_above_merged_and_sorted_by_count_descending(self):
        self.mock_read.side_effect = [
            {"symbolsProcessed": 50, "errors": 0, "crossovers": [],
             "dayAbove": [{"symbol": "LOW", "count": 2}], "weekAbove": []},
            {"symbolsProcessed": 50, "errors": 0, "crossovers": [],
             "dayAbove": [{"symbol": "HIGH", "count": 10}], "weekAbove": []},
        ]

        _aggregate_results("b", "r", 2)

        above_data = self.mock_put.call_args_list[3][0][2]
        assert len(above_data["dayAbove"]) == 2
        assert above_data["dayAbove"][0]["symbol"] == "HIGH"
        assert above_data["dayAbove"][1]["symbol"] == "LOW"

    def test_week_above_merged_and_sorted_by_count_descending(self):
        self.mock_read.side_effect = [
            {"symbolsProcessed": 50, "errors": 0, "crossovers": [],
             "dayAbove": [], "weekAbove": [{"symbol": "LOW", "count": 1}]},
            {"symbolsProcessed": 50, "errors": 0, "crossovers": [],
             "dayAbove": [], "weekAbove": [{"symbol": "HIGH", "count": 8}]},
        ]

        _aggregate_results("b", "r", 2)

        above_data = self.mock_put.call_args_list[3][0][2]
        assert len(above_data["weekAbove"]) == 2
        assert above_data["weekAbove"][0]["symbol"] == "HIGH"
        assert above_data["weekAbove"][1]["symbol"] == "LOW"

    def test_backward_compat_missing_above_keys(self):
        self.mock_read.side_effect = [
            {"symbolsProcessed": 50, "errors": 0, "crossovers": []},
        ]

        _aggregate_results("b", "r", 1)

        above_data = self.mock_put.call_args_list[3][0][2]
        assert above_data["dayAbove"] == []
        assert above_data["weekAbove"] == []

    def test_crossdowns_merged_and_sorted_by_weeks_above_descending(self):
        self.mock_read.side_effect = [
            {"symbolsProcessed": 50, "errors": 0, "crossovers": [], "crossdowns": [{"symbol": "LOW", "weeksAbove": 3}]},
            {"symbolsProcessed": 50, "errors": 0, "crossovers": [], "crossdowns": [{"symbol": "HIGH", "weeksAbove": 8}]},
        ]

        _aggregate_results("b", "r", 2)

        crossdown_data = self.mock_put.call_args_list[1][0][2]
        assert crossdown_data["crossdowns"][0]["symbol"] == "HIGH"
        assert crossdown_data["crossdowns"][1]["symbol"] == "LOW"

    def test_writes_latest_crossdown_json(self):
        self.mock_read.return_value = EMPTY_BATCH

        _aggregate_results("mybucket", "2026-02-22", 1)

        assert self.mock_put.call_args_list[1][0][1] == "results/latest-crossdown.json"

    def test_latest_crossdown_json_has_required_fields(self):
        self.mock_read.return_value = EMPTY_BATCH

        _aggregate_results("b", "r", 1)

        data = self.mock_put.call_args_list[1][0][2]
        assert set(data.keys()) == {"scanDate", "scanTime", "symbolsScanned", "errors", "crossdowns"}

    def test_backward_compat_missing_crossdowns_key(self):
        self.mock_read.side_effect = [
            {"symbolsProcessed": 50, "errors": 0, "crossovers": []},
        ]

        _aggregate_results("b", "r", 1)

        crossdown_data = self.mock_put.call_args_list[1][0][2]
        assert crossdown_data["crossdowns"] == []

    def test_writes_latest_monthly_json(self):
        self.mock_read.return_value = EMPTY_BATCH

        _aggregate_results("mybucket", "2026-02-22", 1)

        assert self.mock_put.call_args_list[4][0][1] == "results/latest-monthly.json"

    def test_writes_latest_monthly_below_above_json(self):
        self.mock_read.return_value = EMPTY_BATCH

        _aggregate_results("mybucket", "2026-02-22", 1)

        assert self.mock_put.call_args_list[5][0][1] == "results/latest-monthly-below-above.json"

    def test_latest_monthly_json_has_required_fields(self):
        self.mock_read.return_value = EMPTY_BATCH

        _aggregate_results("b", "r", 1)

        data = self.mock_put.call_args_list[4][0][2]
        assert set(data.keys()) == {"scanDate", "scanTime", "symbolsScanned", "errors", "monthCrossovers", "monthCrossdowns"}

    def test_latest_monthly_below_above_json_has_required_fields(self):
        self.mock_read.return_value = EMPTY_BATCH

        _aggregate_results("b", "r", 1)

        data = self.mock_put.call_args_list[5][0][2]
        assert set(data.keys()) == {"scanDate", "scanTime", "symbolsScanned", "errors", "monthBelow", "monthAbove"}

    def test_month_crossovers_sorted_by_months_below_descending(self):
        self.mock_read.side_effect = [
            {**EMPTY_BATCH, "monthCrossovers": [{"symbol": "LOW", "monthsBelow": 2}]},
            {**EMPTY_BATCH, "monthCrossovers": [{"symbol": "HIGH", "monthsBelow": 5}]},
        ]

        _aggregate_results("b", "r", 2)

        monthly_data = self.mock_put.call_args_list[4][0][2]
        assert monthly_data["monthCrossovers"][0]["symbol"] == "HIGH"
        assert monthly_data["monthCrossovers"][1]["symbol"] == "LOW"

    def test_month_crossdowns_sorted_by_months_above_descending(self):
        self.mock_read.side_effect = [
            {**EMPTY_BATCH, "monthCrossdowns": [{"symbol": "LOW", "monthsAbove": 1}]},
            {**EMPTY_BATCH, "monthCrossdowns": [{"symbol": "HIGH", "monthsAbove": 4}]},
        ]

        _aggregate_results("b", "r", 2)

        monthly_data = self.mock_put.call_args_list[4][0][2]
        assert monthly_data["monthCrossdowns"][0]["symbol"] == "HIGH"
        assert monthly_data["monthCrossdowns"][1]["symbol"] == "LOW"

    def test_backward_compat_missing_monthly_keys(self):
        self.mock_read.side_effect = [
            {"symbolsProcessed": 50, "errors": 0, "crossovers": []},
        ]

        _aggregate_results("b", "r", 1)

        monthly_data = self.mock_put.call_args_list[4][0][2]
        assert monthly_data["monthCrossovers"] == []
        assert monthly_data["monthCrossdowns"] == []
        monthly_ba_data = self.mock_put.call_args_list[5][0][2]
        assert monthly_ba_data["monthBelow"] == []
        assert monthly_ba_data["monthAbove"] == []
