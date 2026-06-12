# Data Storage KMS Key
#
# Shared key for encrypting data-at-rest across storage services: RDS
# (database storage), S3 (Loki, Velero, RDS backup buckets), and EBS volumes
# (via the AutoScaling service-linked role for EKS node volumes). Grants RDS,
# S3, and the AutoScaling service-linked role permission to use the key, plus
# grant management for the AutoScaling role, in addition to the shared
# kms_admin_statements.

resource "aws_kms_key" "data_storage" {
  description                        = "KMS Key for Storage Encryption"
  bypass_policy_lockout_safety_check = true
  deletion_window_in_days            = 30
  enable_key_rotation               = true

  policy = jsonencode({
    Id      = "key-storage-all"
    Version = "2012-10-17"
    Statement = concat(local.kms_admin_statements, [
      # General encrypt/decrypt usage for RDS, S3, and the EKS node
      # AutoScaling service-linked role (used for EBS volume encryption)
      {
        Sid    = "AllowGeneralUsage"
        Effect = "Allow"
        Principal = {
          Service = [
            "rds.amazonaws.com",
            "s3.amazonaws.com"
          ]
          AWS = [
            "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling"
          ]
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
      },
      # Allows the AutoScaling service-linked role to create/list grants,
      # needed to attach encrypted EBS volumes to EC2 instances launched by
      # the ASG (Karpenter-managed node groups)
      {
        Sid    = "AllowASGGrantPermissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling"
        }
        Action   = ["kms:CreateGrant", "kms:ListGrants"]
        Resource = "*"
        Condition = {
          Bool = { "kms:GrantIsForAWSResource" = "true" }
        }
      }
    ])
  })

  tags = merge(
    {
    scope    = "data-storage"
    },
    var.extended_tags
  )
}