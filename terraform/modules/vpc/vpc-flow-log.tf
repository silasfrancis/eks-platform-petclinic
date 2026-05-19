resource "aws_cloudwatch_log_group" "vpc_flow_log_group" {
  name              = "/aws/vpc-flow-log/${var.env}-${var.app}-main-vpc"
  retention_in_days = 3
  kms_key_id        = var.infra_common_kms_key_arn
  
  tags = {
    resource = "cloudwatch"
  }
}


resource "aws_flow_log" "main_vpc_flow_log" {
  iam_role_arn    = aws_iam_role.vpc_flow_logs.arn
  log_destination = aws_cloudwatch_log_group.vpc_flow_log_group.arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.main_vpc.id
  tags = {
    resource = "vpc"
  }
}