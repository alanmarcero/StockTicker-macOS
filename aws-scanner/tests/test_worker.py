import json
from unittest.mock import MagicMock, patch

from src.worker.app import _process_batch, _aggregate_results


class TestProcessBatch:

    @patch("src.worker.app.yahoo")
    @patch("src.worker.app.time")
    def test_crossover_detected(self, mock_time, mock_yahoo):
        # Build closes that produce a crossover: 3 weeks below then cross above
        # First 5: [100, 102, 104, 106, 108] -> SMA = 104.0
        # idx5: close=100, EMA=102.667 -> below
        # idx6: close=101, EMA=102.111 -> below
        # idx7: close=101, EMA=101.741 -> below
        # idx8: close=106, EMA=103.160 -> above (crossover, 3 weeks below)
        closes = [100.0, 102.0, 104.0, 106.0, 108.0, 100.0, 101.0, 101.0, 106.0]
        timestamps = list(range(len(closes)))
        mock_yahoo.fetch_weekly_candles.return_value = (closes, timestamps)

        crossovers, below, errors = _process_batch(["TEST"])

        assert len(crossovers) == 1
        assert crossovers[0]["symbol"] == "TEST"
        assert crossovers[0]["close"] == 106.0
        assert crossovers[0]["weeksBelow"] == 3
        assert crossovers[0]["pctAbove"] > 0
        assert len(errors) == 0

    @patch("src.worker.app.yahoo")
    @patch("src.worker.app.time")
    def test_below_detected_with_minimum_weeks(self, mock_time, mock_yahoo):
        # 3 weeks below EMA (the minimum threshold)
        closes = [100.0, 102.0, 104.0, 106.0, 108.0, 100.0, 101.0, 101.0]
        timestamps = list(range(len(closes)))
        mock_yahoo.fetch_weekly_candles.return_value = (closes, timestamps)

        crossovers, below, errors = _process_batch(["TEST"])

        assert len(below) == 1
        assert below[0]["symbol"] == "TEST"
        assert below[0]["weeksBelow"] == 3
        assert below[0]["pctBelow"] > 0

    @patch("src.worker.app.yahoo")
    @patch("src.worker.app.time")
    def test_below_not_detected_under_threshold(self, mock_time, mock_yahoo):
        # Only 1 week below — under the 3-week threshold
        closes = [50.0, 52.0, 54.0, 56.0, 58.0, 56.0, 53.0]
        timestamps = list(range(len(closes)))
        mock_yahoo.fetch_weekly_candles.return_value = (closes, timestamps)

        crossovers, below, errors = _process_batch(["TEST"])

        assert len(below) == 0

    @patch("src.worker.app.yahoo")
    @patch("src.worker.app.time")
    def test_fetch_failure_records_error(self, mock_time, mock_yahoo):
        mock_yahoo.fetch_weekly_candles.return_value = None

        crossovers, below, errors = _process_batch(["FAIL"])

        assert len(crossovers) == 0
        assert len(below) == 0
        assert len(errors) == 1
        assert errors[0]["symbol"] == "FAIL"

    @patch("src.worker.app.yahoo")
    @patch("src.worker.app.time")
    def test_insufficient_data_skipped_no_error(self, mock_time, mock_yahoo):
        # Only 3 closes — not enough for EMA period 5
        mock_yahoo.fetch_weekly_candles.return_value = ([100.0, 101.0, 102.0], [1, 2, 3])

        crossovers, below, errors = _process_batch(["SHORT"])

        assert len(crossovers) == 0
        assert len(below) == 0
        assert len(errors) == 0

    @patch("src.worker.app.yahoo")
    @patch("src.worker.app.time")
    def test_multiple_symbols_rate_limited(self, mock_time, mock_yahoo):
        closes = [50.0] * 10
        mock_yahoo.fetch_weekly_candles.return_value = (closes, list(range(10)))

        _process_batch(["A", "B", "C"])

        # sleep(1) called between symbols (not before the first one)
        assert mock_time.sleep.call_count == 2

    @patch("src.worker.app.yahoo")
    @patch("src.worker.app.time")
    def test_mixed_success_and_failure(self, mock_time, mock_yahoo):
        def side_effect(symbol):
            if symbol == "FAIL":
                return None
            # Crossover data
            return ([100.0, 102.0, 104.0, 106.0, 108.0, 100.0, 101.0, 101.0, 106.0], list(range(9)))

        mock_yahoo.fetch_weekly_candles.side_effect = side_effect

        crossovers, below, errors = _process_batch(["OK", "FAIL", "OK2"])

        assert len(crossovers) == 2
        assert len(errors) == 1
        assert errors[0]["symbol"] == "FAIL"


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

        latest_call = mock_put.call_args_list[0]
        assert latest_call[0][1] == "results/latest.json"
        data = latest_call[0][2]
        assert data["symbolsScanned"] == 100
        assert data["errors"] == 1
        assert len(data["crossovers"]) == 2
        # Sorted by weeksBelow descending
        assert data["crossovers"][0]["symbol"] == "AAPL"
        assert data["crossovers"][1]["symbol"] == "MSFT"

        below_call = mock_put.call_args_list[1]
        assert below_call[0][1] == "results/latest-below.json"
        below_data = below_call[0][2]
        assert len(below_data["below"]) == 1

    @patch("src.worker.app._put_json")
    @patch("src.worker.app._read_json")
    def test_handles_missing_batch_file(self, mock_read, mock_put):
        mock_read.side_effect = [
            {"symbolsProcessed": 50, "errors": 0, "crossovers": [], "below": []},
            None,  # Missing batch file
        ]

        _aggregate_results("test-bucket", "2026-02-22", 2)

        latest_data = mock_put.call_args_list[0][0][2]
        assert latest_data["symbolsScanned"] == 50

    @patch("src.worker.app._put_json")
    @patch("src.worker.app._read_json")
    def test_writes_archive_with_date(self, mock_read, mock_put):
        mock_read.return_value = {
            "symbolsProcessed": 50, "errors": 0, "crossovers": [], "below": []
        }

        _aggregate_results("test-bucket", "2026-02-22", 1)

        archive_call = mock_put.call_args_list[2]
        assert archive_call[0][1].startswith("results/")
        assert ".json" in archive_call[0][1]

    @patch("src.worker.app._put_json")
    @patch("src.worker.app._read_json")
    def test_sneak_peek_always_true(self, mock_read, mock_put):
        mock_read.return_value = {
            "symbolsProcessed": 10, "errors": 0, "crossovers": [], "below": []
        }

        _aggregate_results("test-bucket", "2026-02-22", 1)

        latest_data = mock_put.call_args_list[0][0][2]
        assert latest_data["sneakPeek"] is True
