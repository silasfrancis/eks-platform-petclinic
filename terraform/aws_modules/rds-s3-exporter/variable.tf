variable "env" {
  type = string
}

variable "db_instance_identifier" {
  type = string
}

variable "rds_export_bucket" {
  type = string
}

variable "rds_export_role_arn" {
  type = string
}

variable "rds_export_lambda_role_arn" {
  type = string
}

variable "rds_export_kms_key_arn" {
  type = string
}

variable "rds_export_kms_key_id" {
  type = string
}

variable "slack_webhook_url" {
  type = string
  sensitive = true
}

variable "slack_notify_lambda_role_arn" {
  type = string
}

variable "application" {
  type = string
}