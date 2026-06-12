# Infra Common KMS Key
#
# Used to encrypt general infrastructure resources: CloudWatch Log Groups,
# SNS topics, and other shared infra (e.g. VPC flow logs). Grants the
# CloudWatch Logs and SNS service principals the permissions needed to use
# the key for encryption within this account, in addition to the shared
# kms_admin_statements.

resource "aws_kms_key" "infra_common" {
  description             = "Common Infrastructure KMS Key (CloudWatch/SNS/VPC)"
  bypass_policy_lockout_safety_check = true
  deletion_window_in_days = 30
  enable_key_rotation     = true

  policy = jsonencode({
    Id      = "infra-common-key"
    Version = "2012-10-17"
    Statement = concat(local.kms_admin_statements, [
      # Allows CloudWatch Logs to encrypt/decrypt log data for log groups
      # using this key, scoped to this account
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
      # Allows SNS to generate/decrypt data keys for encrypting topic
      # messages, scoped to this account
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