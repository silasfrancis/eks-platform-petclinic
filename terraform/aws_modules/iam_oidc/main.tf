data "tls_certificate" "eks" {
  url = var.eks_oidc_provider_url
}

resource "aws_iam_openid_connect_provider" "eks" {
  url             = var.eks_oidc_provider_url 
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
}

locals {
  oidc_url_stripped = replace(aws_iam_openid_connect_provider.eks.url, "https://", "")
}


resource "aws_iam_role" "pod_secrets_reader" {
  name = "${var.env}-${var.service_account_name}-pod-secrets-reader"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.eks.arn
      }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${local.oidc_url_stripped}:sub" = "system:serviceaccount:${var.namespace}:${var.service_account_name}"
          "${local.oidc_url_stripped}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })
  tags = {
    env = var.env
    app = var.application
  }
}