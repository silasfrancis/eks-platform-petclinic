resource "aws_cloudwatch_event_rule" "rds_snapshot_events" {
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
  tags = {
    resource = "event_bridge"
  }
}

resource "aws_cloudwatch_event_target" "to_sqs" {
  rule = aws_cloudwatch_event_rule.rds_snapshot_events.name
  arn  = aws_sqs_queue.main.arn
}

resource "aws_cloudwatch_event_rule" "daily_summary" {
  name                = "${var.app}-${var.env}-rds-daily-backup-summary"
  schedule_expression = "cron(0 18 * * ? *)"
  tags = {
    resource = "event_bridge"
  }
}

resource "aws_cloudwatch_event_target" "summary_target" {
  rule = aws_cloudwatch_event_rule.daily_summary.name
  arn  = aws_lambda_function.summary.arn
}