import json
from io import BytesIO
from unittest.mock import patch, MagicMock

from src.orchestrator.app import lambda_handler, BATCH_SIZE


class TestLambdaHandler:

    def _make_s3_response(self, symbols: list[str]) -> dict:
        body = "\n".join(symbols).encode("utf-8")
        return {"Body": BytesIO(body)}

    @patch.dict("os.environ", {"BUCKET_NAME": "test-bucket", "QUEUE_URL": "https://sqs.test/queue"})
    @patch("src.orchestrator.app.sqs")
    @patch("src.orchestrator.app.s3")
    def test_reads_symbols_from_s3(self, mock_s3, mock_sqs):
        mock_s3.get_object.return_value = self._make_s3_response(["AAPL", "MSFT"])

        lambda_handler({}, None)

        mock_s3.get_object.assert_called_once_with(
            Bucket="test-bucket", Key="symbols/us-equities.txt"
        )

    @patch.dict("os.environ", {"BUCKET_NAME": "test-bucket", "QUEUE_URL": "https://sqs.test/queue"})
    @patch("src.orchestrator.app.sqs")
    @patch("src.orchestrator.app.s3")
    def test_sends_correct_batch_count(self, mock_s3, mock_sqs):
        symbols = [f"SYM{i}" for i in range(120)]
        mock_s3.get_object.return_value = self._make_s3_response(symbols)

        lambda_handler({}, None)

        # 120 symbols / 50 per batch = 3 batches
        assert mock_sqs.send_message.call_count == 3

    @patch.dict("os.environ", {"BUCKET_NAME": "test-bucket", "QUEUE_URL": "https://sqs.test/queue"})
    @patch("src.orchestrator.app.sqs")
    @patch("src.orchestrator.app.s3")
    def test_batch_message_structure(self, mock_s3, mock_sqs):
        symbols = [f"SYM{i}" for i in range(60)]
        mock_s3.get_object.return_value = self._make_s3_response(symbols)

        lambda_handler({}, None)

        first_call = mock_sqs.send_message.call_args_list[0]
        body = json.loads(first_call[1]["MessageBody"])
        assert body["batchIndex"] == 0
        assert body["totalBatches"] == 2
        assert len(body["symbols"]) == 50
        assert "runId" in body

        second_call = mock_sqs.send_message.call_args_list[1]
        body2 = json.loads(second_call[1]["MessageBody"])
        assert body2["batchIndex"] == 1
        assert body2["totalBatches"] == 2
        assert len(body2["symbols"]) == 10

    @patch.dict("os.environ", {"BUCKET_NAME": "test-bucket", "QUEUE_URL": "https://sqs.test/queue"})
    @patch("src.orchestrator.app.sqs")
    @patch("src.orchestrator.app.s3")
    def test_sends_to_correct_queue_url(self, mock_s3, mock_sqs):
        mock_s3.get_object.return_value = self._make_s3_response(["AAPL"])

        lambda_handler({}, None)

        assert mock_sqs.send_message.call_args[1]["QueueUrl"] == "https://sqs.test/queue"

    @patch.dict("os.environ", {"BUCKET_NAME": "test-bucket", "QUEUE_URL": "https://sqs.test/queue"})
    @patch("src.orchestrator.app.sqs")
    @patch("src.orchestrator.app.s3")
    def test_returns_summary(self, mock_s3, mock_sqs):
        mock_s3.get_object.return_value = self._make_s3_response(["AAPL", "MSFT", "GOOG"])

        result = lambda_handler({}, None)

        assert result["statusCode"] == 200
        assert result["body"]["totalSymbols"] == 3
        assert result["body"]["totalBatches"] == 1
        assert "runId" in result["body"]

    @patch.dict("os.environ", {"BUCKET_NAME": "test-bucket", "QUEUE_URL": "https://sqs.test/queue"})
    @patch("src.orchestrator.app.sqs")
    @patch("src.orchestrator.app.s3")
    def test_strips_whitespace_and_skips_empty_lines(self, mock_s3, mock_sqs):
        body = b"  AAPL  \n\n  MSFT \n\n\n  GOOG  \n"
        mock_s3.get_object.return_value = {"Body": BytesIO(body)}

        result = lambda_handler({}, None)

        assert result["body"]["totalSymbols"] == 3

        body_sent = json.loads(mock_sqs.send_message.call_args[1]["MessageBody"])
        assert body_sent["symbols"] == ["AAPL", "MSFT", "GOOG"]

    @patch.dict("os.environ", {"BUCKET_NAME": "test-bucket", "QUEUE_URL": "https://sqs.test/queue"})
    @patch("src.orchestrator.app.sqs")
    @patch("src.orchestrator.app.s3")
    def test_run_id_is_date_format(self, mock_s3, mock_sqs):
        mock_s3.get_object.return_value = self._make_s3_response(["AAPL"])

        result = lambda_handler({}, None)

        import re
        assert re.match(r"\d{4}-\d{2}-\d{2}", result["body"]["runId"])

    @patch.dict("os.environ", {"BUCKET_NAME": "test-bucket", "QUEUE_URL": "https://sqs.test/queue"})
    @patch("src.orchestrator.app.sqs")
    @patch("src.orchestrator.app.s3")
    def test_exactly_batch_size_symbols(self, mock_s3, mock_sqs):
        symbols = [f"SYM{i}" for i in range(50)]
        mock_s3.get_object.return_value = self._make_s3_response(symbols)

        result = lambda_handler({}, None)

        assert result["body"]["totalBatches"] == 1
        assert mock_sqs.send_message.call_count == 1

    @patch.dict("os.environ", {"BUCKET_NAME": "test-bucket", "QUEUE_URL": "https://sqs.test/queue"})
    @patch("src.orchestrator.app.sqs")
    @patch("src.orchestrator.app.s3")
    def test_single_symbol(self, mock_s3, mock_sqs):
        mock_s3.get_object.return_value = self._make_s3_response(["AAPL"])

        result = lambda_handler({}, None)

        assert result["body"]["totalBatches"] == 1
        body_sent = json.loads(mock_sqs.send_message.call_args[1]["MessageBody"])
        assert body_sent["symbols"] == ["AAPL"]
        assert body_sent["totalBatches"] == 1


class TestBatchSize:

    def test_batch_size_is_50(self):
        assert BATCH_SIZE == 50
