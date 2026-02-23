import json
from unittest.mock import patch, MagicMock

from src.worker.app import (
    lambda_handler,
    _process_batch,
    _aggregate_results,
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

# Reusable empty batch for aggregation tests
EMPTY_BATCH = {"symbolsProcessed": 10, "errors": 0, "crossovers": [], "below": [], "dayAbove": [], "weekAbove": []}


def _timestamps_for(closes):
    return list(range(len(closes)))


class TestProcessBatch:

    def setup_method(self):
        self._yahoo_patcher = patch("src.worker.app.yahoo")
        self._time_patcher = patch("src.worker.app.time")
        self.mock_yahoo = self._yahoo_patcher.start()
        self.mock_time = self._time_patcher.start()
        self.mock_yahoo.fetch_daily_candles.return_value = None

    def teardown_method(self):
        self._time_patcher.stop()
        self._yahoo_patcher.stop()

    def test_crossover_detected(self):
        self.mock_yahoo.fetch_weekly_candles.return_value = (CROSSOVER_CLOSES, _timestamps_for(CROSSOVER_CLOSES))

        crossovers, below, day_above, week_above, errors = _process_batch(["TEST"])

        assert len(crossovers) == 1
        assert crossovers[0]["symbol"] == "TEST"
        assert crossovers[0]["close"] == 106.0
        assert crossovers[0]["weeksBelow"] == 3
        assert crossovers[0]["pctAbove"] > 0
        assert len(errors) == 0

    def test_crossover_output_fields(self):
        self.mock_yahoo.fetch_weekly_candles.return_value = (CROSSOVER_CLOSES, _timestamps_for(CROSSOVER_CLOSES))

        crossovers, _, _, _, _ = _process_batch(["AAPL"])

        entry = crossovers[0]
        assert set(entry.keys()) == {"symbol", "close", "ema", "pctAbove", "weeksBelow"}
        assert isinstance(entry["close"], float)
        assert isinstance(entry["ema"], float)
        assert isinstance(entry["pctAbove"], float)
        assert isinstance(entry["weeksBelow"], int)

    def test_crossover_ema_rounded_to_4_decimals(self):
        self.mock_yahoo.fetch_weekly_candles.return_value = (CROSSOVER_CLOSES, _timestamps_for(CROSSOVER_CLOSES))

        crossovers, _, _, _, _ = _process_batch(["X"])

        ema_str = str(crossovers[0]["ema"])
        decimals = ema_str.split(".")[-1] if "." in ema_str else ""
        assert len(decimals) <= 4

    def test_crossover_pct_above_rounded_to_2_decimals(self):
        self.mock_yahoo.fetch_weekly_candles.return_value = (CROSSOVER_CLOSES, _timestamps_for(CROSSOVER_CLOSES))

        crossovers, _, _, _, _ = _process_batch(["X"])

        pct = crossovers[0]["pctAbove"]
        assert pct == round(pct, 2)

    def test_below_detected_with_minimum_weeks(self):
        self.mock_yahoo.fetch_weekly_candles.return_value = (BELOW_CLOSES, _timestamps_for(BELOW_CLOSES))

        crossovers, below, day_above, week_above, errors = _process_batch(["TEST"])

        assert len(below) == 1
        assert below[0]["symbol"] == "TEST"
        assert below[0]["weeksBelow"] == 3
        assert below[0]["pctBelow"] > 0

    def test_below_output_fields(self):
        self.mock_yahoo.fetch_weekly_candles.return_value = (BELOW_CLOSES, _timestamps_for(BELOW_CLOSES))

        _, below, _, _, _ = _process_batch(["X"])

        entry = below[0]
        assert set(entry.keys()) == {"symbol", "close", "ema", "pctBelow", "weeksBelow"}

    def test_below_not_detected_under_threshold(self):
        closes = [50.0, 52.0, 54.0, 56.0, 58.0, 56.0, 53.0]
        self.mock_yahoo.fetch_weekly_candles.return_value = (closes, _timestamps_for(closes))

        _, below, _, _, _ = _process_batch(["TEST"])

        assert len(below) == 0

    def test_below_two_weeks_not_detected(self):
        closes = [100.0, 102.0, 104.0, 106.0, 108.0, 100.0, 101.0]
        self.mock_yahoo.fetch_weekly_candles.return_value = (closes, _timestamps_for(closes))

        _, below, _, _, _ = _process_batch(["TEST"])

        assert len(below) == 0

    def test_uptrend_no_crossover_no_below(self):
        self.mock_yahoo.fetch_weekly_candles.return_value = (UPTREND_CLOSES, _timestamps_for(UPTREND_CLOSES))

        crossovers, below, day_above, week_above, errors = _process_batch(["BULL"])

        assert len(crossovers) == 0
        assert len(below) == 0
        assert len(errors) == 0

    def test_fetch_failure_records_error(self):
        self.mock_yahoo.fetch_weekly_candles.return_value = None

        crossovers, below, day_above, week_above, errors = _process_batch(["FAIL"])

        assert len(crossovers) == 0
        assert len(below) == 0
        assert len(day_above) == 0
        assert len(week_above) == 0
        assert len(errors) == 1
        assert errors[0]["symbol"] == "FAIL"
        assert "error" in errors[0]

    def test_insufficient_data_skipped_no_error(self):
        self.mock_yahoo.fetch_weekly_candles.return_value = ([100.0, 101.0, 102.0], [1, 2, 3])

        crossovers, below, day_above, week_above, errors = _process_batch(["SHORT"])

        assert len(crossovers) == 0
        assert len(below) == 0
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

        crossovers, below, day_above, week_above, errors = _process_batch(["OK", "FAIL", "OK2"])

        assert len(crossovers) == 2
        assert len(errors) == 1
        assert errors[0]["symbol"] == "FAIL"

    def test_empty_batch(self):
        crossovers, below, day_above, week_above, errors = _process_batch([])

        assert crossovers == []
        assert below == []
        assert day_above == []
        assert week_above == []
        assert errors == []
        self.mock_yahoo.fetch_weekly_candles.assert_not_called()
        self.mock_yahoo.fetch_daily_candles.assert_not_called()

    def test_all_failures(self):
        self.mock_yahoo.fetch_weekly_candles.return_value = None

        crossovers, below, day_above, week_above, errors = _process_batch(["A", "B", "C"])

        assert len(crossovers) == 0
        assert len(below) == 0
        assert len(day_above) == 0
        assert len(week_above) == 0
        assert len(errors) == 3

    def test_day_above_detected(self):
        self.mock_yahoo.fetch_daily_candles.return_value = (UPTREND_CLOSES, _timestamps_for(UPTREND_CLOSES))
        self.mock_yahoo.fetch_weekly_candles.return_value = (UPTREND_CLOSES, _timestamps_for(UPTREND_CLOSES))

        _, _, day_above, _, _ = _process_batch(["BULL"])

        assert len(day_above) == 1
        assert day_above[0]["symbol"] == "BULL"
        assert day_above[0]["count"] == 6
        assert day_above[0]["pctAbove"] > 0

    def test_day_above_output_fields(self):
        self.mock_yahoo.fetch_daily_candles.return_value = (UPTREND_CLOSES, _timestamps_for(UPTREND_CLOSES))
        self.mock_yahoo.fetch_weekly_candles.return_value = (UPTREND_CLOSES, _timestamps_for(UPTREND_CLOSES))

        _, _, day_above, _, _ = _process_batch(["X"])

        entry = day_above[0]
        assert set(entry.keys()) == {"symbol", "close", "ema", "pctAbove", "count"}
        assert isinstance(entry["count"], int)

    def test_week_above_detected(self):
        self.mock_yahoo.fetch_weekly_candles.return_value = (UPTREND_CLOSES, _timestamps_for(UPTREND_CLOSES))

        _, _, _, week_above, _ = _process_batch(["BULL"])

        assert len(week_above) == 1
        assert week_above[0]["symbol"] == "BULL"
        assert week_above[0]["count"] == 6
        assert week_above[0]["pctAbove"] > 0

    def test_week_above_output_fields(self):
        self.mock_yahoo.fetch_weekly_candles.return_value = (UPTREND_CLOSES, _timestamps_for(UPTREND_CLOSES))

        _, _, _, week_above, _ = _process_batch(["X"])

        entry = week_above[0]
        assert set(entry.keys()) == {"symbol", "close", "ema", "pctAbove", "count"}

    def test_daily_fail_still_processes_weekly(self):
        self.mock_yahoo.fetch_daily_candles.return_value = None
        self.mock_yahoo.fetch_weekly_candles.return_value = (CROSSOVER_CLOSES, _timestamps_for(CROSSOVER_CLOSES))

        crossovers, _, _, _, errors = _process_batch(["TEST"])

        assert len(crossovers) == 1
        assert len(errors) == 0

    def test_weekly_fail_still_processes_daily(self):
        self.mock_yahoo.fetch_daily_candles.return_value = (UPTREND_CLOSES, _timestamps_for(UPTREND_CLOSES))
        self.mock_yahoo.fetch_weekly_candles.return_value = None

        _, _, day_above, _, errors = _process_batch(["TEST"])

        assert len(day_above) == 1
        assert len(errors) == 0

    def test_both_fail_records_error(self):
        self.mock_yahoo.fetch_daily_candles.return_value = None
        self.mock_yahoo.fetch_weekly_candles.return_value = None

        _, _, _, _, errors = _process_batch(["FAIL"])

        assert len(errors) == 1
        assert errors[0]["symbol"] == "FAIL"

    def test_below_ema_not_in_above_lists(self):
        self.mock_yahoo.fetch_daily_candles.return_value = (BELOW_CLOSES, _timestamps_for(BELOW_CLOSES))
        self.mock_yahoo.fetch_weekly_candles.return_value = (BELOW_CLOSES, _timestamps_for(BELOW_CLOSES))

        _, _, day_above, week_above, _ = _process_batch(["BEAR"])

        assert len(day_above) == 0
        assert len(week_above) == 0


class TestWriteBatchResults:

    @patch("src.worker.app.s3")
    def test_writes_to_correct_key(self, mock_s3):
        _write_batch_results("mybucket", "2026-02-22", 5, 50, 2, [], [], [], [])

        mock_s3.put_object.assert_called_once()
        kwargs = mock_s3.put_object.call_args[1]
        assert kwargs["Bucket"] == "mybucket"
        assert kwargs["Key"] == "batches/2026-02-22/batch-005.json"

    @patch("src.worker.app.s3")
    def test_batch_index_zero_padded(self, mock_s3):
        _write_batch_results("b", "r", 0, 10, 0, [], [], [], [])
        assert "batch-000.json" in mock_s3.put_object.call_args[1]["Key"]

        _write_batch_results("b", "r", 99, 10, 0, [], [], [], [])
        assert "batch-099.json" in mock_s3.put_object.call_args[1]["Key"]

        _write_batch_results("b", "r", 159, 10, 0, [], [], [], [])
        assert "batch-159.json" in mock_s3.put_object.call_args[1]["Key"]

    @patch("src.worker.app.s3")
    def test_body_contains_all_fields(self, mock_s3):
        crossovers = [{"symbol": "AAPL", "weeksBelow": 3}]
        below = [{"symbol": "MSFT", "weeksBelow": 4}]
        day_above = [{"symbol": "GOOG", "count": 5}]
        week_above = [{"symbol": "TSLA", "count": 3}]

        _write_batch_results("b", "r", 0, 50, 2, crossovers, below, day_above, week_above)

        body = json.loads(mock_s3.put_object.call_args[1]["Body"])
        assert body["batchIndex"] == 0
        assert body["symbolsProcessed"] == 50
        assert body["errors"] == 2
        assert body["crossovers"] == crossovers
        assert body["below"] == below
        assert body["dayAbove"] == day_above
        assert body["weekAbove"] == week_above


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
        self._env_patcher.start()
        self.mock_process = self._process_patcher.start()
        self.mock_write = self._write_patcher.start()
        self.mock_errors = self._errors_patcher.start()
        self.mock_agg = self._agg_patcher.start()

    def teardown_method(self):
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
        self.mock_process.return_value = ([], [], [], [], [])
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
        self.mock_process.return_value = ([], [], [], [], [])
        event = self._sqs_event([{
            "runId": "2026-02-22",
            "batchIndex": 2,
            "totalBatches": 3,
            "symbols": ["AAPL"],
        }])

        lambda_handler(event, None)

        self.mock_agg.assert_called_once_with("test-bucket", "2026-02-22", 3)

    def test_non_last_batch_skips_aggregation(self):
        self.mock_process.return_value = ([], [], [], [], [])
        event = self._sqs_event([{
            "runId": "2026-02-22",
            "batchIndex": 0,
            "totalBatches": 3,
            "symbols": ["AAPL"],
        }])

        lambda_handler(event, None)

        self.mock_agg.assert_not_called()

    def test_errors_written_when_present(self):
        self.mock_process.return_value = ([], [], [], [], [{"symbol": "BAD", "error": "fail"}])
        event = self._sqs_event([{
            "runId": "2026-02-22",
            "batchIndex": 0,
            "totalBatches": 1,
            "symbols": ["BAD"],
        }])

        lambda_handler(event, None)

        self.mock_errors.assert_called_once()

    def test_errors_not_written_when_empty(self):
        self.mock_process.return_value = ([], [], [], [], [])
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
        self.mock_process.return_value = ([], [], [], [], [])
        event = self._sqs_event([{
            "runId": "2026-02-22",
            "batchIndex": 0,
            "totalBatches": 1,
            "symbols": ["AAPL"],
        }])

        lambda_handler(event, None)

        self.mock_agg.assert_called_once()


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
                "below": [{"symbol": "X", "weeksBelow": 4}],
                "dayAbove": [{"symbol": "GOOG", "count": 3}],
                "weekAbove": [],
            },
            {
                "symbolsProcessed": 50,
                "errors": 0,
                "crossovers": [{"symbol": "MSFT", "weeksBelow": 3}],
                "below": [],
                "dayAbove": [],
                "weekAbove": [{"symbol": "TSLA", "count": 2}],
            },
        ]

        _aggregate_results("test-bucket", "2026-02-22", 2)

        assert self.mock_put.call_count == 4
        latest_data = self.mock_put.call_args_list[0][0][2]
        assert latest_data["symbolsScanned"] == 100
        assert latest_data["errors"] == 1
        assert len(latest_data["crossovers"]) == 2

    def test_crossovers_sorted_by_weeks_below_descending(self):
        self.mock_read.side_effect = [
            {"symbolsProcessed": 50, "errors": 0,
             "crossovers": [{"symbol": "LOW", "weeksBelow": 3}], "below": []},
            {"symbolsProcessed": 50, "errors": 0,
             "crossovers": [{"symbol": "HIGH", "weeksBelow": 8}], "below": []},
        ]

        _aggregate_results("b", "r", 2)

        crossovers = self.mock_put.call_args_list[0][0][2]["crossovers"]
        assert crossovers[0]["symbol"] == "HIGH"
        assert crossovers[1]["symbol"] == "LOW"

    def test_below_sorted_by_weeks_below_descending(self):
        self.mock_read.side_effect = [
            {"symbolsProcessed": 50, "errors": 0, "crossovers": [],
             "below": [{"symbol": "LOW", "weeksBelow": 3}]},
            {"symbolsProcessed": 50, "errors": 0, "crossovers": [],
             "below": [{"symbol": "HIGH", "weeksBelow": 10}]},
        ]

        _aggregate_results("b", "r", 2)

        below = self.mock_put.call_args_list[1][0][2]["below"]
        assert below[0]["symbol"] == "HIGH"
        assert below[1]["symbol"] == "LOW"

    def test_handles_missing_batch_file(self):
        self.mock_read.side_effect = [
            {"symbolsProcessed": 50, "errors": 0, "crossovers": [], "below": []},
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

        assert self.mock_put.call_args_list[1][0][1] == "results/latest-below.json"

    def test_writes_latest_above_json(self):
        self.mock_read.return_value = EMPTY_BATCH

        _aggregate_results("mybucket", "2026-02-22", 1)

        assert self.mock_put.call_args_list[2][0][1] == "results/latest-above.json"

    def test_writes_archive_with_date(self):
        self.mock_read.return_value = EMPTY_BATCH

        _aggregate_results("b", "2026-02-22", 1)

        archive_key = self.mock_put.call_args_list[3][0][1]
        assert archive_key.startswith("results/")
        assert ".json" in archive_key

    def test_sneak_peek_always_true(self):
        self.mock_read.return_value = EMPTY_BATCH

        _aggregate_results("b", "r", 1)

        latest_data = self.mock_put.call_args_list[0][0][2]
        assert latest_data["sneakPeek"] is True

    def test_latest_json_has_required_fields(self):
        self.mock_read.return_value = EMPTY_BATCH

        _aggregate_results("b", "r", 1)

        data = self.mock_put.call_args_list[0][0][2]
        assert set(data.keys()) == {"scanDate", "scanTime", "sneakPeek", "symbolsScanned", "errors", "crossovers"}

    def test_latest_below_json_has_required_fields(self):
        self.mock_read.return_value = EMPTY_BATCH

        _aggregate_results("b", "r", 1)

        data = self.mock_put.call_args_list[1][0][2]
        assert set(data.keys()) == {"scanDate", "scanTime", "sneakPeek", "symbolsScanned", "errors", "below"}

    def test_latest_above_json_has_required_fields(self):
        self.mock_read.return_value = EMPTY_BATCH

        _aggregate_results("b", "r", 1)

        data = self.mock_put.call_args_list[2][0][2]
        assert set(data.keys()) == {"scanDate", "scanTime", "sneakPeek", "symbolsScanned", "errors", "dayAbove", "weekAbove"}

    def test_reads_correct_batch_keys(self):
        self.mock_read.return_value = EMPTY_BATCH

        _aggregate_results("mybucket", "2026-02-22", 3)

        read_calls = self.mock_read.call_args_list
        assert read_calls[0][0] == ("mybucket", "batches/2026-02-22/batch-000.json")
        assert read_calls[1][0] == ("mybucket", "batches/2026-02-22/batch-001.json")
        assert read_calls[2][0] == ("mybucket", "batches/2026-02-22/batch-002.json")

    def test_error_counts_accumulate(self):
        self.mock_read.side_effect = [
            {"symbolsProcessed": 50, "errors": 3, "crossovers": [], "below": []},
            {"symbolsProcessed": 50, "errors": 7, "crossovers": [], "below": []},
            {"symbolsProcessed": 50, "errors": 5, "crossovers": [], "below": []},
        ]

        _aggregate_results("b", "r", 3)

        latest_data = self.mock_put.call_args_list[0][0][2]
        assert latest_data["errors"] == 15
        assert latest_data["symbolsScanned"] == 150

    def test_day_above_merged_and_sorted_by_count_descending(self):
        self.mock_read.side_effect = [
            {"symbolsProcessed": 50, "errors": 0, "crossovers": [], "below": [],
             "dayAbove": [{"symbol": "LOW", "count": 2}], "weekAbove": []},
            {"symbolsProcessed": 50, "errors": 0, "crossovers": [], "below": [],
             "dayAbove": [{"symbol": "HIGH", "count": 10}], "weekAbove": []},
        ]

        _aggregate_results("b", "r", 2)

        above_data = self.mock_put.call_args_list[2][0][2]
        assert len(above_data["dayAbove"]) == 2
        assert above_data["dayAbove"][0]["symbol"] == "HIGH"
        assert above_data["dayAbove"][1]["symbol"] == "LOW"

    def test_week_above_merged_and_sorted_by_count_descending(self):
        self.mock_read.side_effect = [
            {"symbolsProcessed": 50, "errors": 0, "crossovers": [], "below": [],
             "dayAbove": [], "weekAbove": [{"symbol": "LOW", "count": 1}]},
            {"symbolsProcessed": 50, "errors": 0, "crossovers": [], "below": [],
             "dayAbove": [], "weekAbove": [{"symbol": "HIGH", "count": 8}]},
        ]

        _aggregate_results("b", "r", 2)

        above_data = self.mock_put.call_args_list[2][0][2]
        assert len(above_data["weekAbove"]) == 2
        assert above_data["weekAbove"][0]["symbol"] == "HIGH"
        assert above_data["weekAbove"][1]["symbol"] == "LOW"

    def test_backward_compat_missing_above_keys(self):
        self.mock_read.side_effect = [
            {"symbolsProcessed": 50, "errors": 0, "crossovers": [], "below": []},
        ]

        _aggregate_results("b", "r", 1)

        above_data = self.mock_put.call_args_list[2][0][2]
        assert above_data["dayAbove"] == []
        assert above_data["weekAbove"] == []
