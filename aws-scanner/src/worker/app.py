import json
import os
import time
from datetime import datetime, timezone
from typing import Any

import boto3

try:
    from . import ema, yahoo
except ImportError:
    import ema, yahoo

s3 = boto3.client("s3")


def lambda_handler(event: dict, context) -> dict:
    bucket = os.environ["BUCKET_NAME"]

    for record in event.get("Records", []):
        message = json.loads(record["body"])
        run_id: str = message["runId"]
        batch_index: int = message["batchIndex"]
        total_batches: int = message["totalBatches"]
        symbols: list[str] = message["symbols"]

        crossovers, below, errors = _process_batch(symbols)

        _write_batch_results(bucket, run_id, batch_index, len(symbols), len(errors), crossovers, below)

        if errors:
            _write_errors(bucket, run_id, batch_index, errors)

        if batch_index == total_batches - 1:
            _aggregate_results(bucket, run_id, total_batches)

    return {"statusCode": 200}


def _process_batch(
    symbols: list[str],
) -> tuple[list[dict], list[dict], list[dict]]:
    crossovers: list[dict] = []
    below: list[dict] = []
    errors: list[dict] = []

    for i, symbol in enumerate(symbols):
        if i > 0:
            time.sleep(1)

        result = yahoo.fetch_weekly_candles(symbol)
        if result is None:
            errors.append({"symbol": symbol, "error": "Failed to fetch weekly candles"})
            continue

        closes, _timestamps = result

        ema_value = ema.calculate(closes)
        if ema_value is None:
            continue

        last_close = closes[-1]

        crossover_weeks = ema.detect_weekly_crossover(closes)
        if crossover_weeks is not None:
            pct_above = round((last_close - ema_value) / ema_value * 100, 2)
            crossovers.append({
                "symbol": symbol,
                "close": last_close,
                "ema": round(ema_value, 4),
                "pctAbove": pct_above,
                "weeksBelow": crossover_weeks,
            })

        below_count = ema.count_weeks_below(closes)
        if below_count is not None and below_count >= 3:
            pct_below = round((ema_value - last_close) / ema_value * 100, 2)
            below.append({
                "symbol": symbol,
                "close": last_close,
                "ema": round(ema_value, 4),
                "pctBelow": pct_below,
                "weeksBelow": below_count,
            })

    return crossovers, below, errors


def _write_batch_results(
    bucket: str,
    run_id: str,
    batch_index: int,
    symbols_processed: int,
    error_count: int,
    crossovers: list[dict],
    below: list[dict],
) -> None:
    body = {
        "batchIndex": batch_index,
        "symbolsProcessed": symbols_processed,
        "errors": error_count,
        "crossovers": crossovers,
        "below": below,
    }
    key = f"batches/{run_id}/batch-{batch_index:03d}.json"
    s3.put_object(Bucket=bucket, Key=key, Body=json.dumps(body))


def _write_errors(bucket: str, run_id: str, batch_index: int, errors: list[dict]) -> None:
    key = f"logs/{run_id}/errors-{batch_index:03d}.json"
    s3.put_object(Bucket=bucket, Key=key, Body=json.dumps(errors))


def _aggregate_results(bucket: str, run_id: str, total_batches: int) -> None:
    all_crossovers: list[dict] = []
    all_below: list[dict] = []
    total_symbols = 0
    total_errors = 0

    for i in range(total_batches):
        key = f"batches/{run_id}/batch-{i:03d}.json"
        batch = _read_json(bucket, key)
        if batch is None:
            continue

        all_crossovers.extend(batch.get("crossovers", []))
        all_below.extend(batch.get("below", []))
        total_symbols += batch.get("symbolsProcessed", 0)
        total_errors += batch.get("errors", 0)

    all_crossovers.sort(key=lambda x: x.get("weeksBelow", 0), reverse=True)
    all_below.sort(key=lambda x: x.get("weeksBelow", 0), reverse=True)

    now = datetime.now(timezone.utc)
    scan_date = now.strftime("%Y-%m-%d")
    scan_time = now.strftime("%Y-%m-%dT%H:%M:%SZ")

    crossover_result = {
        "scanDate": scan_date,
        "scanTime": scan_time,
        "sneakPeek": True,
        "symbolsScanned": total_symbols,
        "errors": total_errors,
        "crossovers": all_crossovers,
    }

    below_result = {
        "scanDate": scan_date,
        "scanTime": scan_time,
        "sneakPeek": True,
        "symbolsScanned": total_symbols,
        "errors": total_errors,
        "below": all_below,
    }

    _put_json(bucket, "results/latest.json", crossover_result)
    _put_json(bucket, "results/latest-below.json", below_result)
    _put_json(bucket, f"results/{scan_date}.json", crossover_result)


def _read_json(bucket: str, key: str) -> Any:
    try:
        resp = s3.get_object(Bucket=bucket, Key=key)
        return json.loads(resp["Body"].read())
    except Exception:
        return None


def _put_json(bucket: str, key: str, data: Any) -> None:
    s3.put_object(Bucket=bucket, Key=key, Body=json.dumps(data))
