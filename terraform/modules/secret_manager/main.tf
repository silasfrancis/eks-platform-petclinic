# Secrets Manager Lookups
#
# Reads pre-created secrets from AWS Secrets Manager for ArgoCD, Petclinic
# app credentials, platform monitoring, and platform DNS. Secrets must exist
# in Secrets Manager (under <env>/<name>) before terraform apply — this module
# only reads them and exposes their values/ARNs as outputs for use by IRSA,
# RDS, and other modules.
#
# To add another secret: add an entry to secret_paths with the path it lives
# at in Secrets Manager (<env>/<name>), and reference it via
# data.aws_secretsmanager_secret_version.secrets["<key>"] in outputs.tf.

locals {
  secret_paths = {
    argocd     = "${var.env}/argocd"
    petclinic  = "${var.env}/petclinic"
    monitoring = "${var.env}/platform-monitoring"
    dns        = "${var.env}/platform-dns"
  }
}

# Looks up each secret by name/path
data "aws_secretsmanager_secret" "secrets" {
  for_each = local.secret_paths
  name     = each.value
}

# Fetches the current value of each secret
data "aws_secretsmanager_secret_version" "secrets" {
  for_each  = data.aws_secretsmanager_secret.secrets
  secret_id = each.value.id
}