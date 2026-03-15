import json
import os
import time
from datetime import datetime, timezone
from typing import Any, Optional

import boto3

try:
    from . import ema, stats, yahoo
except ImportError:
    import ema, stats, yahoo

s3 = boto3.client("s3")
cloudfront = boto3.client("cloudfront")

RATE_LIMIT_DELAY = 1
MIN_WEEKS_THRESHOLD = 3
MAX_WEEKLY_SNAPSHOTS = 6


def lambda_handler(event: dict, context) -> dict:
    bucket = os.environ["BUCKET_NAME"]

    for record in event.get("Records", []):
        message = json.loads(record["body"])
        run_id: str = message["runId"]
        batch_index: int = message["batchIndex"]
        total_batches: int = message["totalBatches"]
        symbols: list[str] = message["symbols"]
        vix_spikes: list[dict] = message.get("vixSpikes", [])

        crossovers, crossdowns, day_below, week_below, day_above, week_above, month_crossovers, month_crossdowns, month_below, month_above, stats_data, errors = _process_batch(symbols, vix_spikes)

        _write_batch_results(bucket, run_id, batch_index, len(symbols), len(errors), crossovers, crossdowns, day_below, week_below, day_above, week_above, month_crossovers, month_crossdowns, month_below, month_above, stats_data, errors)

        if errors:
            _write_errors(bucket, run_id, batch_index, errors)

        if batch_index == total_batches - 1:
            _aggregate_results(bucket, run_id, total_batches)
            _invalidate_cache()

    return {"statusCode": 200}


def _strip_incomplete_week(closes: list[float], timestamps: list[int]) -> tuple[list[float], list[int]]:
    """Drop the last candle if it belongs to the current (incomplete) week."""
    if not timestamps:
        return closes, timestamps
    now = datetime.now(timezone.utc)
    last_dt = datetime.fromtimestamp(timestamps[-1], tz=timezone.utc)
    if last_dt.isocalendar()[1] == now.isocalendar()[1] and last_dt.year == now.year:
        return closes[:-1], timestamps[:-1]
    return closes, timestamps


def _aggregate_to_monthly(closes: list[float], timestamps: list[int]) -> list[float]:
    """Take the last close per calendar month from weekly data."""
    if not closes:
        return []
    monthly: dict[tuple[int, int], float] = {}
    for close, ts in zip(closes, timestamps):
        dt = datetime.fromtimestamp(ts, tz=timezone.utc)
        key = (dt.year, dt.month)
        monthly[key] = close
    return list(monthly.values())


def _pct_diff(close: float, ema_value: float) -> float:
    return round((close - ema_value) / ema_value * 100, 2)


def _above_entry(symbol: str, close: float, ema_value: float, count: int) -> dict:
    return {
        "symbol": symbol,
        "close": close,
        "ema": round(ema_value, 4),
        "pctAbove": _pct_diff(close, ema_value),
        "count": count,
    }


def _below_entry(symbol: str, close: float, ema_value: float, count: int) -> dict:
    return {
        "symbol": symbol,
        "close": close,
        "ema": round(ema_value, 4),
        "pctBelow": _pct_diff(ema_value, close),
        "count": count,
    }


def _crossover_entry(symbol: str, close: float, ema_value: float, periods_below: int, period_key: str) -> dict:
    return {
        "symbol": symbol,
        "close": close,
        "ema": round(ema_value, 4),
        "pctAbove": _pct_diff(close, ema_value),
        period_key: periods_below,
    }


def _crossdown_entry(symbol: str, close: float, ema_value: float, periods_above: int, period_key: str) -> dict:
    return {
        "symbol": symbol,
        "close": close,
        "ema": round(ema_value, 4),
        "pctBelow": _pct_diff(ema_value, close),
        period_key: periods_above,
    }


def _process_batch(
    symbols: list[str],
    vix_spikes: Optional[list[dict]] = None,
) -> tuple[list[dict], list[dict], list[dict], list[dict], list[dict], list[dict], list[dict], list[dict], list[dict], list[dict], list[dict], list[dict]]:
    crossovers: list[dict] = []
    crossdowns: list[dict] = []
    day_below: list[dict] = []
    week_below: list[dict] = []
    day_above: list[dict] = []
    week_above: list[dict] = []
    month_crossovers: list[dict] = []
    month_crossdowns: list[dict] = []
    month_below: list[dict] = []
    month_above: list[dict] = []
    stats_data: list[dict] = []
    errors: list[dict] = []

    for i, symbol in enumerate(symbols):
        if i > 0:
            time.sleep(RATE_LIMIT_DELAY)

        daily_result = yahoo.fetch_daily_candles(symbol)
        weekly_result = yahoo.fetch_weekly_candles(symbol)
        monthly_result = yahoo.fetch_monthly_candles(symbol)
        stats_result = yahoo.fetch_stats_candles(symbol)

        if daily_result is None and weekly_result is None and monthly_result is None:
            print(f"[worker] {symbol}: fetch failed")
            errors.append({"symbol": symbol, "error": "Failed to fetch candles"})
            continue

        _process_daily(symbol, daily_result, day_above, day_below)
        _process_weekly(symbol, weekly_result, crossovers, crossdowns, week_below, week_above)
        _process_monthly(symbol, monthly_result, month_crossovers, month_crossdowns, month_below, month_above)

        if stats_result is not None:
            forward_pe, pe_history = yahoo.fetch_forward_pe(symbol)
            computed = stats.compute_stats(
                stats_result[0], stats_result[1],
                vix_spikes=vix_spikes,
                forward_pe=forward_pe,
                forward_pe_history=pe_history,
            )
            if computed is not None:
                computed["symbol"] = symbol
                stats_data.append(computed)

    return crossovers, crossdowns, day_below, week_below, day_above, week_above, month_crossovers, month_crossdowns, month_below, month_above, stats_data, errors


def _process_daily(
    symbol: str,
    daily_result: Optional[tuple[list[float], list[int]]],
    day_above: list[dict],
    day_below: list[dict],
) -> None:
    if daily_result is None:
        return
    daily_closes = daily_result[0]
    daily_ema_value = ema.calculate(daily_closes)
    if daily_ema_value is None:
        return
    last_close = daily_closes[-1]

    above_count = ema.count_periods_above(daily_closes)
    if above_count is not None:
        day_above.append(_above_entry(symbol, last_close, daily_ema_value, above_count))

    below_count = ema.count_periods_below(daily_closes)
    if below_count is not None:
        day_below.append(_below_entry(symbol, last_close, daily_ema_value, below_count))


def _process_weekly(
    symbol: str,
    weekly_result: Optional[tuple[list[float], list[int]]],
    crossovers: list[dict],
    crossdowns: list[dict],
    week_below: list[dict],
    week_above: list[dict],
) -> None:
    if weekly_result is None:
        return
    closes, _ = _strip_incomplete_week(weekly_result[0], weekly_result[1])
    ema_value = ema.calculate(closes)
    if ema_value is None:
        return
    last_close = closes[-1]

    crossover_weeks = ema.detect_weekly_crossover(closes)
    if crossover_weeks is not None:
        crossovers.append(_crossover_entry(symbol, last_close, ema_value, crossover_weeks, "weeksBelow"))

    crossdown_weeks = ema.detect_weekly_crossdown(closes)
    if crossdown_weeks is not None:
        crossdowns.append(_crossdown_entry(symbol, last_close, ema_value, crossdown_weeks, "weeksAbove"))

    weekly_below_count = ema.count_periods_below(closes)
    if weekly_below_count is not None and weekly_below_count >= MIN_WEEKS_THRESHOLD:
        week_below.append(_below_entry(symbol, last_close, ema_value, weekly_below_count))

    weekly_above_count = ema.count_periods_above(closes)
    if weekly_above_count is not None:
        week_above.append(_above_entry(symbol, last_close, ema_value, weekly_above_count))


def _process_monthly(
    symbol: str,
    monthly_result: Optional[tuple[list[float], list[int]]],
    month_crossovers: list[dict],
    month_crossdowns: list[dict],
    month_below: list[dict],
    month_above: list[dict],
) -> None:
    if monthly_result is None:
        return
    m_closes, m_timestamps = _strip_incomplete_week(monthly_result[0], monthly_result[1])
    monthly_closes = _aggregate_to_monthly(m_closes, m_timestamps)
    monthly_ema = ema.calculate(monthly_closes)
    if monthly_ema is None:
        return
    m_last = monthly_closes[-1]

    m_crossover = ema.detect_weekly_crossover(monthly_closes)
    if m_crossover is not None:
        month_crossovers.append(_crossover_entry(symbol, m_last, monthly_ema, m_crossover, "monthsBelow"))

    m_crossdown = ema.detect_weekly_crossdown(monthly_closes)
    if m_crossdown is not None:
        month_crossdowns.append(_crossdown_entry(symbol, m_last, monthly_ema, m_crossdown, "monthsAbove"))

    m_below_count = ema.count_periods_below(monthly_closes)
    if m_below_count is not None:
        month_below.append(_below_entry(symbol, m_last, monthly_ema, m_below_count))

    m_above_count = ema.count_periods_above(monthly_closes)
    if m_above_count is not None:
        month_above.append(_above_entry(symbol, m_last, monthly_ema, m_above_count))


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
    month_crossovers: list[dict],
    month_crossdowns: list[dict],
    month_below: list[dict],
    month_above: list[dict],
    stats_data: Optional[list[dict]] = None,
    error_details: Optional[list[dict]] = None,
) -> None:
    body = {
        "batchIndex": batch_index,
        "symbolsProcessed": symbols_processed,
        "errors": error_count,
        "errorDetails": error_details or [],
        "crossovers": crossovers,
        "crossdowns": crossdowns,
        "dayBelow": day_below,
        "weekBelow": week_below,
        "dayAbove": day_above,
        "weekAbove": week_above,
        "monthCrossovers": month_crossovers,
        "monthCrossdowns": month_crossdowns,
        "monthBelow": month_below,
        "monthAbove": month_above,
        "stats": stats_data or [],
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
    all_month_crossovers: list[dict] = []
    all_month_crossdowns: list[dict] = []
    all_month_below: list[dict] = []
    all_month_above: list[dict] = []
    all_stats: list[dict] = []
    all_error_details: list[dict] = []
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
        all_month_crossovers.extend(batch.get("monthCrossovers", []))
        all_month_crossdowns.extend(batch.get("monthCrossdowns", []))
        all_month_below.extend(batch.get("monthBelow", []))
        all_month_above.extend(batch.get("monthAbove", []))
        all_stats.extend(batch.get("stats", []))
        all_error_details.extend(batch.get("errorDetails", []))
        total_symbols += batch.get("symbolsProcessed", 0)
        total_errors += batch.get("errors", 0)

    all_crossovers.sort(key=lambda x: x.get("weeksBelow", 0), reverse=True)
    all_crossdowns.sort(key=lambda x: x.get("weeksAbove", 0), reverse=True)
    all_day_below.sort(key=lambda x: x.get("count", 0), reverse=True)
    all_week_below.sort(key=lambda x: x.get("count", 0), reverse=True)
    all_day_above.sort(key=lambda x: x.get("count", 0), reverse=True)
    all_week_above.sort(key=lambda x: x.get("count", 0), reverse=True)
    all_month_crossovers.sort(key=lambda x: x.get("monthsBelow", 0), reverse=True)
    all_month_crossdowns.sort(key=lambda x: x.get("monthsAbove", 0), reverse=True)
    all_month_below.sort(key=lambda x: x.get("count", 0), reverse=True)
    all_month_above.sort(key=lambda x: x.get("count", 0), reverse=True)

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
    monthly_result = {**base, "monthCrossovers": all_month_crossovers, "monthCrossdowns": all_month_crossdowns}
    monthly_ba_result = {**base, "monthBelow": all_month_below, "monthAbove": all_month_above}

    _put_json(bucket, "results/latest.json", crossover_result)
    _put_json(bucket, "results/latest-crossdown.json", crossdown_result)
    _put_json(bucket, "results/latest-below.json", below_result)
    _put_json(bucket, "results/latest-above.json", above_result)
    _put_json(bucket, "results/latest-monthly.json", monthly_result)
    _put_json(bucket, "results/latest-monthly-below-above.json", monthly_ba_result)
    all_error_details.sort(key=lambda x: x.get("symbol", ""))
    _put_json(bucket, "results/latest-errors.json", {**base, "errorDetails": all_error_details})
    _put_json(bucket, f"results/{scan_date}.json", crossover_result)
    _put_json(bucket, f"results/{scan_date}-crossdown.json", crossdown_result)
    _put_json(bucket, f"results/{scan_date}-below.json", below_result)
    _put_json(bucket, f"results/{scan_date}-above.json", above_result)
    _put_json(bucket, f"results/{scan_date}-monthly.json", monthly_result)
    _put_json(bucket, f"results/{scan_date}-monthly-below-above.json", monthly_ba_result)

    all_stats.sort(key=lambda x: x.get("symbol", ""))
    misc = _compute_misc_stats(all_stats, len(all_week_above), total_symbols)
    stats_result = {**base, "stats": all_stats, "misc": misc}
    _put_json(bucket, "results/latest-stats.json", stats_result)
    _put_json(bucket, f"results/{scan_date}-stats.json", stats_result)

    _update_manifest(bucket, scan_date)


def _compute_misc_stats(
    all_stats: list[dict],
    week_above_count: int = 0,
    total_symbols: int = 0,
) -> dict:
    """Compute aggregate misc stats from all symbol stats."""
    if not all_stats:
        return {}

    total = len(all_stats)

    high_pcts = [s["highPct"] for s in all_stats if "highPct" in s]
    ytd_pcts = [s["ytdPct"] for s in all_stats if "ytdPct" in s]
    forward_pes = [s["forwardPE"] for s in all_stats if "forwardPE" in s]

    misc: dict = {}

    if high_pcts:
        within_5 = sum(1 for h in high_pcts if h >= -5)
        misc["pctWithin5OfHigh"] = round(within_5 / total * 100, 1)

    if ytd_pcts:
        positive_ytd = sum(1 for y in ytd_pcts if y >= 0)
        misc["pctPositiveYTD"] = round(positive_ytd / total * 100, 1)
        misc["avgYTD"] = round(sum(ytd_pcts) / len(ytd_pcts), 2)

    if forward_pes:
        misc["avgForwardPE"] = round(sum(forward_pes) / len(forward_pes), 2)
        sorted_pes = sorted(forward_pes)
        mid = len(sorted_pes) // 2
        if len(sorted_pes) % 2 == 0:
            misc["medianForwardPE"] = round((sorted_pes[mid - 1] + sorted_pes[mid]) / 2, 2)
        else:
            misc["medianForwardPE"] = round(sorted_pes[mid], 2)

    # EMA above/below percentages
    if total_symbols > 0:
        misc["pctAbove5wkEMA"] = round(week_above_count / total_symbols * 100, 1)
        misc["pctBelow5wkEMA"] = round((total_symbols - week_above_count) / total_symbols * 100, 1)

    return misc


def _update_manifest(bucket: str, scan_date: str) -> None:
    manifest = _read_json(bucket, "results/manifest.json") or {"weeks": []}
    weeks: list[str] = manifest.get("weeks", [])

    if scan_date not in weeks:
        weeks.insert(0, scan_date)
    else:
        weeks.remove(scan_date)
        weeks.insert(0, scan_date)

    trimmed = weeks[MAX_WEEKLY_SNAPSHOTS:]
    weeks = weeks[:MAX_WEEKLY_SNAPSHOTS]

    for old_date in trimmed:
        _delete_snapshot(bucket, old_date)

    _put_json(bucket, "results/manifest.json", {"weeks": weeks})


def _delete_snapshot(bucket: str, scan_date: str) -> None:
    suffixes = ["", "-crossdown", "-below", "-above", "-monthly", "-monthly-below-above", "-stats"]
    for suffix in suffixes:
        key = f"results/{scan_date}{suffix}.json"
        try:
            s3.delete_object(Bucket=bucket, Key=key)
        except Exception as err:
            print(f"[worker] failed to delete s3://{bucket}/{key}: {err}")


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
