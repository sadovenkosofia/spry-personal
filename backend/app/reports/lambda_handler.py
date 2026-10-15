"""report-builder Lambda (runs inside the VPC, next to the database).

Triggers it understands:
  * SQS record   - schedule -> queue -> here, or `make report-now`
  * direct call  - e.g. `aws lambda invoke` with {"source": "schedule"}

It writes reports/<week>.csv to S3. It knows nothing about e-mail: the
S3 ObjectCreated event starts the mailer.
"""

import json
import logging
import os

import boto3

from app.reports.weekly import build_weekly_report, previous_week, report_key

# Lambda's root logger defaults to WARNING, so INFO lines vanish without this.
log = logging.getLogger()
log.setLevel(logging.INFO)

s3 = boto3.client("s3")


def parse_event(event: dict) -> tuple[str, str, dict]:
    """Return (trigger, event_source, payload).

    trigger       what started the work: "schedule", "sqs" or "direct"
    event_source  how it arrived: "aws:sqs" or "invoke"
    """
    records = event.get("Records")
    if records and records[0].get("eventSource") == "aws:sqs":
        payload = json.loads(records[0]["body"])
        # The schedule also travels through SQS; its message says who sent it.
        trigger = "schedule" if payload.get("source") == "schedule" else "sqs"
        return trigger, "aws:sqs", payload
    trigger = "schedule" if event.get("source") == "schedule" else "direct"
    return trigger, "invoke", event


def handler(event, context):
    # BatchSize is 1 in the event source mapping, so there is one record.
    trigger, event_source, payload = parse_event(event)
    week = payload.get("week") or previous_week()

    # This is the line you submit.
    log.info(
        "report-builder triggered trigger=%s event_source=%s week=%s",
        trigger, event_source, week,
    )

    csv_bytes = build_weekly_report(week)  # a bad week raises -> retry -> DLQ
    key = report_key(week)
    s3.put_object(
        Bucket=os.environ["REPORTS_BUCKET"],
        Key=key,
        Body=csv_bytes,
        ContentType="text/csv; charset=utf-8",
    )
    log.info("report-builder saved key=%s bytes=%d", key, len(csv_bytes))
    return {"key": key}
