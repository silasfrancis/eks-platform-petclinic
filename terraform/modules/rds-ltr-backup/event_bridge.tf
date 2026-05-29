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

resource "aws_cloudwatch_event_target" "to_sqs" {
  count = var.enable_rds_ltr_backup ? 1 : 0

  rule = aws_cloudwatch_event_rule.rds_snapshot_events[0].name
  arn  = aws_sqs_queue.main[0].arn
}

resource "aws_cloudwatch_event_rule" "daily_summary" {
  count = var.enable_rds_ltr_backup ? 1 : 0

  name                = "${var.app}-${var.env}-rds-daily-backup-summary"
  schedule_expression = "cron(0 18 * * ? *)"
  tags                = var.extended_tags
}

resource "aws_cloudwatch_event_target" "summary_target" {
  count = var.enable_rds_ltr_backup ? 1 : 0

  rule = aws_cloudwatch_event_rule.daily_summary[0].name
  arn  = aws_lambda_function.summary[0].arn
}