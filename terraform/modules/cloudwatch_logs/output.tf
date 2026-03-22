output "logs_arn" {
  value = {
    eks_log_group_arn = aws_cloudwatch_log_group.eks_log_group.arn
    vpc_flow_log_group_arn = aws_cloudwatch_log_group.vpc_flow_log_group.arn
  }
}