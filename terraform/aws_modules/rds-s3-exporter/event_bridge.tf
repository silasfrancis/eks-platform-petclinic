resource "aws_cloudwatch_event_rule" "rds_snapshot_complete" {
  name        = "${var.env}-rds-snapshot-complete"
  description = "Fires when RDS automated snapshot completes"

  event_pattern = jsonencode({
    source      = ["aws.rds"]
    detail-type = ["RDS DB Snapshot Event"]
    detail = {
      EventID          = ["RDS-EVENT-0091"]
      SourceIdentifier = [var.db_instance_identifier]
    }
  })
}

resource "aws_cloudwatch_event_target" "rds_export" {
  rule      = aws_cloudwatch_event_rule.rds_snapshot_complete.name
  target_id = "TriggerSnapshotExport"
  arn       = aws_lambda_function.rds_export_trigger.arn
  depends_on = [ aws_lambda_function.rds_export_trigger ]
}