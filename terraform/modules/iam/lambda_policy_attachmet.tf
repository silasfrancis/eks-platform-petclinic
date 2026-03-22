resource "aws_iam_role_policy_attachment" "rds_export_lambda_attach" {
  role       = aws_iam_role.rds_export_lambda.name
  policy_arn = aws_iam_policy.rds_export_lambda.arn
  depends_on = [ aws_iam_policy.rds_export_lambda ]
}

resource "aws_iam_role_policy_attachment" "basic_exec_exporter" {
  role       = aws_iam_role.rds_export_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "basic_exec_notifier" {
  role       = aws_iam_role.slack_notifier_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}