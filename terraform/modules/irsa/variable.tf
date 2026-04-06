variable "env" {
  type = string
}

variable "app" {
  type = string
}

variable "oidc_arn" {
  type = string
}

variable "oidc_url" {
  type = string
}


variable "secret_name" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "application_namespace" {
  type = string
}

variable "application_service_account_name" {
  type = string
}

variable "monitoring_namespace" {
  type = string
}

variable "cloudwatch_exporter_service_account_name" {
  type = string
}