resource "aws_kms_key" "infra_common" {
  description             = "Common Infrastructure KMS Key (CloudWatch/SNS/VPC)"
  bypass_policy_lockout_safety_check = true
  deletion_window_in_days = 30
  enable_key_rotation     = true

  policy = jsonencode({
    Id      = "infra-common-key"
    Version = "2012-10-17"
    Statement = concat(local.kms_admin_statements, [
      {
        Sid    = "AllowCloudWatchLogsService"
        Effect = "Allow"
        Principal = { Service = "logs.${data.aws_region.current.id}.amazonaws.com" }
        Action = [
          "kms:Encrypt*",
          "kms:Decrypt*",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:Describe*"
        ]
        Resource = "*"
        Condition = {
          StringEquals = { "aws:SourceAccount" = data.aws_caller_identity.current.account_id }
        }
      },
      {
        Sid    = "AllowSNSService"
        Effect = "Allow"
        Principal = { Service = "sns.amazonaws.com" }
        Action = [
          "kms:GenerateDataKey*",
          "kms:Decrypt"
        ]
        Resource = "*"
        Condition = {
          StringEquals = { "aws:SourceAccount" = data.aws_caller_identity.current.account_id }
        }
      }
    ])
  })

  tags = merge(
    {
    scope    = "common-infra"
    },
    var.extended_tags
  )
}