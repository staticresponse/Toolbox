import os
import hashlib
import json
import logging
import traceback

from datetime import datetime

from helpers.sqs import (
    send_single,
    send_batch
)
from helpers.s3 import (
    inspect_prefix,
    list_files,
    head_object,
    get_object_tags
)
from helpers.opensearch import opensearch_request
from helpers.telemetry import generate_record, bulk_block


SCAN_QUEUE = os.getenv("SCAN_QUEUE")
PROCESS_QUEUE = os.getenv("PROCESS_QUEUE")
DEFAULT_PAGE_SIZE = int(os.getenv("DEFAULT_PAGE_SIZE", 1000))
LOG_LEVEL = os.getenv("LOG_LEVEL", "WARN")
host = os.getenv("opensearch_host")




logger = logging.getLogger()
logger.setLevel(LOG_LEVEL)
headers = {"Content-Type": "application/z-ndjson", "Host": host.replace('https://','').split('/')[0]}
'''

    File Processing

'''
def compare_dates(last_modified, nlt):
    logger.info(f"eval: {last_modified} < {nlt}")
    return str(last_modified) < str(nlt)

def process_file(bucket, key, size, storage_class, last_modified, nlt, etag="scanner"):
    logger.info(f"Processing: {bucket}/{key}")
    if(compare_dates(last_modified,nlt)):
        uuid = hashlib.sha256(f"{bucket}:{key}".encode()).hexdigest()
        c_id = key.split("/")[0]
        logger.info(f"Attempting to stage record for {uuid}")
        try:
            storage_info = generate_record(bucket,key,size,etag,storage_class,last_modified)
        except Exception:
            traceback.print_exc()
        try:
            block = bulk_block(uuid,bucket, c_id, storage_info)
        except Exception:
            traceback.print_exc()
        return block 
    logger.info(f"File not in range. Skipping")
    return ""

def process_job(job):
    bucket = job["bucket"]
    prefix = job["prefix"]
    nlt = job.get("nlt")
    page_size = int(job.get("page_size",DEFAULT_PAGE_SIZE))
    continuation_token = job.get("continuation_token", None)

    listing = list_files(
        bucket = bucket,
        prefix = prefix,
        continuation_token = continuation_token,
        max_keys = page_size
    )
    files = listing["files"]
    bulk_payload = ""
    for file in files:
        bulk_payload += process_file(
            bucket=bucket,
            key=file["Key"],
            size=file["Size"],
            storage_class=file["StorageClass"],
            last_modified=file["LastModified"],
            nlt=nlt,
            etag=file["ETag"]
        )
    if (len(bulk_payload) > 0):
        opensearch_request("POST", headers, "_bulk", bulk_payload)
        logger.info(f"Wrote {len(files)} records to OpenSearch")
    if listing.get("is_truncated"):
        logger.info(f"Process_Job Queueing Sharded Search")
        send_single(
            PROCESS_QUEUE,
            {
                "job_type":"process",
                "bucket":bucket,
                "prefix":prefix,
                "continuation_token":listing["next_token"],
                "page_size":page_size,
                "nlt": nlt
            }
        )
    else:
        logger.info("Processed All Files at this depth")
    return 200

'''

    Scanner

'''
def scan_job(job):
    bucket = job["bucket"]
    prefix = job["prefix"]
    current_depth = int(job["current_depth"])
    target_depth = int(job["target_depth"])
    nlt = job.get("nlt")

    logger.info(f"Scan_Job: scanning prefix {prefix} at depth: {current_depth}/{target_depth}")

    inspection = inspect_prefix(bucket, prefix, DEFAULT_PAGE_SIZE)
    child_prefixes = inspection["child_prefixes"]
    has_files = inspection["has_files"]
    has_child_prefixes = inspection["has_child_prefixes"]
    
    if has_files:
        message = {
            "job_type":"process",
            "bucket":bucket,
            "prefix":prefix,
            "page_size": DEFAULT_PAGE_SIZE,
            "nlt": nlt
        }
        send_single(
            PROCESS_QUEUE,
            message
        )
    #EXIT CASES
    if current_depth >= target_depth:
        return
    if not has_child_prefixes:
        return
    
    # Recursive fan out invocation
    batch = []
    for child_prefix in child_prefixes:
        batch.append({
            "job_type":"scan",
            "bucket":bucket,
            "prefix": child_prefix,
            "current_depth":current_depth+1,
            "target_depth":target_depth,
            "nlt":nlt
        })
        if len(batch) == 10:
            logger.info("Sending Batch of 10")
            send_batch(
                SCAN_QUEUE,
                batch
            )
            batch = []
    if batch:
        logger.info("Sending last chunk")
        send_batch(
            SCAN_QUEUE,
            batch
        )


def lambda_handler(event,context):
    if 'Records' in event and len(event['Records']) > 0:
        for record in event["Records"]:
            body = json.loads(record["body"])
            job_type = body.get("job_type", "UNK")
            logger.info(f"Job: {job_type}")
            try:
                if job_type == "scan":
                    scan_job(body)
                elif job_type == "process":
                    process_job(body)
                else:
                    raise Exception(f"Unknown Job Type: {job_type}")
            except Exception:
                return {
                    "statusCode": 500,
                    "body":json.dumps({"status":"failure"})
                }

    else:
        try:
            job_type = event.get("job_type", "UNK")
            logger.info(f"Job: {job_type}")
            if job_type == "scan":
                scan_job(event)
            elif job_type == "process":
                process_job(event)
            else:
                raise Exception(f"Unknown Job Type: {job_type}")
        except Exception:
            return {
                "statusCode": 500,
                "body":json.dumps({"status":"failure"})
            }
    return {
        "statusCode": 200,
        "body":json.dumps({"status":"success"})
    }

