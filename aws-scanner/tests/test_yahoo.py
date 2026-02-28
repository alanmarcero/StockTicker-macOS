from unittest.mock import patch, MagicMock
import json

from src.worker.yahoo import fetch_daily_candles, fetch_weekly_candles, _parse_response, BASE_URL, USER_AGENT, TIMEOUT_SECONDS


class TestParseResponse:

    def test_valid_response(self):
        data = {
            "chart": {
                "result": [{
                    "timestamp": [1000, 2000, 3000],
                    "indicators": {
                        "quote": [{"close": [100.0, 101.5, 102.0]}]
                    },
                }]
            }
        }

        result = _parse_response(data)

        assert result is not None
        closes, timestamps = result
        assert closes == [100.0, 101.5, 102.0]
        assert timestamps == [1000, 2000, 3000]

    def test_filters_null_closes(self):
        data = {
            "chart": {
                "result": [{
                    "timestamp": [1000, 2000, 3000, 4000],
                    "indicators": {
                        "quote": [{"close": [100.0, None, 102.0, None]}]
                    },
                }]
            }
        }

        result = _parse_response(data)

        closes, timestamps = result
        assert closes == [100.0, 102.0]
        assert timestamps == [1000, 3000]

    def test_all_null_closes_returns_none(self):
        data = {
            "chart": {
                "result": [{
                    "timestamp": [1000, 2000],
                    "indicators": {
                        "quote": [{"close": [None, None]}]
                    },
                }]
            }
        }

        assert _parse_response(data) is None

    def test_missing_chart_key(self):
        assert _parse_response({}) is None

    def test_missing_result(self):
        assert _parse_response({"chart": {}}) is None

    def test_empty_result_list(self):
        assert _parse_response({"chart": {"result": []}}) is None

    def test_missing_timestamp(self):
        data = {
            "chart": {
                "result": [{
                    "indicators": {"quote": [{"close": [100.0]}]},
                }]
            }
        }
        assert _parse_response(data) is None

    def test_missing_indicators(self):
        data = {
            "chart": {
                "result": [{
                    "timestamp": [1000],
                }]
            }
        }
        assert _parse_response(data) is None

    def test_missing_quote(self):
        data = {
            "chart": {
                "result": [{
                    "timestamp": [1000],
                    "indicators": {},
                }]
            }
        }
        assert _parse_response(data) is None

    def test_missing_close_key(self):
        data = {
            "chart": {
                "result": [{
                    "timestamp": [1000],
                    "indicators": {"quote": [{"open": [100.0]}]},
                }]
            }
        }
        assert _parse_response(data) is None

    def test_null_result(self):
        assert _parse_response({"chart": {"result": None}}) is None

    def test_single_valid_close(self):
        data = {
            "chart": {
                "result": [{
                    "timestamp": [1000],
                    "indicators": {"quote": [{"close": [99.5]}]},
                }]
            }
        }

        closes, timestamps = _parse_response(data)
        assert closes == [99.5]
        assert timestamps == [1000]


class TestFetchDailyCandles:

    @patch("src.worker.yahoo.urllib.request.urlopen")
    def test_success(self, mock_urlopen):
        response_data = {
            "chart": {
                "result": [{
                    "timestamp": [1000, 2000],
                    "indicators": {"quote": [{"close": [150.0, 155.0]}]},
                }]
            }
        }
        mock_response = MagicMock()
        mock_response.read.return_value = json.dumps(response_data).encode()
        mock_response.__enter__ = lambda s: s
        mock_response.__exit__ = MagicMock(return_value=False)
        mock_urlopen.return_value = mock_response

        result = fetch_daily_candles("AAPL")

        assert result is not None
        closes, timestamps = result
        assert closes == [150.0, 155.0]
        assert timestamps == [1000, 2000]

    @patch("src.worker.yahoo.urllib.request.urlopen")
    def test_builds_correct_url(self, mock_urlopen):
        mock_urlopen.side_effect = OSError("stop")

        fetch_daily_candles("MSFT")

        call_args = mock_urlopen.call_args
        request = call_args[0][0]
        assert request.full_url == f"{BASE_URL}/MSFT?range=1mo&interval=1d"

    @patch("src.worker.yahoo.urllib.request.urlopen")
    def test_sets_user_agent(self, mock_urlopen):
        mock_urlopen.side_effect = OSError("stop")

        fetch_daily_candles("GOOG")

        request = mock_urlopen.call_args[0][0]
        assert request.get_header("User-agent") == USER_AGENT

    @patch("src.worker.yahoo.urllib.request.urlopen")
    def test_sets_timeout(self, mock_urlopen):
        mock_urlopen.side_effect = OSError("stop")

        fetch_daily_candles("TSLA")

        assert mock_urlopen.call_args[1]["timeout"] == TIMEOUT_SECONDS

    @patch("src.worker.yahoo.urllib.request.urlopen")
    def test_network_error_returns_none(self, mock_urlopen):
        mock_urlopen.side_effect = ConnectionError("no network")

        assert fetch_daily_candles("FAIL") is None

    @patch("src.worker.yahoo.urllib.request.urlopen")
    def test_invalid_json_returns_none(self, mock_urlopen):
        mock_response = MagicMock()
        mock_response.read.return_value = b"not json"
        mock_response.__enter__ = lambda s: s
        mock_response.__exit__ = MagicMock(return_value=False)
        mock_urlopen.return_value = mock_response

        assert fetch_daily_candles("BAD") is None


class TestFetchWeeklyCandles:

    @patch("src.worker.yahoo.urllib.request.urlopen")
    def test_success(self, mock_urlopen):
        # Use Monday timestamps so the partial-week filter keeps both candles
        response_data = {
            "chart": {
                "result": [{
                    "timestamp": [1771218000, 1771822800],
                    "indicators": {"quote": [{"close": [150.0, 155.0]}]},
                }]
            }
        }
        mock_response = MagicMock()
        mock_response.read.return_value = json.dumps(response_data).encode()
        mock_response.__enter__ = lambda s: s
        mock_response.__exit__ = MagicMock(return_value=False)
        mock_urlopen.return_value = mock_response

        result = fetch_weekly_candles("AAPL")

        assert result is not None
        closes, timestamps = result
        assert closes == [150.0, 155.0]
        assert timestamps == [1771218000, 1771822800]

    @patch("src.worker.yahoo.urllib.request.urlopen")
    def test_drops_partial_week_candle(self, mock_urlopen):
        # Last timestamp is Friday — should be dropped
        response_data = {
            "chart": {
                "result": [{
                    "timestamp": [1771218000, 1771822800, 1772226000],
                    "indicators": {"quote": [{"close": [150.0, 155.0, 156.0]}]},
                }]
            }
        }
        mock_response = MagicMock()
        mock_response.read.return_value = json.dumps(response_data).encode()
        mock_response.__enter__ = lambda s: s
        mock_response.__exit__ = MagicMock(return_value=False)
        mock_urlopen.return_value = mock_response

        result = fetch_weekly_candles("AAPL")

        assert result is not None
        closes, timestamps = result
        assert closes == [150.0, 155.0]
        assert timestamps == [1771218000, 1771822800]

    @patch("src.worker.yahoo.urllib.request.urlopen")
    def test_builds_correct_url(self, mock_urlopen):
        mock_urlopen.side_effect = OSError("stop")

        fetch_weekly_candles("MSFT")

        call_args = mock_urlopen.call_args
        request = call_args[0][0]
        assert request.full_url == f"{BASE_URL}/MSFT?range=6mo&interval=1wk"

    @patch("src.worker.yahoo.urllib.request.urlopen")
    def test_sets_user_agent(self, mock_urlopen):
        mock_urlopen.side_effect = OSError("stop")

        fetch_weekly_candles("GOOG")

        request = mock_urlopen.call_args[0][0]
        assert request.get_header("User-agent") == USER_AGENT

    @patch("src.worker.yahoo.urllib.request.urlopen")
    def test_sets_timeout(self, mock_urlopen):
        mock_urlopen.side_effect = OSError("stop")

        fetch_weekly_candles("TSLA")

        assert mock_urlopen.call_args[1]["timeout"] == TIMEOUT_SECONDS

    @patch("src.worker.yahoo.urllib.request.urlopen")
    def test_network_error_returns_none(self, mock_urlopen):
        mock_urlopen.side_effect = ConnectionError("no network")

        assert fetch_weekly_candles("FAIL") is None

    @patch("src.worker.yahoo.urllib.request.urlopen")
    def test_timeout_returns_none(self, mock_urlopen):
        from urllib.error import URLError
        mock_urlopen.side_effect = URLError("timed out")

        assert fetch_weekly_candles("SLOW") is None

    @patch("src.worker.yahoo.urllib.request.urlopen")
    def test_invalid_json_returns_none(self, mock_urlopen):
        mock_response = MagicMock()
        mock_response.read.return_value = b"not json"
        mock_response.__enter__ = lambda s: s
        mock_response.__exit__ = MagicMock(return_value=False)
        mock_urlopen.return_value = mock_response

        assert fetch_weekly_candles("BAD") is None

    @patch("src.worker.yahoo.urllib.request.urlopen")
    def test_http_error_returns_none(self, mock_urlopen):
        from urllib.error import HTTPError
        mock_urlopen.side_effect = HTTPError(
            url="http://test", code=404, msg="Not Found", hdrs={}, fp=None
        )

        assert fetch_weekly_candles("GONE") is None


class TestConstants:

    def test_base_url(self):
        assert BASE_URL == "https://query1.finance.yahoo.com/v8/finance/chart"

    def test_user_agent(self):
        assert "Mozilla" in USER_AGENT

    def test_timeout(self):
        assert TIMEOUT_SECONDS == 10
