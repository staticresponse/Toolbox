import json
import boto3
import logging
from botocore.config import Config

config = Config(retries = {
    "max_attempts":3,
    "mode":"adaptive"
})

sqs_client = boto3.client("sqs", config=config)
logger = logging.get.logger(__name__)

def send_batch(queue,messages):
    if not messages:
        return
    entries = []
    for idx,msg in enumerate(messages):
        entries.append({
            "Id": str(idx),
            "MessageBody": json.dumps(msg)
        })
    response = sqs_client.send_message_batch(
        QueueUrl=queue,
        Entries=entries
    )
    failures = response.get("Failed", [])
    if failures:
        logger.error(f"SQS Failure: {failures}")
def send_single(queue, message):
    sqs_client.send_message(
        QueueUrl=queue,
        MessageBody=json.dumps(message)
    )