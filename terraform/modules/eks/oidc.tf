data "tls_certificate" "eks" {
  url = aws_eks_cluster.main_cluster.identity[0].oidc[0].issuer
  depends_on = [ aws_eks_cluster.main_cluster ]
}

resource "aws_iam_openid_connect_provider" "eks" {
  url             = aws_eks_cluster.main_cluster.identity[0].oidc[0].issuer
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  depends_on = [ data.tls_certificate.eks ]
}
