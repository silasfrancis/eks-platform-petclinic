resource "aws_iam_role" "irsa_alb_controller" {
  name = "${var.env}-${var.app}-alb-controller"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = {
        Federated = var.oidc_arn
      }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${var.oidc_url}:sub" = "system:serviceaccount:${var.namespace}:${var.service_account_name}"
          "${var.oidc_url}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })
  tags = {
    resource = "iam"
  }
}