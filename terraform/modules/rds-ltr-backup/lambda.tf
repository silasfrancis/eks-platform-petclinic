# RDS LTR Automated Backup — Lambda Functions
#
# Three Lambdas, each packaged with a shared utils module:
#   - processor: triggered by SQS on snapshot-complete events; starts an RDS
#     export task to S3 using the rds_export_role
#   - dlq_inspector: triggered by SNS when a message lands in the DLQ; posts
#     a failure alert to Slack
#   - summary: triggered daily by EventBridge; posts a backup status summary
#     to Slack

locals {
  # Shared Python module bundled into every Lambda's zip alongside its
  # handler.py
  shared_files = {
    "shared/__init__.py" = "${path.module}/lambda/shared/__init__.py"
    "shared/utils.py"    = "${path.module}/lambda/shared/utils.py"
  }
}

# Package for the snapshot-export processor
data "archive_file" "processor" {
  count       = var.enable_rds_ltr_backup ? 1 : 0
  type        = "zip"
  output_path = "${path.module}/build/processor.zip"

  source {
    content  = file("${path.module}/lambda/processor/handler.py")
    filename = "handler.py"
  }

  dynamic "source" {
    for_each = local.shared_files
    content {
      content  = file(source.value)
      filename = source.key
    }
  }
}

# Package for the DLQ inspector
data "archive_file" "dlq_inspector" {
  count       = var.enable_rds_ltr_backup ? 1 : 0
  type        = "zip"
  output_path = "${path.module}/build/dlq_inspector.zip"

  source {
    content  = file("${path.module}/lambda/dlq_inspector/handler.py")
    filename = "handler.py"
  }

  dynamic "source" {
    for_each = local.shared_files
    content {
      content  = file(source.value)
      filename = source.key
    }
  }
}

# Package for the daily summary report
data "archive_file" "summary" {
  count       = var.enable_rds_ltr_backup ? 1 : 0
  type        = "zip"
  output_path = "${path.module}/build/summary.zip"

  source {
    content  = file("${path.module}/lambda/summary/handler.py")
    filename = "handler.py"
  }

  dynamic "source" {
    for_each = local.shared_files
    content {
      content  = file(source.value)
      filename = source.key
    }
  }
}

# Triggered via SQS (aws_lambda_event_source_mapping below); starts an RDS
# export task to S3 when a snapshot-complete event is received
resource "aws_lambda_function" "processor" {
  count            = var.enable_rds_ltr_backup ? 1 : 0
  function_name    = "${var.app}-${var.env}-rds-export-processor"
  role             = aws_iam_role.lambda_rds_backup[0].arn
  filename         = data.archive_file.processor[0].output_path
  source_code_hash = data.archive_file.processor[0].output_base64sha256
  handler          = "handler.handler"
  runtime          = "python3.11"
  timeout          = 60

  environment {
    variables = {
      S3_BUCKET     = var.rds_backup_bucket
      IAMROLE_ARN   = aws_iam_role.rds_export_role[0].arn
      KMS_KEY_ARN   = var.data_storage_kms_key_arn
      DB_IDENTIFIER = var.db_instance_identifier
      ENV           = var.env
    }
  }

  tags = var.extended_tags

  depends_on = [aws_cloudwatch_log_group.rds_export_lambda_processor]
}

# Triggered via SNS (aws_lambda_permission.allow_sns below) when a message
# lands in the DLQ; posts a failure alert to Slack
resource "aws_lambda_function" "dlq_inspector" {
  count            = var.enable_rds_ltr_backup ? 1 : 0
  function_name    = "${var.app}-${var.env}-rds-dlq-inspector"
  role             = aws_iam_role.lambda_rds_backup[0].arn
  filename         = data.archive_file.dlq_inspector[0].output_path
  source_code_hash = data.archive_file.dlq_inspector[0].output_base64sha256
  handler          = "handler.handler"
  runtime          = "python3.11"
  timeout          = 60

  environment {
    variables = {
      SLACK_WEBHOOK = var.slack_webhook
      DLQ_URL       = aws_sqs_queue.dlq[0].id
    }
  }

  tags = var.extended_tags

  depends_on = [aws_cloudwatch_log_group.dlq_inspector]
}

# Triggered daily via EventBridge (aws_lambda_permission.allow_eventbridge
# below); posts a backup status summary to Slack
resource "aws_lambda_function" "summary" {
  count            = var.enable_rds_ltr_backup ? 1 : 0
  function_name    = "${var.app}-${var.env}-rds-backup-summary"
  role             = aws_iam_role.lambda_rds_backup[0].arn
  filename         = data.archive_file.summary[0].output_path
  source_code_hash = data.archive_file.summary[0].output_base64sha256
  handler          = "handler.handler"
  runtime          = "python3.11"
  timeout          = 60

  environment {
    variables = {
      SLACK_WEBHOOK = var.slack_webhook
      DLQ_URL       = aws_sqs_queue.dlq[0].id
    }
  }

  tags = var.extended_tags

  depends_on = [aws_cloudwatch_log_group.summary]
}

# Wires the main SQS queue as the trigger for the processor Lambda
resource "aws_lambda_event_source_mapping" "sqs_trigger" {
  count            = var.enable_rds_ltr_backup ? 1 : 0
  event_source_arn = aws_sqs_queue.main[0].arn
  function_name    = aws_lambda_function.processor[0].arn
}

# Allows the SNS alerts topic to invoke the DLQ inspector
resource "aws_lambda_permission" "allow_sns" {
  count         = var.enable_rds_ltr_backup ? 1 : 0
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.dlq_inspector[0].function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.alerts[0].arn
}

# Allows the daily summary EventBridge rule to invoke the summary Lambda
resource "aws_lambda_permission" "allow_eventbridge" {
  count         = var.enable_rds_ltr_backup ? 1 : 0
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.summary[0].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.daily_summary[0].arn
}