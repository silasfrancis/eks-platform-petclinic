output "kms_key_arn" {
  value = {
    infra_logs = aws_kms_key.infra_logs.arn
    rds_data = aws_kms_key.rds_data.arn
    eks_secrets = aws_kms_key.eks_secrets.arn
    eks_nodes_ebs = aws_kms_key.eks_nodes_ebs.arn
  }
}

output "kms_key_id" {
  value = {
    infra_logs = aws_kms_key.infra_logs.id
    rds_data = aws_kms_key.rds_data.id
    eks_secrets = aws_kms_key.eks_secrets.id
    eks_nodes_ebs = aws_kms_key.eks_nodes_ebs.id
  }
}