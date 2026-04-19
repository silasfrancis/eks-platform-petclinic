variable "env" {
  type = string
}

variable "private_subnets" {
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
  type = string
}

variable "cluster_sg_id" {
  type = string
}

variable "ec2_security_group_id" {
  type = string
}

variable "rds_data_kms_arn" {
  type = string
}

variable "rds_monitoring_role_arn" {
  type = string
}

variable "app" {
  type = string
}