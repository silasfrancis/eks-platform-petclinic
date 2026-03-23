resource "aws_cloudwatch_log_group" "eks_log_group" {
  name              = "/aws/eks/${var.env}-${var.app}/cluster"
  retention_in_days = 14
  kms_key_id        = var.kms_infra_logs_arn
  
  tags = {
    resource = "cloudwatch"
  }
}

resource "aws_cloudwatch_log_group" "vpc_flow_log_group" {
  name              = "/aws/vpc-flow-log/${var.env}-${var.app}"
  retention_in_days = 14
  kms_key_id        = var.kms_infra_logs_arn
  
  tags = {
    resource = "cloudwatch"
  }
}
