resource "aws_iam_policy" "read_secrets_policy" {
  name        = "${var.env}-jumphost-secrets-read"
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
}

resource "aws_iam_policy" "rds_export_policy" {
  name = "${var.env}-rds-snapshot-export-policy"

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
      }
    ]
  })
}

resource "aws_iam_policy" "vpc_flow_log_policy" {
  name = "${var.env}-vpc-flow-log-policy"

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
}