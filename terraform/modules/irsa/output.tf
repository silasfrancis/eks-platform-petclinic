output "irsa_role_arns" {
  description = "Map of IRSA identifier to Role ARN"
  value       = { for k, v in aws_iam_role.irsa : k => v.arn }
}

output "alb_controller_irsa_role_arn" {
  value = aws_iam_role.alb_controller_irsa.arn
}