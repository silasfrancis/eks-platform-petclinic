import urllib3
import json
import os

def handler(event, context):
    try:
        message   = json.loads(event['Records'][0]['Sns']['Message'])
        alarm_name = message['AlarmName']
        new_state  = message['NewStateValue']
        reason     = message['NewStateReason']

        slack_data = {
            "text": f":rotating_light: RDS Export Alarm triggered!",
            "attachments": [{
                "color": "danger" if new_state == "ALARM" else "good",
                "fields": [
                    {"title": "Alarm",  "value": alarm_name, "short": True},
                    {"title": "Status", "value": new_state,  "short": True},
                    {"title": "Reason", "value": reason,     "short": False}
                ]
            }]
        }

        http     = urllib3.PoolManager()
        response = http.request(
            'POST',
            os.environ['SLACK_WEBHOOK_URL'],
            body    = json.dumps(slack_data),
            headers = {'Content-Type': 'application/json'}
        )

        return {"status": "sent", "http_status": response.status}

    except KeyError as e:
        print(f"Missing key in event payload: {e}")
        raise
    except Exception as e:
        print(f"Failed to send Slack alert: {e}")
        raise