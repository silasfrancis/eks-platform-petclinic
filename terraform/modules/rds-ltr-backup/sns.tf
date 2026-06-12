# RDS LTR Automated Backup — SNS
#
# Alert topic for DLQ failures, with the dlq_inspector Lambda subscribed
# directly (SNS invokes it on each alert to post a Slack notification)


resource "aws_sns_topic" "alerts" {
  count = var.enable_rds_ltr_backup ? 1 : 0
  name  = "${var.app}-${var.env}-rds-backup-alerts"
}

resource "aws_sns_topic_subscription" "dlq_lambda" {
  count     = var.enable_rds_ltr_backup ? 1 : 0
  topic_arn = aws_sns_topic.alerts[0].arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.dlq_inspector[0].arn
}