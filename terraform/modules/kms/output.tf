output "kms_key_arn" {
  value = {
    cloudwatch_logs = aws_kms_key.cloudwatch_logs.arn
    data_storage = aws_kms_key.data_storage.arn
    eks_secrets = aws_kms_key.eks_secrets.arn
  }
}

output "kms_key_id" {
  value = {
    cloudwatch_logs = aws_kms_key.cloudwatch_logs.id
    data_storage = aws_kms_key.data_storage.id
    eks_secrets = aws_kms_key.eks_secrets.id
  }
}