import boto3
import json
from datetime import timezone

# ---------------- CONFIG ---------------- #

BUCKET_NAME = "my-bucket"
PREFIX = ""  # optional, e.g. "data/2024/"
EVENT_BUS_NAME = "my-ingest-bus"

SOURCE = "custom.s3.replay"
DETAIL_TYPE = "S3 Object Created (Replay)"

AWS_REGION = "us-east-1"

# ---------------------------------------- #

s3 = boto3.client("s3", region_name=AWS_REGION)
events = boto3.client("events", region_name=AWS_REGION)


def list_s3_objects(bucket, prefix=""):
    paginator = s3.get_paginator("list_objects_v2")
    for page in paginator.paginate(Bucket=bucket, Prefix=prefix):
        for obj in page.get("Contents", []):
            yield obj


def send_event(obj):
    event_time = obj["LastModified"].astimezone(timezone.utc)

    detail = {
        "bucket": BUCKET_NAME,
        "key": obj["Key"],
        "size": obj["Size"],
        "etag": obj["ETag"].strip('"'),
        "eventSource": "aws:s3"
    }

    response = events.put_events(
        Entries=[
            {
                "EventBusName": EVENT_BUS_NAME,
                "Source": SOURCE,
                "DetailType": DETAIL_TYPE,
                "Time": event_time,
                "Detail": json.dumps(detail)
            }
        ]
    )

    if response["FailedEntryCount"] > 0:
        print("❌ Failed:", response["Entries"])
    else:
        print(f"✅ Sent: {obj['Key']} @ {event_time.isoformat()}")


def main():
    print(f"Replaying objects from s3://{BUCKET_NAME}/{PREFIX}")

    for obj in list_s3_objects(BUCKET_NAME, PREFIX):
        send_event(obj)


if __name__ == "__main__":
    main()
