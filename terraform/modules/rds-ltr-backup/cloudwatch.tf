resource "aws_cloudwatch_log_group" "rds_export_lambda_processor" {
  count = var.enable_rds_ltr_backup ? 1 : 0

  name              = "/aws/lambda/${var.app}-${var.env}-rds-export-processor"
  retention_in_days = 3 
  kms_key_id        = var.infra_common_kms_key_arn

  tags = var.extended_tags
}

resource "aws_cloudwatch_log_group" "dlq_inspector" {
  count = var.enable_rds_ltr_backup ? 1 : 0

  name              = "/aws/lambda/${var.app}-${var.env}-rds-dlq-inspector"
  retention_in_days = 3
  kms_key_id        = var.infra_common_kms_key_arn

  tags = var.extended_tags
}

resource "aws_cloudwatch_log_group" "summary" {
  count = var.enable_rds_ltr_backup ? 1 : 0

  name              = "/aws/lambda/${var.app}-${var.env}-rds-backup-summary"
  retention_in_days = 3
  kms_key_id        = var.infra_common_kms_key_arn

  tags = var.extended_tags
}

resource "aws_cloudwatch_metric_alarm" "dlq_alarm" {
  count = var.enable_rds_ltr_backup ? 1 : 0

  alarm_name          = "${var.app}-${var.env}-rds-dlq-messages"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 300
  statistic           = "Sum"
  threshold           = 0

  dimensions = {
    QueueName = aws_sqs_queue.dlq[0].name
  }

  alarm_actions = [aws_sns_topic.alerts[0].arn]
}