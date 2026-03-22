output "eks_oidc_provider_url" {
  value = aws_eks_cluster.main_cluster.identity[0].oidc[0].issuer
}