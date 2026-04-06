resource "aws_iam_role" "cloudwatch_exporter" {
  name = "${var.cluster_name}-cloudwatch-exporter"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = var.oidc_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${var.oidc_url}:sub" = "system:serviceaccount:${var.monitoring_namespace}:${var.cloudwatch_exporter_service_account_name}"
            "${var.oidc_url}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })
}

resource "aws_iam_policy" "cloudwatch_exporter" {
  name        = "${var.cluster_name}-cloudwatch-exporter"
  description = "CloudWatch read access for Prometheus exporter"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:GetMetricData",
          "cloudwatch:GetMetricStatistics",
          "cloudwatch:ListMetrics",
          "tag:GetResources"         
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "cloudwatch_exporter" {
  role       = aws_iam_role.cloudwatch_exporter.name
  policy_arn = aws_iam_policy.cloudwatch_exporter.arn
}