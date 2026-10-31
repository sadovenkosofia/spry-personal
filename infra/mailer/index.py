import logging
import os
import urllib.parse
from email.message import EmailMessage

import boto3

log = logging.getLogger()
log.setLevel(logging.INFO)
s3 = boto3.client("s3")
ses = boto3.client("sesv2")


def handler(event, context):
    rec = event["Records"][0]
    bucket = rec["s3"]["bucket"]["name"]
    key = urllib.parse.unquote_plus(rec["s3"]["object"]["key"])
    # This is the line you submit for the S3 trigger.
    log.info(
        "report-mailer triggered trigger=s3 event_source=%s bucket=%s key=%s",
        rec["eventName"], bucket, key,
    )

    data = s3.get_object(Bucket=bucket, Key=key)["Body"].read()
    filename = key.rsplit("/", 1)[-1]
    week = filename.removesuffix(".csv")
    sender = os.environ["SENDER"]
    recipients = [
        r.strip() for r in os.environ["RECIPIENTS"].split(",") if r.strip()
    ]

    msg = EmailMessage()
    msg["From"] = sender
    msg["To"] = ", ".join(recipients)
    msg["Subject"] = f"Spry weekly meetings report {week}"
    msg.set_content(f"The weekly meetings report for {week} is attached.")
    msg.add_attachment(
        data, maintype="text", subtype="csv", filename=filename
    )

    ses.send_email(
        FromEmailAddress=sender,
        Destination={"ToAddresses": recipients},
        Content={"Raw": {"Data": msg.as_bytes()}},
    )
    log.info("report-mailer sent key=%s to=%s", key, recipients)
