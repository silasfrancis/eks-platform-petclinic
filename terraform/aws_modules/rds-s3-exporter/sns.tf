resource "aws_sns_topic" "rds_export_alerts" {
  name              = "${var.env}-rds-export-alerts"
  kms_master_key_id = var.rds_export_kms_key_id
  tags = {
    env = var.env
    app = var.application
  }
}

resource "aws_sns_topic_subscription" "slack" {
  topic_arn = aws_sns_topic.rds_export_alerts.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.slack_notifier.arn
}