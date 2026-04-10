import boto3
import os
from datetime import datetime

def start_export(event, context):
    rds = boto3.client('rds')
    
    snapshot_arn = event['detail']['SourceArn']
    timestamp    = datetime.now().strftime('%Y-%m-%d-%H-%M')
    
    rds.start_export_task(
        ExportTaskIdentifier = f"{os.environ['ENV']}-mysql-export-{timestamp}",
        SourceArn            = snapshot_arn,
        S3BucketName         = os.environ['S3_BUCKET'],
        IamRoleArn           = os.environ['EXPORT_ROLE_ARN'],
        KmsKeyId             = os.environ['KMS_KEY_ARN'],
        S3Prefix             = f"{os.environ['ENV']}/automated/",
    )
    
    return {"status": "export started", "snapshot": snapshot_arn}