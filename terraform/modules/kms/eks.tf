# EKS Secrets KMS Key
#
# Used for envelope encryption of Kubernetes Secrets at the etcd layer
# (configured via the EKS cluster's encryption_config). Grants the EKS
# service principal permission to use the key, restricted to AWS-resource
# grants only, in addition to the shared kms_admin_statements.

resource "aws_kms_key" "eks_secrets" {
  description             = "KMS Key for EKS Secret Encryption"
  bypass_policy_lockout_safety_check = true
  deletion_window_in_days = 30
  enable_key_rotation     = true

  policy = jsonencode({
    Id      = "key-eks-secrets"
    Version = "2012-10-17"
    Statement = concat(local.kms_admin_statements, [
      # Allows the EKS service to encrypt/decrypt Kubernetes Secrets stored
      # in etcd using this key
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
  tags = merge(
    {
    scope    = "eks-secrets"
    },
    var.extended_tags
  )
}