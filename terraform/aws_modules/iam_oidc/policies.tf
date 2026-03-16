resource "aws_iam_policy" "pod_read_secrets_policy" {
  name        = "${var.env}-pod-secrets-read"
  description = "Allows reading of a specific secret from AWS Secrets Manager for pods in EKS using OIDC authentication"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ]
      Resource = "arn:aws:secretsmanager:*:*:secret:${var.secret_name}*"
    }]
  })
}