# RDS LTR (Long-Term Retention) Automated Backup — EventBridge
#
# Drives the backup pipeline on two triggers:
#   1. RDS automated snapshot completion event (RDS-EVENT-0091) for the
#      target DB instance -> enqueued to the main SQS queue, which the
#      processor Lambda consumes to start an export task to S3
#   2. Daily cron (18:00 UTC) -> triggers the summary Lambda to post a
#      backup status report to Slack
# Entire pipeline is gated by var.enable_rds_ltr_backup (disabled in dev)


# Fires when the target RDS instance completes an automated snapshot
resource "aws_cloudwatch_event_rule" "rds_snapshot_events" {
  count = var.enable_rds_ltr_backup ? 1 : 0

  name        = "${var.app}-${var.env}-rds-snapshot-complete"
  description = "Fires when RDS automated snapshot completes"

  event_pattern = jsonencode({
    source      = ["aws.rds"]
    detail-type = ["RDS DB Snapshot Event"]
    detail = {
      EventID          = ["RDS-EVENT-0091"]
      SourceIdentifier = [var.db_instance_identifier]
    }
  })
  tags = var.extended_tags
}

# Routes snapshot-complete events to the main SQS queue for processing
resource "aws_cloudwatch_event_target" "to_sqs" {
  count = var.enable_rds_ltr_backup ? 1 : 0

  rule = aws_cloudwatch_event_rule.rds_snapshot_events[0].name
  arn  = aws_sqs_queue.main[0].arn
}

# Daily 18:00 UTC trigger for the backup summary report
resource "aws_cloudwatch_event_rule" "daily_summary" {
  count = var.enable_rds_ltr_backup ? 1 : 0

  name                = "${var.app}-${var.env}-rds-daily-backup-summary"
  schedule_expression = "cron(0 18 * * ? *)"
  tags                = var.extended_tags
}

# Invokes the summary Lambda on the daily schedule
resource "aws_cloudwatch_event_target" "summary_target" {
  count = var.enable_rds_ltr_backup ? 1 : 0

  rule = aws_cloudwatch_event_rule.daily_summary[0].name
  arn  = aws_lambda_function.summary[0].arn
}