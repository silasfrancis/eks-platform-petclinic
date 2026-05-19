resource "aws_cloudwatch_log_group" "rds_export_lambda_processor" {
  name              = "/aws/lambda/${var.env}-${var.app}-rds-export-processor"
  retention_in_days = 3 
  kms_key_id        = var.infra_common_kms_key_arn

  tags = {
    resource = "cloudwatch"
  }
}

resource "aws_cloudwatch_log_group" "dlq_inspector" {
  name              = "/aws/lambda/${var.app}-${var.env}-rds-dlq-inspector"
  retention_in_days = 3
  kms_key_id        = var.infra_common_kms_key_arn
}

resource "aws_cloudwatch_log_group" "summary" {
  name              = "/aws/lambda/${var.app}-${var.env}-rds-backup-summary"
  retention_in_days = 3
  kms_key_id        = var.infra_common_kms_key_arn
}

resource "aws_cloudwatch_metric_alarm" "dlq_alarm" {
  alarm_name          = "rds-dlq-messages"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 300
  statistic           = "Sum"
  threshold           = 0

  dimensions = {
    QueueName = aws_sqs_queue.dlq.name
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
}