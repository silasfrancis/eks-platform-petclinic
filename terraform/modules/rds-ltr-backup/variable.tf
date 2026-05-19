variable "env" {
  type = string
}

variable "db_instance_identifier" {
  type = string
}

variable "rds_export_bucket" {
  type = string
}

variable "infra_common_kms_key_arn" {
  type = string
}

variable "data_storage_kms_key_arn" {
  type = string
}

variable "rds_export_bucket_arn" {
  type = string
}

variable "slack_webhook" {
  type = string
  sensitive = true
}

variable "app" {
  type = string
}