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