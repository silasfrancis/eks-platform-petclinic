# VPC Flow Logs — IAM
#
# Role and policy allowing the VPC Flow Logs service to write log streams
# and events to the CloudWatch Log Group above. Only created when
# var.enable_flow_logs is true.

resource "aws_iam_role" "vpc_flow_logs" {
  count = var.enable_flow_logs ? 1 : 0

  name = "${var.vpc_name_prefix}-${var.env}-vpc-flow-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
  tags = var.extended_tags

}

resource "aws_iam_policy" "vpc_flow_log_policy" {
  count = var.enable_flow_logs ? 1 : 0

  name = "${var.vpc_name_prefix}-${var.env}-vpc-flow-log-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = "*"
      }
    ]
  })
  tags = var.extended_tags
}

resource "aws_iam_role_policy_attachment" "vpc_flow_logs_attach" {
  count = var.enable_flow_logs ? 1 : 0
  role       = aws_iam_role.vpc_flow_logs[0].name
  policy_arn = aws_iam_policy.vpc_flow_log_policy[0].arn
  depends_on = [ aws_iam_policy.vpc_flow_log_policy ]
}