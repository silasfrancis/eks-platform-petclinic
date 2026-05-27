resource "aws_iam_role" "lambda_rds_backup" {
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

resource "aws_iam_role" "rds_export_role" {
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

resource "aws_iam_policy" "lambda_backup" {
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
        Resource = aws_iam_role.rds_export_role.arn
      },

      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = aws_sqs_queue.main.arn
      }
    ]
  })

  tags = var.extended_tags

}

resource "aws_iam_role_policy_attachment" "lambda_backup" {
  role       = aws_iam_role.lambda_backup.name
  policy_arn = aws_iam_policy.lambda_backup.arn

  depends_on = [
    aws_iam_policy.lambda_backup
  ]
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_backup.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_policy" "rds_export_policy" {
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
  role       = aws_iam_role.rds_export_role.name
  policy_arn = aws_iam_policy.rds_export_policy.arn

  depends_on = [
    aws_iam_policy.rds_export_policy
  ]
}