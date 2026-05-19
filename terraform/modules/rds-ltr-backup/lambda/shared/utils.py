import os
import json
import urllib.request

def get_env(key):
    """Retrieves environment variable or raises a clear ValueError."""
    value = os.environ.get(key)
    if not value:
        raise ValueError(f"Missing required environment variable: {key}")
    return value

def validate_event_detail(body):
    """Validates the structure of the RDS event body."""
    detail = body.get("detail")
    if not detail or "SourceArn" not in detail:
        raise ValueError("Missing SourceArn in event detail")
    return detail

def send_to_slack(webhook_url, message):
    """Helper to send JSON payloads to a Slack Webhook."""
    req = urllib.request.Request(
        webhook_url,
        data=json.dumps(message).encode(),
        headers={"Content-Type": "application/json"}
    )
    return urllib.request.urlopen(req)