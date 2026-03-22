data "archive_file" "rds_export" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/rds_export"
  output_path = "${path.module}/lambda/rds_export.zip"
}

data "archive_file" "slack_sns_notify" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/slack_sns_notify"
  output_path = "${path.module}/lambda/slack_sns_notify.zip"
}

resource "aws_lambda_function" "rds_export_trigger" {
  function_name    = "${var.env}-rds-export-trigger"
  filename         = data.archive_file.rds_export.output_path
  source_code_hash = data.archive_file.rds_export.output_base64sha256
  runtime          = "python3.12"
  handler          = "rds_exporter.start_export"
  role             = var.rds_export_lambda_role_arn
  timeout          = 60

  environment {
    variables = {
      ENV             = var.env
      S3_BUCKET       = var.rds_export_bucket
      EXPORT_ROLE_ARN = var.rds_export_role_arn
      KMS_KEY_ARN     = var.rds_export_kms_key_arn
    }
  }

  tags = {
    env = var.env
    app = var.application
  }
}

resource "aws_lambda_function" "slack_notifier" {
  function_name = "${var.env}-slack-notifier"
  filename = data.archive_file.slack_sns_notify.output_path
  source_code_hash = data.archive_file.slack_sns_notify.output_base64sha256
  runtime          = "python3.12"
  handler       = "slack_sns_notify.handler"
  role = var.slack_notify_lambda_role_arn
  timeout = 10
  environment {
    variables = {
      SLACK_WEBHOOK_URL = var.slack_webhook_url 
    }
  }

  tags = {
    env = var.env
    app = var.application
  }
}

resource "aws_lambda_permission" "eventbridge_rds_export" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.rds_export_trigger.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.rds_snapshot_complete.arn
  depends_on = [ aws_cloudwatch_event_rule.rds_snapshot_complete ]
}

resource "aws_lambda_permission" "sns_notify" {
  statement_id  = "NotifySlackOnRdsExportAlerts"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.slack_notifier.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.rds_export_alerts.arn
  depends_on = [ aws_sns_topic.rds_export_alerts ]
}