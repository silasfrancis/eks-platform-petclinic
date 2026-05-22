resource "aws_cloudwatch_log_group" "eks_log_group" {
  name              = "/aws/eks/${var.app}-${var.env}-eks-cluster/cluster"
  retention_in_days = 3
  kms_key_id        = var.infra_common_kms_key_arn
  
  tags = {
    resource = "cloudwatch"
  }
}
