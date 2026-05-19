import json
import boto3
import logging
from datetime import datetime
from shared.utils import get_env, validate_event_detail

logger = logging.getLogger()
logger.setLevel(logging.INFO)

S3_BUCKET = get_env("S3_BUCKET")
IAMROLE_ARN = get_env("IAMROLE_ARN")
KMS_KEY_ARN = get_env("KMS_KEY_ARN")
ENV = get_env("ENV")
rds = boto3.client("rds")
EXPECTED_DB = get_env("DB_IDENTIFIER")

def handler(event, context):
    for record in event["Records"]:
        try:
            body = json.loads(record["body"])
            detail = validate_event_detail(body)
            
            snapshot_arn = detail["SourceArn"]
            db_id = detail.get("SourceIdentifier")

            if db_id != EXPECTED_DB:
                logger.warning(f"Unexpected DB identifier: {db_id}")
                return

            timestamp = datetime.now().strftime("%Y-%m-%d-%H-%M")

            logger.info(f"Triggering export for {db_id}")
            rds.start_export_task(
                ExportTaskIdentifier=f"{db_id}-export-{timestamp}", 
                SourceArn=snapshot_arn,
                S3BucketName=S3_BUCKET,
                IamRoleArn=IAMROLE_ARN,
                KmsKeyId=KMS_KEY_ARN,
                S3Prefix=f"{ENV}/automated/",
            )
            
        except Exception as e:
            logger.error(f"Processing error: {str(e)}")
            raise
