# KMS Admin Policy Statements
#
# Shared IAM policy statements appended to every KMS key's key policy in this
# module. Grants full key management to the account root (required by AWS)
# and to a dedicated "kms-admin-role" for day-to-day key administration,
# usage, and grant management. Referenced via local.kms_admin_statements and
# combined with key-specific statements (e.g. service principals)

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# IAM role designated as the administrator for all KMS keys created here
data "aws_iam_role" "kms_admin" {
  name = "kms-admin-role"
}

locals {
  kms_admin_statements = [
    # Required by AWS: the account root must always retain full KMS permissions,
    # otherwise the key policy can lock everyone out
    {
      Sid    = "EnableIAMUserPermissions"
      Effect = "Allow"
      Principal = {
        AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
      }
      Action   = "kms:*"
      Resource = "*"
    },
    # Full administrative access (create, manage, rotate, delete) for the
    # kms-admin-role
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
    # Allows kms-admin-role to use the key directly for encrypt/decrypt
    # operations (e.g. for debugging/testing)
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
    # Allows kms-admin-role to manage grants for AWS-managed resources
    # (e.g. service-linked roles needing temporary key access)
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