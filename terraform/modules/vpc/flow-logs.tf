# VPC Flow Logs
#
# Optional (var.enable_flow_logs) — logs ALL traffic for the VPC to a
# CloudWatch Log Group encrypted with the infra common KMS key, with a
# 3-day retention. Enabled in prod, disabled in dev to reduce cost/noise.


resource "aws_cloudwatch_log_group" "vpc_flow_log_group" {
  count = var.enable_flow_logs ? 1 : 0

  name              = "/aws/vpc-flow-log/${var.vpc_name_prefix}-${var.env}-main-vpc"
  retention_in_days = 3

  kms_key_id = var.infra_common_kms_key_arn

  tags = var.extended_tags
}

resource "aws_flow_log" "vpc_flow_log" {
  count = var.enable_flow_logs ? 1 : 0

  iam_role_arn = aws_iam_role.vpc_flow_logs[0].arn
  log_destination = aws_cloudwatch_log_group.vpc_flow_log_group[0].arn
  traffic_type = "ALL"
  vpc_id = aws_vpc.vpc.id
  tags = var.extended_tags
}