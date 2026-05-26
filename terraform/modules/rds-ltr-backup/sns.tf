resource "aws_sns_topic" "alerts" {
  name = "${var.app}-${var.env}-rds-backup-alerts"
}

resource "aws_sns_topic_subscription" "dlq_lambda" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.dlq_inspector.arn
}