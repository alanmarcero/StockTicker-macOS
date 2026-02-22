import json
from unittest.mock import patch, MagicMock, call

from src.worker.app import (
    lambda_handler,
    _process_batch,
    _aggregate_results,
    _write_batch_results,
    _write_errors,
)


# -- Shared test data --

# Crossover: 3 weeks below then cross above
# First 5: [100, 102, 104, 106, 108] -> SMA = 104.0
# idx5: close=100, EMA=102.667 -> below
# idx6: close=101, EMA=102.111 -> below
# idx7: close=101, EMA=101.741 -> below
# idx8: close=106, EMA=103.160 -> above (crossover, 3 weeks below)
CROSSOVER_CLOSES = [100.0, 102.0, 104.0, 106.0, 108.0, 100.0, 101.0, 101.0, 106.0]

# Steady below: 3 weeks below EMA (no crossover)
BELOW_CLOSES = [100.0, 102.0, 104.0, 106.0, 108.0, 100.0, 101.0, 101.0]

# Uptrend: all above EMA (no crossover, no below)
UPTREND_CLOSES = [10.0, 20.0, 30.0, 40.0, 50.0, 60.0, 70.0, 80.0, 90.0, 100.0]


def _timestamps_for(closes):
    return list(range(len(closes)))


class TestProcessBatch:

    @patch("src.worker.app.yahoo")
    @patch("src.worker.app.time")
    def test_crossover_detected(self, mock_time, mock_yahoo):
        mock_yahoo.fetch_weekly_candles.return_value = (CROSSOVER_CLOSES, _timestamps_for(CROSSOVER_CLOSES))

        crossovers, below, errors = _process_batch(["TEST"])

        assert len(crossovers) == 1
        assert crossovers[0]["symbol"] == "TEST"
        assert crossovers[0]["close"] == 106.0
        assert crossovers[0]["weeksBelow"] == 3
        assert crossovers[0]["pctAbove"] > 0
        assert len(errors) == 0

    @patch("src.worker.app.yahoo")
    @patch("src.worker.app.time")
    def test_crossover_output_fields(self, mock_time, mock_yahoo):
        mock_yahoo.fetch_weekly_candles.return_value = (CROSSOVER_CLOSES, _timestamps_for(CROSSOVER_CLOSES))

        crossovers, _, _ = _process_batch(["AAPL"])

        entry = crossovers[0]
        assert set(entry.keys()) == {"symbol", "close", "ema", "pctAbove", "weeksBelow"}
        assert isinstance(entry["close"], float)
        assert isinstance(entry["ema"], float)
        assert isinstance(entry["pctAbove"], float)
        assert isinstance(entry["weeksBelow"], int)

    @patch("src.worker.app.yahoo")
    @patch("src.worker.app.time")
    def test_crossover_ema_rounded_to_4_decimals(self, mock_time, mock_yahoo):
        mock_yahoo.fetch_weekly_candles.return_value = (CROSSOVER_CLOSES, _timestamps_for(CROSSOVER_CLOSES))

        crossovers, _, _ = _process_batch(["X"])

        ema_str = str(crossovers[0]["ema"])
        decimals = ema_str.split(".")[-1] if "." in ema_str else ""
        assert len(decimals) <= 4

    @patch("src.worker.app.yahoo")
    @patch("src.worker.app.time")
    def test_crossover_pct_above_rounded_to_2_decimals(self, mock_time, mock_yahoo):
        mock_yahoo.fetch_weekly_candles.return_value = (CROSSOVER_CLOSES, _timestamps_for(CROSSOVER_CLOSES))

        crossovers, _, _ = _process_batch(["X"])

        pct = crossovers[0]["pctAbove"]
        assert pct == round(pct, 2)

    @patch("src.worker.app.yahoo")
    @patch("src.worker.app.time")
    def test_below_detected_with_minimum_weeks(self, mock_time, mock_yahoo):
        mock_yahoo.fetch_weekly_candles.return_value = (BELOW_CLOSES, _timestamps_for(BELOW_CLOSES))

        crossovers, below, errors = _process_batch(["TEST"])

        assert len(below) == 1
        assert below[0]["symbol"] == "TEST"
        assert below[0]["weeksBelow"] == 3
        assert below[0]["pctBelow"] > 0

    @patch("src.worker.app.yahoo")
    @patch("src.worker.app.time")
    def test_below_output_fields(self, mock_time, mock_yahoo):
        mock_yahoo.fetch_weekly_candles.return_value = (BELOW_CLOSES, _timestamps_for(BELOW_CLOSES))

        _, below, _ = _process_batch(["X"])

        entry = below[0]
        assert set(entry.keys()) == {"symbol", "close", "ema", "pctBelow", "weeksBelow"}

    @patch("src.worker.app.yahoo")
    @patch("src.worker.app.time")
    def test_below_not_detected_under_threshold(self, mock_time, mock_yahoo):
        # Only 1 week below — under the 3-week threshold
        closes = [50.0, 52.0, 54.0, 56.0, 58.0, 56.0, 53.0]
        mock_yahoo.fetch_weekly_candles.return_value = (closes, _timestamps_for(closes))

        _, below, _ = _process_batch(["TEST"])

        assert len(below) == 0

    @patch("src.worker.app.yahoo")
    @patch("src.worker.app.time")
    def test_below_two_weeks_not_detected(self, mock_time, mock_yahoo):
        # 2 weeks below — still under threshold (chop)
        closes = [100.0, 102.0, 104.0, 106.0, 108.0, 100.0, 101.0]
        mock_yahoo.fetch_weekly_candles.return_value = (closes, _timestamps_for(closes))

        _, below, _ = _process_batch(["TEST"])

        assert len(below) == 0

    @patch("src.worker.app.yahoo")
    @patch("src.worker.app.time")
    def test_uptrend_no_crossover_no_below(self, mock_time, mock_yahoo):
        mock_yahoo.fetch_weekly_candles.return_value = (UPTREND_CLOSES, _timestamps_for(UPTREND_CLOSES))

        crossovers, below, errors = _process_batch(["BULL"])

        assert len(crossovers) == 0
        assert len(below) == 0
        assert len(errors) == 0

    @patch("src.worker.app.yahoo")
    @patch("src.worker.app.time")
    def test_fetch_failure_records_error(self, mock_time, mock_yahoo):
        mock_yahoo.fetch_weekly_candles.return_value = None

        crossovers, below, errors = _process_batch(["FAIL"])

        assert len(crossovers) == 0
        assert len(below) == 0
        assert len(errors) == 1
        assert errors[0]["symbol"] == "FAIL"
        assert "error" in errors[0]

    @patch("src.worker.app.yahoo")
    @patch("src.worker.app.time")
    def test_insufficient_data_skipped_no_error(self, mock_time, mock_yahoo):
        mock_yahoo.fetch_weekly_candles.return_value = ([100.0, 101.0, 102.0], [1, 2, 3])

        crossovers, below, errors = _process_batch(["SHORT"])

        assert len(crossovers) == 0
        assert len(below) == 0
        assert len(errors) == 0

    @patch("src.worker.app.yahoo")
    @patch("src.worker.app.time")
    def test_multiple_symbols_rate_limited(self, mock_time, mock_yahoo):
        mock_yahoo.fetch_weekly_candles.return_value = ([50.0] * 10, list(range(10)))

        _process_batch(["A", "B", "C"])

        # sleep(1) called between symbols (not before the first)
        assert mock_time.sleep.call_count == 2
        mock_time.sleep.assert_called_with(1)

    @patch("src.worker.app.yahoo")
    @patch("src.worker.app.time")
    def test_single_symbol_no_sleep(self, mock_time, mock_yahoo):
        mock_yahoo.fetch_weekly_candles.return_value = ([50.0] * 10, list(range(10)))

        _process_batch(["ONLY"])

        mock_time.sleep.assert_not_called()

    @patch("src.worker.app.yahoo")
    @patch("src.worker.app.time")
    def test_mixed_success_and_failure(self, mock_time, mock_yahoo):
        def side_effect(symbol):
            if symbol == "FAIL":
                return None
            return (CROSSOVER_CLOSES, _timestamps_for(CROSSOVER_CLOSES))

        mock_yahoo.fetch_weekly_candles.side_effect = side_effect

        crossovers, below, errors = _process_batch(["OK", "FAIL", "OK2"])

        assert len(crossovers) == 2
        assert len(errors) == 1
        assert errors[0]["symbol"] == "FAIL"

    @patch("src.worker.app.yahoo")
    @patch("src.worker.app.time")
    def test_empty_batch(self, mock_time, mock_yahoo):
        crossovers, below, errors = _process_batch([])

        assert crossovers == []
        assert below == []
        assert errors == []
        mock_yahoo.fetch_weekly_candles.assert_not_called()

    @patch("src.worker.app.yahoo")
    @patch("src.worker.app.time")
    def test_all_failures(self, mock_time, mock_yahoo):
        mock_yahoo.fetch_weekly_candles.return_value = None

        crossovers, below, errors = _process_batch(["A", "B", "C"])

        assert len(crossovers) == 0
        assert len(below) == 0
        assert len(errors) == 3


class TestWriteBatchResults:

    @patch("src.worker.app.s3")
    def test_writes_to_correct_key(self, mock_s3):
        _write_batch_results("mybucket", "2026-02-22", 5, 50, 2, [], [])

        mock_s3.put_object.assert_called_once()
        kwargs = mock_s3.put_object.call_args[1]
        assert kwargs["Bucket"] == "mybucket"
        assert kwargs["Key"] == "batches/2026-02-22/batch-005.json"

    @patch("src.worker.app.s3")
    def test_batch_index_zero_padded(self, mock_s3):
        _write_batch_results("b", "r", 0, 10, 0, [], [])
        assert "batch-000.json" in mock_s3.put_object.call_args[1]["Key"]

        _write_batch_results("b", "r", 99, 10, 0, [], [])
        assert "batch-099.json" in mock_s3.put_object.call_args[1]["Key"]

        _write_batch_results("b", "r", 159, 10, 0, [], [])
        assert "batch-159.json" in mock_s3.put_object.call_args[1]["Key"]

    @patch("src.worker.app.s3")
    def test_body_contains_all_fields(self, mock_s3):
        crossovers = [{"symbol": "AAPL", "weeksBelow": 3}]
        below = [{"symbol": "MSFT", "weeksBelow": 4}]

        _write_batch_results("b", "r", 0, 50, 2, crossovers, below)

        body = json.loads(mock_s3.put_object.call_args[1]["Body"])
        assert body["batchIndex"] == 0
        assert body["symbolsProcessed"] == 50
        assert body["errors"] == 2
        assert body["crossovers"] == crossovers
        assert body["below"] == below


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

    def _sqs_event(self, messages: list[dict]) -> dict:
        return {
            "Records": [
                {"body": json.dumps(msg)} for msg in messages
            ]
        }

    @patch.dict("os.environ", {"BUCKET_NAME": "test-bucket"})
    @patch("src.worker.app._aggregate_results")
    @patch("src.worker.app._write_errors")
    @patch("src.worker.app._write_batch_results")
    @patch("src.worker.app._process_batch")
    def test_processes_sqs_message(self, mock_process, mock_write, mock_errors, mock_agg):
        mock_process.return_value = ([], [], [])
        event = self._sqs_event([{
            "runId": "2026-02-22",
            "batchIndex": 0,
            "totalBatches": 3,
            "symbols": ["AAPL", "MSFT"],
        }])

        result = lambda_handler(event, None)

        assert result["statusCode"] == 200
        mock_process.assert_called_once_with(["AAPL", "MSFT"])
        mock_write.assert_called_once()

    @patch.dict("os.environ", {"BUCKET_NAME": "test-bucket"})
    @patch("src.worker.app._aggregate_results")
    @patch("src.worker.app._write_errors")
    @patch("src.worker.app._write_batch_results")
    @patch("src.worker.app._process_batch")
    def test_last_batch_triggers_aggregation(self, mock_process, mock_write, mock_errors, mock_agg):
        mock_process.return_value = ([], [], [])
        event = self._sqs_event([{
            "runId": "2026-02-22",
            "batchIndex": 2,
            "totalBatches": 3,
            "symbols": ["AAPL"],
        }])

        lambda_handler(event, None)

        mock_agg.assert_called_once_with("test-bucket", "2026-02-22", 3)

    @patch.dict("os.environ", {"BUCKET_NAME": "test-bucket"})
    @patch("src.worker.app._aggregate_results")
    @patch("src.worker.app._write_errors")
    @patch("src.worker.app._write_batch_results")
    @patch("src.worker.app._process_batch")
    def test_non_last_batch_skips_aggregation(self, mock_process, mock_write, mock_errors, mock_agg):
        mock_process.return_value = ([], [], [])
        event = self._sqs_event([{
            "runId": "2026-02-22",
            "batchIndex": 0,
            "totalBatches": 3,
            "symbols": ["AAPL"],
        }])

        lambda_handler(event, None)

        mock_agg.assert_not_called()

    @patch.dict("os.environ", {"BUCKET_NAME": "test-bucket"})
    @patch("src.worker.app._aggregate_results")
    @patch("src.worker.app._write_errors")
    @patch("src.worker.app._write_batch_results")
    @patch("src.worker.app._process_batch")
    def test_errors_written_when_present(self, mock_process, mock_write, mock_errors, mock_agg):
        mock_process.return_value = ([], [], [{"symbol": "BAD", "error": "fail"}])
        event = self._sqs_event([{
            "runId": "2026-02-22",
            "batchIndex": 0,
            "totalBatches": 1,
            "symbols": ["BAD"],
        }])

        lambda_handler(event, None)

        mock_errors.assert_called_once()

    @patch.dict("os.environ", {"BUCKET_NAME": "test-bucket"})
    @patch("src.worker.app._aggregate_results")
    @patch("src.worker.app._write_errors")
    @patch("src.worker.app._write_batch_results")
    @patch("src.worker.app._process_batch")
    def test_errors_not_written_when_empty(self, mock_process, mock_write, mock_errors, mock_agg):
        mock_process.return_value = ([], [], [])
        event = self._sqs_event([{
            "runId": "2026-02-22",
            "batchIndex": 0,
            "totalBatches": 1,
            "symbols": ["AAPL"],
        }])

        lambda_handler(event, None)

        mock_errors.assert_not_called()

    @patch.dict("os.environ", {"BUCKET_NAME": "test-bucket"})
    @patch("src.worker.app._aggregate_results")
    @patch("src.worker.app._write_errors")
    @patch("src.worker.app._write_batch_results")
    @patch("src.worker.app._process_batch")
    def test_empty_records(self, mock_process, mock_write, mock_errors, mock_agg):
        result = lambda_handler({"Records": []}, None)

        assert result["statusCode"] == 200
        mock_process.assert_not_called()

    @patch.dict("os.environ", {"BUCKET_NAME": "test-bucket"})
    @patch("src.worker.app._aggregate_results")
    @patch("src.worker.app._write_errors")
    @patch("src.worker.app._write_batch_results")
    @patch("src.worker.app._process_batch")
    def test_single_batch_total_triggers_aggregation(self, mock_process, mock_write, mock_errors, mock_agg):
        mock_process.return_value = ([], [], [])
        event = self._sqs_event([{
            "runId": "2026-02-22",
            "batchIndex": 0,
            "totalBatches": 1,
            "symbols": ["AAPL"],
        }])

        lambda_handler(event, None)

        mock_agg.assert_called_once()


class TestAggregateResults:

    @patch("src.worker.app._put_json")
    @patch("src.worker.app._read_json")
    def test_merges_all_batches(self, mock_read, mock_put):
        mock_read.side_effect = [
            {
                "symbolsProcessed": 50,
                "errors": 1,
                "crossovers": [{"symbol": "AAPL", "weeksBelow": 5}],
                "below": [{"symbol": "X", "weeksBelow": 4}],
            },
            {
                "symbolsProcessed": 50,
                "errors": 0,
                "crossovers": [{"symbol": "MSFT", "weeksBelow": 3}],
                "below": [],
            },
        ]

        _aggregate_results("test-bucket", "2026-02-22", 2)

        assert mock_put.call_count == 3  # latest.json, latest-below.json, archive

        latest_data = mock_put.call_args_list[0][0][2]
        assert latest_data["symbolsScanned"] == 100
        assert latest_data["errors"] == 1
        assert len(latest_data["crossovers"]) == 2

    @patch("src.worker.app._put_json")
    @patch("src.worker.app._read_json")
    def test_crossovers_sorted_by_weeks_below_descending(self, mock_read, mock_put):
        mock_read.side_effect = [
            {"symbolsProcessed": 50, "errors": 0,
             "crossovers": [{"symbol": "LOW", "weeksBelow": 3}], "below": []},
            {"symbolsProcessed": 50, "errors": 0,
             "crossovers": [{"symbol": "HIGH", "weeksBelow": 8}], "below": []},
        ]

        _aggregate_results("b", "r", 2)

        crossovers = mock_put.call_args_list[0][0][2]["crossovers"]
        assert crossovers[0]["symbol"] == "HIGH"
        assert crossovers[1]["symbol"] == "LOW"

    @patch("src.worker.app._put_json")
    @patch("src.worker.app._read_json")
    def test_below_sorted_by_weeks_below_descending(self, mock_read, mock_put):
        mock_read.side_effect = [
            {"symbolsProcessed": 50, "errors": 0, "crossovers": [],
             "below": [{"symbol": "LOW", "weeksBelow": 3}]},
            {"symbolsProcessed": 50, "errors": 0, "crossovers": [],
             "below": [{"symbol": "HIGH", "weeksBelow": 10}]},
        ]

        _aggregate_results("b", "r", 2)

        below = mock_put.call_args_list[1][0][2]["below"]
        assert below[0]["symbol"] == "HIGH"
        assert below[1]["symbol"] == "LOW"

    @patch("src.worker.app._put_json")
    @patch("src.worker.app._read_json")
    def test_handles_missing_batch_file(self, mock_read, mock_put):
        mock_read.side_effect = [
            {"symbolsProcessed": 50, "errors": 0, "crossovers": [], "below": []},
            None,
        ]

        _aggregate_results("b", "r", 2)

        latest_data = mock_put.call_args_list[0][0][2]
        assert latest_data["symbolsScanned"] == 50

    @patch("src.worker.app._put_json")
    @patch("src.worker.app._read_json")
    def test_all_batches_missing(self, mock_read, mock_put):
        mock_read.return_value = None

        _aggregate_results("b", "r", 3)

        latest_data = mock_put.call_args_list[0][0][2]
        assert latest_data["symbolsScanned"] == 0
        assert latest_data["errors"] == 0
        assert latest_data["crossovers"] == []

    @patch("src.worker.app._put_json")
    @patch("src.worker.app._read_json")
    def test_writes_latest_json(self, mock_read, mock_put):
        mock_read.return_value = {"symbolsProcessed": 10, "errors": 0, "crossovers": [], "below": []}

        _aggregate_results("mybucket", "2026-02-22", 1)

        assert mock_put.call_args_list[0][0][1] == "results/latest.json"

    @patch("src.worker.app._put_json")
    @patch("src.worker.app._read_json")
    def test_writes_latest_below_json(self, mock_read, mock_put):
        mock_read.return_value = {"symbolsProcessed": 10, "errors": 0, "crossovers": [], "below": []}

        _aggregate_results("mybucket", "2026-02-22", 1)

        assert mock_put.call_args_list[1][0][1] == "results/latest-below.json"

    @patch("src.worker.app._put_json")
    @patch("src.worker.app._read_json")
    def test_writes_archive_with_date(self, mock_read, mock_put):
        mock_read.return_value = {"symbolsProcessed": 10, "errors": 0, "crossovers": [], "below": []}

        _aggregate_results("b", "2026-02-22", 1)

        archive_key = mock_put.call_args_list[2][0][1]
        assert archive_key.startswith("results/")
        assert ".json" in archive_key

    @patch("src.worker.app._put_json")
    @patch("src.worker.app._read_json")
    def test_sneak_peek_always_true(self, mock_read, mock_put):
        mock_read.return_value = {"symbolsProcessed": 10, "errors": 0, "crossovers": [], "below": []}

        _aggregate_results("b", "r", 1)

        latest_data = mock_put.call_args_list[0][0][2]
        assert latest_data["sneakPeek"] is True

    @patch("src.worker.app._put_json")
    @patch("src.worker.app._read_json")
    def test_latest_json_has_required_fields(self, mock_read, mock_put):
        mock_read.return_value = {"symbolsProcessed": 10, "errors": 1, "crossovers": [], "below": []}

        _aggregate_results("b", "r", 1)

        data = mock_put.call_args_list[0][0][2]
        assert set(data.keys()) == {"scanDate", "scanTime", "sneakPeek", "symbolsScanned", "errors", "crossovers"}

    @patch("src.worker.app._put_json")
    @patch("src.worker.app._read_json")
    def test_latest_below_json_has_required_fields(self, mock_read, mock_put):
        mock_read.return_value = {"symbolsProcessed": 10, "errors": 0, "crossovers": [], "below": []}

        _aggregate_results("b", "r", 1)

        data = mock_put.call_args_list[1][0][2]
        assert set(data.keys()) == {"scanDate", "scanTime", "sneakPeek", "symbolsScanned", "errors", "below"}

    @patch("src.worker.app._put_json")
    @patch("src.worker.app._read_json")
    def test_reads_correct_batch_keys(self, mock_read, mock_put):
        mock_read.return_value = {"symbolsProcessed": 10, "errors": 0, "crossovers": [], "below": []}

        _aggregate_results("mybucket", "2026-02-22", 3)

        read_calls = mock_read.call_args_list
        assert read_calls[0][0] == ("mybucket", "batches/2026-02-22/batch-000.json")
        assert read_calls[1][0] == ("mybucket", "batches/2026-02-22/batch-001.json")
        assert read_calls[2][0] == ("mybucket", "batches/2026-02-22/batch-002.json")

    @patch("src.worker.app._put_json")
    @patch("src.worker.app._read_json")
    def test_error_counts_accumulate(self, mock_read, mock_put):
        mock_read.side_effect = [
            {"symbolsProcessed": 50, "errors": 3, "crossovers": [], "below": []},
            {"symbolsProcessed": 50, "errors": 7, "crossovers": [], "below": []},
            {"symbolsProcessed": 50, "errors": 5, "crossovers": [], "below": []},
        ]

        _aggregate_results("b", "r", 3)

        latest_data = mock_put.call_args_list[0][0][2]
        assert latest_data["errors"] == 15
        assert latest_data["symbolsScanned"] == 150
