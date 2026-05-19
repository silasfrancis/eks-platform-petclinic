import boto3
from shared.utils import get_env, send_to_slack

DLQ_URL = get_env("DLQ_URL")
SLACK_WEBHOOK = get_env("SLACK_WEBHOOK")
sqs = boto3.client("sqs")

def handler(event, context):
    attrs = sqs.get_queue_attributes(QueueUrl=DLQ_URL, AttributeNames=["ApproximateNumberOfMessages"])
    count = int(attrs["Attributes"]["ApproximateNumberOfMessages"])

    payload = {
        "text": "📊 Daily RDS Backup Summary",
        "attachments": [{
            "color": "good" if count == 0 else "warning",
            "fields": [
                {"title": "Status", "value": "Healthy" if count == 0 else "Issues", "short": True},
                {"title": "DLQ Count", "value": str(count), "short": True}
            ]
        }]
    }
    send_to_slack(SLACK_WEBHOOK, payload)
