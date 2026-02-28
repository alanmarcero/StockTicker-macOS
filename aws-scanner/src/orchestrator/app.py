import json
import os
from datetime import datetime, timezone

import boto3

BATCH_SIZE = 50

s3 = boto3.client("s3")
sqs = boto3.client("sqs")


def lambda_handler(event: dict, context) -> dict:
    bucket = os.environ["BUCKET_NAME"]
    queue_url = os.environ["QUEUE_URL"]
    sneak_peek = event.get("sneakPeek", True)

    resp = s3.get_object(Bucket=bucket, Key="symbols/us-equities.txt")
    lines = resp["Body"].read().decode("utf-8").splitlines()
    symbols = [line.strip() for line in lines if line.strip()]

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
                "sneakPeek": sneak_peek,
                "symbols": batch,
            }),
        )

    return {
        "statusCode": 200,
        "body": {
            "runId": run_id,
            "totalSymbols": len(symbols),
            "totalBatches": total_batches,
        },
    }
