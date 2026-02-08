import boto3
import json
import os
import uuid
from datetime import timezone
import hashlib
from datetime import datetime
from botocore.exceptions import ClientError

BUCKET_NAME = "demo-bucket"
PREFIX = "example-prefix/"
REGION = "us-east-1"
ACCOUNT_ID = "12345678910"
QUEUE_NAME = "your-queue-name"
LOG_FILE = "processed_keys.log"
SQS_QUEUE_URL = f"https://sqs.us-east-1.amazonaws.com/{ACCOUNT_ID}/{QUEUE_NAME}"

sqs = boto3.client("sqs")
s3 = boto3.client("s3")


def load_processed_keys():
    if not os.path.exists(LOG_FILE):
        return set()

    with open(LOG_FILE, "r") as f:
        return set(line.strip() for line in f if line.strip())


def mark_processed(key):
    with open(LOG_FILE, "a") as f:
        f.write(f"{key}\n")


def build_event(object_info, head):
    last_modified = object_info["LastModified"].astimezone(timezone.utc)

    return {
        "version": "0",
        "id": str(uuid.uuid4()),
        "detail-type": "Object Created",
        "source": "aws.s3",
        "account": ACCOUNT_ID,
        "time": last_modified.isoformat().replace("+00:00", "Z"),
        "region": REGION,
        "resources": [
            f"arn:aws:s3:::{BUCKET_NAME}"
        ],
        "detail": {
            "version": "0",
            "bucket": {
                "name": BUCKET_NAME
            },
            "object": {
                "key": object_info["Key"],
                "size": object_info["Size"],
                "etag": head.get("ETag", "").strip('"'),
                "version-id": head.get("VersionId"),
                "sequencer": uuid.uuid4().hex[:16]
            },
            "request-id": head.get("RequestId", str(uuid.uuid4())),
            "requester": ACCOUNT_ID,
            "source-ip-address": "127.0.0.1",
            "reason": "PutObject"
        }
    }

def getScan(event: dict) -> dict:
    detail = event.get("detail", {})
    bucket = detail.get("bucket", {}).get("name")
    obj = detail.get("object", {})

    key = obj.get("key")
    size = obj.get("size", 0)
    etag = obj.get("etag")
    version_id = obj.get("version-id")

    if not bucket or not key:
        raise ValueError("Invalid S3 event: missing bucket or key")

    event_time = event.get("time")
    scan_time = datetime.fromisoformat(
        event_time.replace("Z", "+00:00")
    ).isoformat()

    dedupe_source = f"{bucket}:{key}:{etag}:{version_id}"
    scan_id = hashlib.sha256(dedupe_source.encode()).hexdigest()

    event["scan"] = {
        "scan_id": scan_id,
        "scan_time": scan_time,
        "status": "pending",
        "engine": "s3-replay-ingest",
        "replay": True
    }

    event["storage"] = {
        "provider": "aws",
        "service": "s3",
        "region": event.get("region"),
        "bucket": bucket,
        "key": key,
        "size": size,
        "etag": etag,
        "version_id": version_id,
        "arn": f"arn:aws:s3:::{bucket}/{key}"
    }

    return event



def putMessage(event: dict) -> None:
    sqs.send_message(
        QueueUrl=SQS_QUEUE_URL,
        MessageBody=json.dumps(event, default=str)
    )


def safe_head_object(bucket, key):
    try:
        return s3.head_object(Bucket=bucket, Key=key)
    except ClientError as e:
        error_code = e.response.get("Error", {}).get("Code")

        if error_code in ("403", "AccessDenied"):
            return {}
        raise


def crawl_bucket():
    processed = load_processed_keys()
    paginator = s3.get_paginator("list_objects_v2")

    for page in paginator.paginate(
        Bucket=BUCKET_NAME,
        Prefix=PREFIX,
        PaginationConfig={"PageSize": 1000}
    ):
        contents = page.get("Contents", [])
        if not contents:
            continue

        for obj in contents:
            key = obj["Key"]

            if key in processed:
                continue

            head = safe_head_object(BUCKET_NAME, key)

            event = build_event(obj, head)
            getScan(event)
            putMessage(event)

            mark_processed(key)
            processed.add(key)



if __name__ == "__main__":
    crawl_bucket()
