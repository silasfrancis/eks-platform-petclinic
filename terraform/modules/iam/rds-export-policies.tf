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
        Resource = var.data_storage_kms_key_arn
      }
    ]
  })
  tags = {
    resource = "iam"
  }
}
resource "aws_iam_role_policy_attachment" "rds_export" {
  role       = aws_iam_role.rds_export_role.name
  policy_arn = aws_iam_policy.rds_export_policy.arn
  depends_on = [ aws_iam_policy.rds_export_policy ]
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  role       = aws_iam_role.rds_enhanced_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}