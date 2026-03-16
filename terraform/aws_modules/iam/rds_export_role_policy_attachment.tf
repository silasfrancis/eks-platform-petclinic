resource "aws_iam_role_policy_attachment" "rds_export_attach" {
  role       = aws_iam_role.rds_export_role.name
  policy_arn = aws_iam_policy.rds_export_policy.arn
  depends_on = [ aws_iam_policy.rds_export_policy ]
}