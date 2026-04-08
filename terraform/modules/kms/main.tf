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