resource "aws_iam_policy" "read_secrets_policy" {
  name        = "${var.env}-${var.app}-jumphost-secrets-read"
  description = "Allows reading of a specific secret from AWS Secrets Manager for jumphosts"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = [
        "secretsmanager:GetSecretValue"
      ]
      Resource = "arn:aws:secretsmanager:*:*:secret:${var.secret_name}*"
    }]
  })
  tags = {
    resource = "iam"
  }
}

resource "aws_iam_policy" "rds_export_policy" {
  name = "${var.env}-${var.app}-rds-snapshot-export-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetBucketLocation",
          "s3:ListBucket",
          "s3:ListAllMyBuckets",
          "s3:GetObject",
          "s3:DeleteObject"
        ]
        Resource = [
          "${var.rds_export_bucket_arn}",
          "${var.rds_export_bucket_arn}/*"
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
        Resource = var.rds_export_kms_key_arn
      }
    ]
  })
  tags = {
    resource = "iam"
  }
}

resource "aws_iam_policy" "vpc_flow_log_policy" {
  name = "${var.env}-${var.app}-vpc-flow-log-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = "*"
      }
    ]
  })
  tags = {
    resource = "iam"
  }
}

resource "aws_iam_policy" "rds_export_lambda" {
  name = "${var.env}-${var.app}-rds-export-lambda-policy"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["rds:StartExportTask", "rds:DescribeExportTasks", "rds:DescribeDBSnapshots"]
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
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect   = "Allow"
        Action   = ["kms:GenerateDataKey*", "kms:Decrypt", "kms:DescribeKey"]
        Resource = var.rds_export_kms_key_arn
      }
    ]
  })
  tags = {
    resource = "iam"
  }
}