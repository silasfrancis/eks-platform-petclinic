output "kms_key_arn" {
  value = {
    infra_logs = aws_kms_key.infra_logs.arn
    rds_data = aws_kms_key.rds_data.arn
    eks_secrets = aws_kms_key.eks_secrets.arn
    eks_nodes_ebs = aws_kms_key.eks_nodes_ebs.arn
  }
}