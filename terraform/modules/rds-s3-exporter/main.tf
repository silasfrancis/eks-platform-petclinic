resource "aws_cloudwatch_log_group" "rds_export_lambda" {
  name              = "/aws/lambda/${var.env}-rds-export-trigger"
  retention_in_days = 14
  kms_key_id        = var.rds_export_kms_key_arn

  tags = {
    resource = "cloudwatch"
  }
}

resource "aws_cloudwatch_metric_alarm" "rds_export_failed" {
  alarm_name          = "${var.env}-rds-export-failed"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  alarm_actions       = [aws_sns_topic.rds_export_alerts.arn]

  dimensions = {
    FunctionName = aws_lambda_function.rds_export_trigger.function_name
  }

  tags = {
    resource = "cloudwatch"
  }
}