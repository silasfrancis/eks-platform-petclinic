output "db_secrets" {
  value = {
    db_username = jsondecode(
      data.aws_secretsmanager_secret_version.secrets.secret_string
    )["MYSQL_USER"]

    db_password = jsondecode(
      data.aws_secretsmanager_secret_version.secrets.secret_string
    )["MYSQL_PASSWORD"]

    data_base = jsondecode(
      data.aws_secretsmanager_secret_version.secrets.secret_string
    )["MYSQL_DATABASE"]

    slack_aws_alert_webhook_url = jsondecode(
      data.aws_secretsmanager_secret_version.secrets.secret_string
    )["SLACK_AWS_ALERT_WEBHOOK_URL"]

  sensitive = true
  }
}

output "slack_secrets" {
  value = {
    slack_aws_alert_webhook_url = jsondecode(
      data.aws_secretsmanager_secret_version.secrets.secret_string
    )["SLACK_AWS_ALERT_WEBHOOK_URL"]

  sensitive = true
  }
}

output "secret_name" {
  value = data.aws_secretsmanager_secret.secret.name
}