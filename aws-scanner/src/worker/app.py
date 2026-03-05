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
cloudfront = boto3.client("cloudfront")


def lambda_handler(event: dict, context) -> dict:
    bucket = os.environ["BUCKET_NAME"]

    for record in event.get("Records", []):
        message = json.loads(record["body"])
        run_id: str = message["runId"]
        batch_index: int = message["batchIndex"]
        total_batches: int = message["totalBatches"]
        symbols: list[str] = message["symbols"]

        crossovers, crossdowns, day_below, week_below, day_above, week_above, errors = _process_batch(symbols)

        _write_batch_results(bucket, run_id, batch_index, len(symbols), len(errors), crossovers, crossdowns, day_below, week_below, day_above, week_above)

        if errors:
            _write_errors(bucket, run_id, batch_index, errors)

        if batch_index == total_batches - 1:
            _aggregate_results(bucket, run_id, total_batches)
            _invalidate_cache()

    return {"statusCode": 200}


def _process_batch(
    symbols: list[str],
) -> tuple[list[dict], list[dict], list[dict], list[dict], list[dict], list[dict], list[dict]]:
    crossovers: list[dict] = []
    crossdowns: list[dict] = []
    day_below: list[dict] = []
    week_below: list[dict] = []
    day_above: list[dict] = []
    week_above: list[dict] = []
    errors: list[dict] = []

    for i, symbol in enumerate(symbols):
        if i > 0:
            time.sleep(1)

        daily_result = yahoo.fetch_daily_candles(symbol)
        weekly_result = yahoo.fetch_weekly_candles(symbol)

        if daily_result is None and weekly_result is None:
            print(f"[worker] {symbol}: fetch failed")
            errors.append({"symbol": symbol, "error": "Failed to fetch candles"})
            continue

        if daily_result is not None:
            daily_closes = daily_result[0]
            daily_ema_value = ema.calculate(daily_closes)
            if daily_ema_value is not None:
                last_close = daily_closes[-1]

                daily_above_count = ema.count_periods_above(daily_closes)
                if daily_above_count is not None:
                    pct = round((last_close - daily_ema_value) / daily_ema_value * 100, 2)
                    day_above.append({
                        "symbol": symbol,
                        "close": last_close,
                        "ema": round(daily_ema_value, 4),
                        "pctAbove": pct,
                        "count": daily_above_count,
                    })

                daily_below_count = ema.count_periods_below(daily_closes)
                if daily_below_count is not None:
                    pct = round((daily_ema_value - last_close) / daily_ema_value * 100, 2)
                    day_below.append({
                        "symbol": symbol,
                        "close": last_close,
                        "ema": round(daily_ema_value, 4),
                        "pctBelow": pct,
                        "count": daily_below_count,
                    })

        if weekly_result is not None:
            closes = weekly_result[0]
            ema_value = ema.calculate(closes)
            if ema_value is not None:
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

                crossdown_weeks = ema.detect_weekly_crossdown(closes)
                if crossdown_weeks is not None:
                    pct_below = round((ema_value - last_close) / ema_value * 100, 2)
                    crossdowns.append({
                        "symbol": symbol,
                        "close": last_close,
                        "ema": round(ema_value, 4),
                        "pctBelow": pct_below,
                        "weeksAbove": crossdown_weeks,
                    })

                weekly_below_count = ema.count_periods_below(closes)
                if weekly_below_count is not None and weekly_below_count >= 3:
                    pct_below = round((ema_value - last_close) / ema_value * 100, 2)
                    week_below.append({
                        "symbol": symbol,
                        "close": last_close,
                        "ema": round(ema_value, 4),
                        "pctBelow": pct_below,
                        "count": weekly_below_count,
                    })

                weekly_above_count = ema.count_periods_above(closes)
                if weekly_above_count is not None:
                    pct = round((last_close - ema_value) / ema_value * 100, 2)
                    week_above.append({
                        "symbol": symbol,
                        "close": last_close,
                        "ema": round(ema_value, 4),
                        "pctAbove": pct,
                        "count": weekly_above_count,
                    })

    return crossovers, crossdowns, day_below, week_below, day_above, week_above, errors


def _write_batch_results(
    bucket: str,
    run_id: str,
    batch_index: int,
    symbols_processed: int,
    error_count: int,
    crossovers: list[dict],
    crossdowns: list[dict],
    day_below: list[dict],
    week_below: list[dict],
    day_above: list[dict],
    week_above: list[dict],
) -> None:
    body = {
        "batchIndex": batch_index,
        "symbolsProcessed": symbols_processed,
        "errors": error_count,
        "crossovers": crossovers,
        "crossdowns": crossdowns,
        "dayBelow": day_below,
        "weekBelow": week_below,
        "dayAbove": day_above,
        "weekAbove": week_above,
    }
    key = f"batches/{run_id}/batch-{batch_index:03d}.json"
    s3.put_object(Bucket=bucket, Key=key, Body=json.dumps(body))


def _write_errors(bucket: str, run_id: str, batch_index: int, errors: list[dict]) -> None:
    key = f"logs/{run_id}/errors-{batch_index:03d}.json"
    s3.put_object(Bucket=bucket, Key=key, Body=json.dumps(errors))


def _aggregate_results(bucket: str, run_id: str, total_batches: int) -> None:
    all_crossovers: list[dict] = []
    all_crossdowns: list[dict] = []
    all_day_below: list[dict] = []
    all_week_below: list[dict] = []
    all_day_above: list[dict] = []
    all_week_above: list[dict] = []
    total_symbols = 0
    total_errors = 0

    for i in range(total_batches):
        key = f"batches/{run_id}/batch-{i:03d}.json"
        batch = _read_json(bucket, key)
        if batch is None:
            continue

        all_crossovers.extend(batch.get("crossovers", []))
        all_crossdowns.extend(batch.get("crossdowns", []))
        all_day_below.extend(batch.get("dayBelow", []))
        all_week_below.extend(batch.get("weekBelow", []))
        all_day_above.extend(batch.get("dayAbove", []))
        all_week_above.extend(batch.get("weekAbove", []))
        total_symbols += batch.get("symbolsProcessed", 0)
        total_errors += batch.get("errors", 0)

    all_crossovers.sort(key=lambda x: x.get("weeksBelow", 0), reverse=True)
    all_crossdowns.sort(key=lambda x: x.get("weeksAbove", 0), reverse=True)
    all_day_below.sort(key=lambda x: x.get("count", 0), reverse=True)
    all_week_below.sort(key=lambda x: x.get("count", 0), reverse=True)
    all_day_above.sort(key=lambda x: x.get("count", 0), reverse=True)
    all_week_above.sort(key=lambda x: x.get("count", 0), reverse=True)

    now = datetime.now(timezone.utc)
    scan_date = now.strftime("%Y-%m-%d")
    scan_time = now.strftime("%Y-%m-%dT%H:%M:%SZ")

    base = {
        "scanDate": scan_date,
        "scanTime": scan_time,
        "symbolsScanned": total_symbols,
        "errors": total_errors,
    }

    crossover_result = {**base, "crossovers": all_crossovers}
    crossdown_result = {**base, "crossdowns": all_crossdowns}
    below_result = {**base, "dayBelow": all_day_below, "weekBelow": all_week_below}
    above_result = {**base, "dayAbove": all_day_above, "weekAbove": all_week_above}

    _put_json(bucket, "results/latest.json", crossover_result)
    _put_json(bucket, "results/latest-crossdown.json", crossdown_result)
    _put_json(bucket, "results/latest-below.json", below_result)
    _put_json(bucket, "results/latest-above.json", above_result)
    _put_json(bucket, f"results/{scan_date}.json", crossover_result)


def _read_json(bucket: str, key: str) -> Any:
    try:
        resp = s3.get_object(Bucket=bucket, Key=key)
        return json.loads(resp["Body"].read())
    except Exception as err:
        print(f"[worker] failed to read s3://{bucket}/{key}: {err}")
        return None


def _invalidate_cache() -> None:
    dist_id = os.environ.get("DISTRIBUTION_ID")
    if not dist_id:
        print("[worker] DISTRIBUTION_ID not set, skipping cache invalidation")
        return
    cloudfront.create_invalidation(
        DistributionId=dist_id,
        InvalidationBatch={
            "Paths": {"Quantity": 1, "Items": ["/results/*"]},
            "CallerReference": datetime.now(timezone.utc).isoformat(),
        },
    )
    print(f"[worker] CloudFront invalidation created for {dist_id}")


def _put_json(bucket: str, key: str, data: Any) -> None:
    s3.put_object(Bucket=bucket, Key=key, Body=json.dumps(data))
