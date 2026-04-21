output "kms_key_arn" {
  value = {
    infra_common = aws_kms_key.infra_common.arn
    data_storage = aws_kms_key.data_storage.arn
    eks_secrets = aws_kms_key.eks_secrets.arn
  }
}

output "kms_key_id" {
  value = {
    infra_common = aws_kms_key.infra_common.id
    data_storage = aws_kms_key.data_storage.id
    eks_secrets = aws_kms_key.eks_secrets.id
  }
}