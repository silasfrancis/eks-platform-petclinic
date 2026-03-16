resource "aws_iam_role_policy_attachment" "vpc_flow_logs_attach" {
  role       = aws_iam_role.vpc_flow_logs_role.name
  policy_arn = aws_iam_policy.vpc_flow_log_policy.arn
  depends_on = [ aws_iam_policy.vpc_flow_log_policy ]
}