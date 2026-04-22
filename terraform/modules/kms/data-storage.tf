locals {
  karpenter_irsa_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.env}-${var.app}-cluster-karpenter-irsa"
  node_role_arn      = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.env}-${var.app}-node-role"
  velero_irsa_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.env}-${var.app}-cluster-velero-irsa"
  loki_irsa_arn   = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.env}-${var.app}-cluster-loki-irsa"
}
resource "aws_kms_key" "data_storage" {
  description                        = "KMS Key for Storage Encryption"
  bypass_policy_lockout_safety_check = true
  deletion_window_in_days            = 30
  enable_key_rotation               = true

  policy = jsonencode({
    Id      = "key-storage-all"
    Version = "2012-10-17"
    Statement = concat(local.kms_admin_statements, [
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
      },
      {
        Sid    = "AllowKarpenterToUseKey"
        Effect = "Allow"
        Principal = {
          AWS = "${local.karpenter_irsa_arn}"
        }
        Action = [
          "kms:CreateGrant",
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:GenerateDataKeyWithoutPlaintext",
          "kms:ReEncrypt*"
        ]
        Resource = "*"
        Condition = {
          Bool = { "kms:GrantIsForAWSResource" = "true" }
        }
      },
      {
        Sid    = "AllowNodeRoleToUseKey"
        Effect = "Allow"
        Principal = {
          AWS =  "${local.node_role_arn}"
        }
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:GenerateDataKeyWithoutPlaintext",
          "kms:ReEncrypt*",
          "kms:CreateGrant"
        ]
        Resource = "*"
        Condition = {
          Bool = { "kms:GrantIsForAWSResource" = "true" }
        }
    },
    {
      Sid    = "AllowVeleroAndLokiToUseKey"
      Effect = "Allow"
      Principal = {
        AWS = [
          local.velero_irsa_arn,
          local.loki_irsa_arn 
        ]
      }
      Action = [
        "kms:GenerateDataKey",
        "kms:Decrypt",
        "kms:DescribeKey"
      ]
      Resource = "*"
    }
    ])
  })

  tags = {
    resource = "kms"
  }
}