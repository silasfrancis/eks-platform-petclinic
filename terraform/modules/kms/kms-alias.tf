resource "aws_kms_alias" "data_storage" {
  name          = "alias/${var.env}-data-storage"
  target_key_id = aws_kms_key.data_storage.key_id
}

resource "aws_kms_alias" "cloudwatch_logs" {
  name          = "alias/${var.env}-cloudwatch-logs"
  target_key_id = aws_kms_key.cloudwatch_logs.key_id
}

resource "aws_kms_alias" "eks_secrets" {
  name          = "alias/${var.env}-eks-secrets"
  target_key_id = aws_kms_key.eks_secrets.key_id
}