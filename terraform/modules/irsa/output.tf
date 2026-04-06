
output "cloudwatch_exporter_role_arn" {
  value = module.cloudwatch_exporter_irsa.iam_role_arn
}