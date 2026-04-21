output "cluster_name" {
  value = aws_eks_cluster.main_cluster.name
}

output "oidc_provider_url" {
  value = aws_eks_cluster.main_cluster.identity[0].oidc[0].issuer
}

output "oidc_url_stripped" {
  value = replace(aws_iam_openid_connect_provider.eks.url, "https://", "")
}

output "cluster_endpoint" {
  value = aws_eks_cluster.main_cluster.endpoint
}

output "cluster_ca_cert" {
  value = aws_eks_cluster.main_cluster.certificate_authority[0].data
}

output "oidc_arn" {
  value = aws_iam_openid_connect_provider.eks.arn
}

output "irsa_role_arns" {
  description = "Map of IRSA role names to their ARNs"
  value = {
    for k, v in aws_iam_role.irsa : k => v.arn
  }
}

output "karpenter_interruption_queue_name" {
  value = aws_sqs_queue.karpenter_interruption.name
}

output "karpenter_interruption_queue_arn" {
  value = aws_sqs_queue.karpenter_interruption.arn
}