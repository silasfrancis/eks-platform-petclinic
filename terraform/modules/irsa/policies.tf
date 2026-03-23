resource "aws_iam_policy" "irsa_secrets_policy" {
  name        = "${var.env}-${var.app}-${var.service_account_name}-pod-secrets-read"
  description = "Allows reading of a specific secret from AWS Secrets Manager by service accounts in EKS using OIDC authentication"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret",
        "secretsmanager:GetResourcePolicy",
        "secretsmanager:ListSecretVersionIds"
      ]
      Resource = "arn:aws:secretsmanager:*:*:secret:${var.secret_name}*"
    }]
  })
  tags = {
    resource = "iam"
  }
}