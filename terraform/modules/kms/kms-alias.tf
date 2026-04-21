resource "aws_kms_alias" "data_storage" {
  name          = "alias/${var.env}-data-storage"
  target_key_id = aws_kms_key.data_storage.key_id
}

resource "aws_kms_alias" "infra_common" {
  name          = "alias/${var.env}-infra-common"
  target_key_id = aws_kms_key.infra_common.key_id
}

resource "aws_kms_alias" "eks_secrets" {
  name          = "alias/${var.env}-eks-secrets"
  target_key_id = aws_kms_key.eks_secrets.key_id
}