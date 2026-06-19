import logging
import boto3
import traceback
s3_client = boto3.client("s3")
logger = logging.getLogger(__name__)

def inspect_prefix(bucket, prefix, max_keys=1000):
    logger.info(f"Inspecting {bucket}/{prefix}")
    try:
        response = s3_client.list_objects_v2(
            Bucket=bucket,
            Prefix=prefix,
            Delimiter="/",
            MaxKeys=max_keys
        )
    except Exception:
        traceback.print_exc()
    child_prefixes = [
        cp["Prefix"] for cp in response.get("CommonPrefixes", [])
    ]
    files = [
        obj["Key"] for obj in response.get("Contents", []) if obj["Key"] != prefix
    ]
    return {
        "child_prefixes":child_prefixes,
        "has_child_prefixes": len(child_prefixes) > 0,
        "has_files": len(files) > 0,
        "direct_file_count_sample": len(files),
        "is_truncated": response.get("IsTruncated")
    }

def list_files(bucket,prefix,continuation_token=None,max_keys=1000):
    kwargs = {
        "Bucket":bucket,
        "Prefix":prefix,
        "MaxKeys":max_keys
    }
    if continuation_token:
        kwargs["ContinuationToken"] = continuation_token
    response = s3_client.list_objects_v2(**kwargs)
    files = [obj for obj in response.get("Contents",[]) if obj["Key"] != prefix]
    return {
        "files": files,
        "isTruncated":response.get("IsTruncated",False),
        "next_token":response.get("NextContinuationToken")
    }

def head_object(bucket,key):
    return s3_client.head_object(Bucket=bucket, Key=key)

def get_object_tags(bucket,key):
    response = s3_client.get_object_tagging(Bucket=bucket, Key=key)
    tags = response.get("TagSet", [])
    return {
        tag["Key"]: tag["Value"] for tag in tags
    }