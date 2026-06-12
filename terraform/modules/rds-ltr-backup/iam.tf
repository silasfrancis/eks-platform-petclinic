# RDS LTR Automated Backup — IAM
#
# Two roles:
#   - lambda_rds_backup: assumed by all three Lambdas (processor,
#     dlq_inspector, summary). Can start/describe RDS export tasks, pass the
#     export role to RDS, consume from the main SQS queue, and write its own
#     logs (basic execution policy)
#   - rds_export_role: assumed by the RDS export service itself when writing
#     snapshot exports to S3, with read/write access to the backup bucket and
#     KMS access for encryption


# Role assumed by the Lambda functions
resource "aws_iam_role" "lambda_rds_backup" {
  count = var.enable_rds_ltr_backup ? 1 : 0

  name = "${var.app}-${var.env}-lambda-rds-backup-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
  tags = var.extended_tags
}

# Role assumed by the RDS export service when writing snapshot exports to S3
resource "aws_iam_role" "rds_export_role" {
  count = var.enable_rds_ltr_backup ? 1 : 0

  name = "${var.app}-${var.env}-rds-snapshot-export-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "export.rds.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
  tags = var.extended_tags
}

# Permissions for the Lambda role: start/describe RDS export tasks, pass the
# export role to RDS, and consume from the main SQS queue
resource "aws_iam_policy" "lambda_backup" {
  count = var.enable_rds_ltr_backup ? 1 : 0

  name = "${var.app}-${var.env}-lambda-backup-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "rds:StartExportTask",
          "rds:DescribeExportTasks"
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = "iam:PassRole"
        Resource = aws_iam_role.rds_export_role[0].arn
      },
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = aws_sqs_queue.main[0].arn
      }
    ]
  })

  tags = var.extended_tags
}

resource "aws_iam_role_policy_attachment" "lambda_backup" {
  count = var.enable_rds_ltr_backup ? 1 : 0

  role       = aws_iam_role.lambda_rds_backup[0].name
  policy_arn = aws_iam_policy.lambda_backup[0].arn
}

# Standard AWS-managed policy granting CloudWatch Logs write permissions
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  count = var.enable_rds_ltr_backup ? 1 : 0

  role       = aws_iam_role.lambda_rds_backup[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Permissions for the RDS export role: read/write/delete on the backup
# bucket, plus KMS access to encrypt/decrypt the exported snapshot data
resource "aws_iam_policy" "rds_export_policy" {
  count = var.enable_rds_ltr_backup ? 1 : 0

  name = "${var.app}-${var.env}-rds-snapshot-export-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetBucketLocation",
          "s3:ListAllMyBuckets",
          "s3:AbortMultipartUpload"
        ]
        Resource = [
          "${var.rds_backup_bucket_arn}",
          "${var.rds_backup_bucket_arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = var.data_storage_kms_key_arn
      }
    ]
  })

  tags = var.extended_tags
}

resource "aws_iam_role_policy_attachment" "rds_export" {
  count = var.enable_rds_ltr_backup ? 1 : 0

  role       = aws_iam_role.rds_export_role[0].name
  policy_arn = aws_iam_policy.rds_export_policy[0].arn
}