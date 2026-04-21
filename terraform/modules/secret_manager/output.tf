output "secret_arns" {
  description = "ARNs of all platform secrets"
  value = {
    argocd     = data.aws_secretsmanager_secret.secrets["argocd"].arn
    petclinic  = data.aws_secretsmanager_secret.secrets["petclinic"].arn
    monitoring = data.aws_secretsmanager_secret.secrets["monitoring"].arn
    dns        = data.aws_secretsmanager_secret.secrets["dns"].arn
  }
}

output "secret_names" {
  description = "Names of all platform secrets"
  value = {
    argocd     = data.aws_secretsmanager_secret.secrets["argocd"].name
    petclinic  = data.aws_secretsmanager_secret.secrets["petclinic"].name
    monitoring = data.aws_secretsmanager_secret.secrets["monitoring"].name
    dns        = data.aws_secretsmanager_secret.secrets["dns"].name
  }
}

output "db_credentials" {
  description = "RDS credentials decoded from petclinic secret — passed to RDS module"
  sensitive   = true
  value = {
    username = jsondecode(
      data.aws_secretsmanager_secret_version.secrets["petclinic"].secret_string
    )["mysql_user"]

    password = jsondecode(
      data.aws_secretsmanager_secret_version.secrets["petclinic"].secret_string
    )["mysql_password"]

    database = jsondecode(
      data.aws_secretsmanager_secret_version.secrets["petclinic"].secret_string
    )["mysql_database"]
  }
}

output "slack_webhook_url" {
  description = "Slack webhook URL for RDS export failure Lambda alerts"
  sensitive   = true
  value = jsondecode(
    data.aws_secretsmanager_secret_version.secrets["monitoring"].secret_string
  )["aws-alerts-slack-webhook-url"]
}