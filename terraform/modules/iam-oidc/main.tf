data "tls_certificate" "eks" {
  url = var.eks_oidc_provider_url
}

resource "aws_iam_openid_connect_provider" "eks" {
  url             = var.eks_oidc_provider_url 
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
}
