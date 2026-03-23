output "oidc_url_stripped" {
  value = replace(aws_iam_openid_connect_provider.eks.url, "https://", "")
}

output "oidc_arn" {
  value = aws_iam_openid_connect_provider.eks.arn
}