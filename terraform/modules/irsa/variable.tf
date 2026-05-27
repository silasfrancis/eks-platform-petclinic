variable "oidc_arn" {
  type = string
}

variable "oidc_url" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "app_secrets_arn" {
  type = list(string)
}

variable "platform_monitoring_secrets_arn" {
  type = list(string)
}


variable "platform_dns_secrets_arn" {
  type = list(string)
}

variable "platform_security_secrets_arn" {
  type = list(string)
}

variable "argocd_secrets_arn" {
  type = list(string)
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
  type = list(string)
}

variable "extended_tags" {
  description = "Additional resource tags passed from the parent environment"
  type        = map(string)
  default     = {}
}