variable "tags" {
  type = string
}

variable "env" {
  type = string
}

variable "secret_name"{
  type = string
}

variable "rds_export_bucket_arn" {
  type = string
}

variable "rds_export_kms_key_arn" {
  type = string
}

variable "application" {
  type = string
}