variable "env" {
  type = string
}

variable "db_instance_identifier" {
  type = string
}

variable "rds_backup_bucket" {
  type = string
}

variable "infra_common_kms_key_arn" {
  type = string
}

variable "data_storage_kms_key_arn" {
  type = string
}

variable "rds_backup_bucket_arn" {
  type = string
}

variable "slack_webhook" {
  type = string
  sensitive = true
}

variable "app" {
  type = string
}

variable "extended_tags" {
  description = "Additional resource tags passed from the parent environment"
  type        = map(string)
  default     = {}
}