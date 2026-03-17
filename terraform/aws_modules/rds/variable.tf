variable "env" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "mysql_version" {
  type = string
}

variable "db_instance_class" {
  type = string
}

variable "allocated_storage" {
  type = number
}

variable "db_name" {
  type = string
}

variable "db_username" {
  type = string
}

variable "db_password" {
  type = string
}

variable "rds_security_group_id" {
  type = list(string)
}

variable "rds_data_kms_arn" {
  type = string
}

variable "rds_monitoring_role_arn" {
  type = string
}

variable "rds_export_role_arn" {
  type = string
}

variable "rds_export_s3_bucket" {
  type = string
}

variable "rds_export_kms_key_arn" {
  type = string
}

# variable "run_snapshot_export" {
#   type    = bool
#   default = false
# }