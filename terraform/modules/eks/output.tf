output "oidc_provider_url" {
  value = aws_eks_cluster.main_cluster.identity[0].oidc[0].issuer
}

output "cluster_sg_id" {
  value = aws_eks_cluster.main_cluster.vpc_config[0].cluster_security_group_id
}