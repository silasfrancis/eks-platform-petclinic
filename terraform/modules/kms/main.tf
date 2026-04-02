data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_iam_role" "kms_admin" {
  name = "kms-admin-role"
}

locals {
  kms_admin_statements = [
    {
      Sid    = "EnableIAMUserPermissions"
      Effect = "Allow"
      Principal = {
        AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
      }
      Action   = "kms:*"
      Resource = "*"
    },
    {
      Sid    = "AllowKeyAdministrators"
      Effect = "Allow"
      Principal = {
        AWS = data.aws_iam_role.kms_admin.arn
      }
      Action = [
        "kms:Create*",
        "kms:Describe*",
        "kms:Enable*",
        "kms:List*",
        "kms:Put*",
        "kms:Update*",
        "kms:Revoke*",
        "kms:Disable*",
        "kms:Get*",
        "kms:Delete*",
        "kms:TagResource",
        "kms:UntagResource",
        "kms:ScheduleKeyDeletion",
        "kms:CancelKeyDeletion",
        "kms:RotateKeyOnDemand"
      ]
      Resource = "*"
    },
    {
      Sid    = "AllowUseOfTheKey"
      Effect = "Allow"
      Principal = {
        AWS = data.aws_iam_role.kms_admin.arn
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
    {
      Sid    = "AllowAttachmentOfPersistentResources"
      Effect = "Allow"
      Principal = {
        AWS = data.aws_iam_role.kms_admin.arn
      }
      Action = [
        "kms:CreateGrant",
        "kms:ListGrants",
        "kms:RevokeGrant"
      ]
      Resource = "*"
      Condition = {
        Bool = { "kms:GrantIsForAWSResource" = "true" }
      }
    }
  ]
}

resource "aws_kms_key" "eks_secrets" {
  description             = "KMS Key for EKS Secret Encryption"
  bypass_policy_lockout_safety_check = true
  deletion_window_in_days = 30
  enable_key_rotation     = true

  policy = jsonencode({
    Id      = "key-eks-secrets"
    Version = "2012-10-17"
    Statement = concat(local.kms_admin_statements, [
      {
        Sid    = "AllowEKSService"
        Effect = "Allow"
        Principal = { Service = "eks.amazonaws.com" }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:CreateGrant",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
        Condition = {
          Bool = { "kms:GrantIsForAWSResource" = "true" }
        }
      }
    ])
  })
  tags = {
    resource = "kms"
  }
}

resource "aws_kms_key" "infra_logs" {
  description             = "KMS Key for CloudWatch Logs (EKS/VPC/RDS)"
  bypass_policy_lockout_safety_check = true
  deletion_window_in_days = 30
  enable_key_rotation     = true

  policy = jsonencode({
    Id      = "key-infra-logs"
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
      }
    ])
  })
  tags = {
    resource = "kms"
  }
}

resource "aws_kms_key" "rds_data" {
  description             = "KMS Key for RDS Storage Encryption"
  bypass_policy_lockout_safety_check = true
  deletion_window_in_days = 30
  enable_key_rotation     = true

  policy = jsonencode({
    Id      = "key-rds-data"
    Version = "2012-10-17"
    Statement = concat(local.kms_admin_statements, [
      {
        Sid    = "AllowRDSService"
        Effect = "Allow"
        Principal = { Service = "rds.amazonaws.com" }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:GenerateDataKey*",
          "kms:CreateGrant",
          "kms:DescribeKey"
        ]
        Resource = "*"
        Condition = {
          Bool = { "kms:GrantIsForAWSResource" = "true" }
        }
      }
    ])
  })
  tags = {
    resource = "kms"
  }
}

resource "aws_kms_key" "eks_nodes_ebs" {
  description             = "KMS Key for EKS Node EBS Encryption"
  bypass_policy_lockout_safety_check = true
  deletion_window_in_days = 30
  enable_key_rotation     = true

  policy = jsonencode({
    Id      = "key-eks-nodes-ebs"
    Version = "2012-10-17"
    Statement = concat(local.kms_admin_statements, [
      {
        Sid    = "AllowAutoScalingService"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling"
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
      {
        Sid    = "AllowAutoScalingGrant"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling"
        }
        Action = [
          "kms:CreateGrant"
        ]
        Resource = "*"
        Condition = {
          Bool = { "kms:GrantIsForAWSResource" = "true" }
        }
      }
    ])
  })
  tags = {
    resource = "kms"
  }
}
