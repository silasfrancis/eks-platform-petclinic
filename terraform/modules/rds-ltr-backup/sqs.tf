# RDS LTR Automated Backup — SQS
#
# Main queue receives snapshot-complete events for the processor Lambda to
# consume; messages that fail processing 5 times are redirected to the DLQ,
# which triggers the dlq_inspector via SNS


# Main queue — triggers the processor Lambda on snapshot-complete events
resource "aws_sqs_queue" "main" {
  count = var.enable_rds_ltr_backup ? 1 : 0
  name  = "${var.app}-${var.env}-rds-backup-queue"

  visibility_timeout_seconds = 300
  message_retention_seconds  = 345600
  receive_wait_time_seconds  = 20
  sqs_managed_sse_enabled   = true
}

# Dead-letter queue — receives messages that failed processing 5 times
resource "aws_sqs_queue" "dlq" {
  count = var.enable_rds_ltr_backup ? 1 : 0
  name  = "${var.app}-${var.env}-rds-backup-dlq"

  message_retention_seconds = 345600
  sqs_managed_sse_enabled   = true
}

resource "aws_sqs_queue_redrive_allow_policy" "dlq_allow" {
  count     = var.enable_rds_ltr_backup ? 1 : 0
  queue_url = aws_sqs_queue.dlq[0].id

  redrive_allow_policy = jsonencode({
    redrivePermission = "byQueue"
    sourceQueueArns   = [aws_sqs_queue.main[0].arn]
  })
}

resource "aws_sqs_queue_redrive_policy" "main" {
  count     = var.enable_rds_ltr_backup ? 1 : 0
  queue_url = aws_sqs_queue.main[0].id

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq[0].arn
    maxReceiveCount     = 5
  })
}