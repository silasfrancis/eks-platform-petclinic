resource "aws_kms_alias" "rds_data" {
  name          = "alias/${var.env}-rds-data"
  target_key_id = aws_kms_key.rds_data.key_id
}

resource "aws_kms_alias" "infra_logs" {
  name          = "alias/${var.env}-infra-logs"
  target_key_id = aws_kms_key.infra_logs.key_id
}

resource "aws_kms_alias" "eks_secrets" {
  name          = "alias/${var.env}-eks-secrets"
  target_key_id = aws_kms_key.eks_secrets.key_id
}