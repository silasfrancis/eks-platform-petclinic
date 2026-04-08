resource "aws_kms_key" "data_storage" {
  description             = "KMS Key for Storage Encryption"
  bypass_policy_lockout_safety_check = true
  deletion_window_in_days = 30
  enable_key_rotation     = true

  policy = jsonencode({
    Id      = "key-storage-all"
    Version = "2012-10-17"
    Statement = concat(local.kms_admin_statements, [
     {
      Sid    = "AllowDataStorageServices"
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
        "kms:DescribeKey",
        "kms:CreateGrant",
        "kms:ListGrants"
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
