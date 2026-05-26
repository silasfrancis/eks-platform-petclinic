output "irsa_role_arns" {
  description = "Map of IRSA identifier to Role ARN"
  value       = { for k, v in aws_iam_role.irsa : k => v.arn }
}