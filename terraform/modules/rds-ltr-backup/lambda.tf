locals {
  shared_files = {
    "shared/__init__.py" = "${path.module}/lambda/shared/__init__.py"
    "shared/utils.py"    = "${path.module}/lambda/shared/utils.py"
  }
}

data "archive_file" "processor" {
  type        = "zip"
  output_path = "${path.module}/build/processor.zip"

  source {
    content  = file("${path.module}/lambda/processor/handler.py")
    filename = "handler.py"
  }

  dynamic "source" {
    for_each = local.shared_files
    content {
      content  = file(source.value)
      filename = source.key
    }
  }
}

data "archive_file" "dlq_inspector" {
  type        = "zip"
  output_path = "${path.module}/build/dlq_inspector.zip"

  source {
    content  = file("${path.module}/lambda/dlq_inspector/handler.py")
    filename = "handler.py"
  }

  dynamic "source" {
    for_each = local.shared_files
    content {
      content  = file(source.value)
      filename = source.key
    }
  }
}

data "archive_file" "summary" {
  type        = "zip"
  output_path = "${path.module}/build/summary.zip"

  source {
    content  = file("${path.module}/lambda/summary/handler.py")
    filename = "handler.py"
  }

  dynamic "source" {
    for_each = local.shared_files
    content {
      content  = file(source.value)
      filename = source.key
    }
  }
}

resource "aws_lambda_function" "processor" {
  function_name    = "${var.app}-${var.env}-rds-export-processor"
  role             = aws_iam_policy.lambda_rds_backup.arn
  filename         = data.archive_file.processor.output_path
  source_code_hash = data.archive_file.processor.output_base64sha256
  handler          = "handler.handler"
  runtime          = "python3.11"
  timeout          = 60

  environment {
    variables = {
      S3_BUCKET        = var.rds_export_bucket
      IAMROLE_ARN      = aws_iam_role.rds_export_role.arn
      KMS_KEY_ARN      = var.data_storage_kms_key_arn
      DB_IDENTIFIER    = var.db_instance_identifier
      ENV              = var.env
    }
  }

  tags = var.extended_tags

  depends_on = [aws_cloudwatch_log_group.rds_export_lambda_processor]
}

resource "aws_lambda_function" "dlq_inspector" {
  function_name    = "${var.app}-${var.env}-rds-dlq-inspector"
  role             = aws_iam_policy.lambda_rds_backup.arn
  filename         = data.archive_file.dlq_inspector.output_path
  source_code_hash = data.archive_file.dlq_inspector.output_base64sha256
  handler          = "handler.handler"
  runtime          = "python3.11"
  timeout          = 60

  environment {
    variables = {
      SLACK_WEBHOOK = var.slack_webhook
      DLQ_URL       = aws_sqs_queue.dlq.id
    }
  }

  tags = var.extended_tags

  depends_on = [aws_cloudwatch_log_group.dlq_inspector]
}

resource "aws_lambda_function" "summary" {
  function_name    = "${var.app}-${var.env}-rds-backup-summary"
  role             = aws_iam_policy.lambda_rds_backup.arn
  filename         = data.archive_file.summary.output_path
  source_code_hash = data.archive_file.summary.output_base64sha256
  handler          = "handler.handler"
  runtime          = "python3.11"
  timeout          = 60

  environment {
    variables = {
      SLACK_WEBHOOK = var.slack_webhook
      DLQ_URL       = aws_sqs_queue.dlq.id
    }
  }

  tags = var.extended_tags

  depends_on = [aws_cloudwatch_log_group.summary]
}

resource "aws_lambda_event_source_mapping" "sqs_trigger" {
  event_source_arn = aws_sqs_queue.main.arn
  function_name    = aws_lambda_function.processor.arn
}

resource "aws_lambda_permission" "allow_sns" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.dlq_inspector.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.alerts.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.summary.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.daily_summary.arn
}