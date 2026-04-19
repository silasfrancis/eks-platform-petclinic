variable "env" {
  type = string
}

variable "oidc_arn" {
  type = string
}

variable "oidc_url" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "app_secret_name" {
  type = string
}

variable "cluster_config_secret_name" {
  type = string
}

variable "loki_bucket_arn" {
  type = string
}

variable "data_storage_kms_key_arn" {
  type = string
}

variable "velero_bucket_arn" {
  type = string
}

variable "route53_private_zone_arn" {
  type = string
}

variable "platform_ingress_secret_name" {
  type = string
}

variable "platform_security_secret_name" {
  type = string
}

variable "argocd_secret_name" {
  type = string
}
