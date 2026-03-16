output "db_secrets" {
  value = {
    db_username = jsondecode(
      data.aws_secretsmanager_secret_version.db_secrets.secret_string
    )["MYSQL_USER"]

    db_password = jsondecode(
      data.aws_secretsmanager_secret_version.db_secrets.secret_string
    )["MYSQL_PASSWORD"]

    data_base = jsondecode(
      data.aws_secretsmanager_secret_version.db_secrets.secret_string
    )["MYSQL_DATABASE"]

  sensitive = true
  }
}