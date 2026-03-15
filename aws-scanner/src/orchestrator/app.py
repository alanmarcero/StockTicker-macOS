import json
import os
import urllib.request
from datetime import datetime, timezone

import boto3

BATCH_SIZE = 50
VIX_URL = "https://query1.finance.yahoo.com/v8/finance/chart/^VIX?range=3y&interval=1d"
USER_AGENT = "Mozilla/5.0"
VIX_TIMEOUT = 15

s3 = boto3.client("s3")
sqs = boto3.client("sqs")


def lambda_handler(event: dict, context) -> dict:
    bucket = os.environ["BUCKET_NAME"]
    queue_url = os.environ["QUEUE_URL"]
    resp = s3.get_object(Bucket=bucket, Key="symbols/us-equities.txt")
    lines = resp["Body"].read().decode("utf-8").splitlines()
    symbols = [line.strip() for line in lines if line.strip()]

    vix_spikes = _fetch_vix_spikes()

    run_id = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    batches = [symbols[i : i + BATCH_SIZE] for i in range(0, len(symbols), BATCH_SIZE)]
    total_batches = len(batches)

    for idx, batch in enumerate(batches):
        sqs.send_message(
            QueueUrl=queue_url,
            MessageBody=json.dumps({
                "runId": run_id,
                "batchIndex": idx,
                "totalBatches": total_batches,
                "symbols": batch,
                "vixSpikes": vix_spikes,
            }),
        )

    return {
        "statusCode": 200,
        "body": {
            "runId": run_id,
            "totalSymbols": len(symbols),
            "totalBatches": total_batches,
            "vixSpikes": len(vix_spikes),
        },
    }


def _fetch_vix_spikes() -> list[dict]:
    """Fetch ^VIX 3yr daily data and detect spike clusters."""
    try:
        from src.worker.vix import detect_spikes
    except ImportError:
        try:
            from worker.vix import detect_spikes
        except ImportError:
            from vix import detect_spikes

    request = urllib.request.Request(VIX_URL, headers={"User-Agent": USER_AGENT})
    try:
        with urllib.request.urlopen(request, timeout=VIX_TIMEOUT) as response:
            data = json.loads(response.read())
    except (OSError, ValueError) as err:
        print(f"[orchestrator] VIX fetch failed: {err}")
        return []

    try:
        result = data["chart"]["result"][0]
        raw_timestamps = result["timestamp"]
        raw_closes = result["indicators"]["quote"][0]["close"]
    except (KeyError, IndexError, TypeError):
        print("[orchestrator] VIX parse failed")
        return []

    pairs = [(c, t) for c, t in zip(raw_closes, raw_timestamps) if c is not None]
    if not pairs:
        return []

    closes = [c for c, _ in pairs]
    timestamps = [t for _, t in pairs]

    return detect_spikes(closes, timestamps)
