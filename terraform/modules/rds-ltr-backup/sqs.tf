resource "aws_sqs_queue" "dlq" {
  name = "${var.app}-${var.env}-rds-backup-dlq"

  message_retention_seconds = 345600

  sqs_managed_sse_enabled = true
}

resource "aws_sqs_queue" "main" {
  name = "${var.app}-${var.env}-rds-backup-queue"

  visibility_timeout_seconds = 300
  message_retention_seconds  = 345600
  receive_wait_time_seconds  = 20

  sqs_managed_sse_enabled = true
}

resource "aws_sqs_queue_redrive_allow_policy" "dlq_allow" {
  queue_url = aws_sqs_queue.dlq.id

  redrive_allow_policy = jsonencode({
    redrivePermission = "byQueue"
    sourceQueueArns   = [aws_sqs_queue.main.arn]
  })
}

resource "aws_sqs_queue_redrive_policy" "main" {
  queue_url = aws_sqs_queue.main.id

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = 5
  })
}