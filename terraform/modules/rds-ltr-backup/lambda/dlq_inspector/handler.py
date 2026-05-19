import json
import boto3
import logging
from shared.utils import get_env, send_to_slack

logger = logging.getLogger()
logger.setLevel(logging.INFO)

DLQ_URL = get_env("DLQ_URL")
SLACK_WEBHOOK = get_env("SLACK_WEBHOOK")
sqs = boto3.client("sqs")

def handler(event, context):
    response = sqs.receive_message(QueueUrl=DLQ_URL, MaxNumberOfMessages=10)
    messages = response.get("Messages", [])

    if not messages:
        return

    failures = [json.loads(m["Body"]) for m in messages]
    payload = {
        "text": f"🚨 RDS Backup Failures: {len(failures)}",
        "attachments": [{"color": "danger", "text": json.dumps(failures[:3], indent=2)}]
    }
    send_to_slack(SLACK_WEBHOOK, payload)