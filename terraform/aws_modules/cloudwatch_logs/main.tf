resource "aws_cloudwatch_log_group" "eks_log_group" {
  name              = "/aws/eks/${var.env}-eks-cluster/cluster"
  retention_in_days = 14
  kms_key_id        = var.kms_infra_logs_arn
  
  tags = {
    Name = var.env
    Resource = "EKS"
  }
}

resource "aws_cloudwatch_log_group" "vpc_flow_log_group" {
  name              = "/aws/vpc-flow-log/${var.env}-vpc"
  retention_in_days = 14
  kms_key_id        = var.kms_infra_logs_arn
  
  tags = {
    Name = var.env
    Resource = "VPC"
  }
}
