resource "aws_iam_policy" "rds_export_lambda" {
  name = "${var.env}-${var.app}-rds-export-lambda-policy"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["rds:StartExportTask", "rds:DescribeExportTasks", "rds:DescribeDBSnapshots"]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = "iam:PassRole"
        Resource = aws_iam_role.rds_export_role.arn
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect   = "Allow"
        Action   = ["kms:GenerateDataKey*", "kms:Decrypt", "kms:DescribeKey"]
        Resource = var.rds_export_kms_key_arn
      }
    ]
  })
  tags = {
    resource = "iam"
  }
}

resource "aws_iam_role_policy_attachment" "rds_export_lambda_policy" {
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