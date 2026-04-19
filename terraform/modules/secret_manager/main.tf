locals {
  secret_paths = {
    argocd     = "${var.env}/argocd"
    petclinic  = "${var.env}/petclinic"
    monitoring = "${var.env}/platform-monitoring"
    dns        = "${var.env}/platform-dns"
  }
}

data "aws_secretsmanager_secret" "secrets" {
  for_each = local.secret_paths
  name     = each.value
}

data "aws_secretsmanager_secret_version" "secrets" {
  for_each  = local.secret_paths
  secret_id = data.aws_secretsmanager_secret.secrets[each.key].id
}
