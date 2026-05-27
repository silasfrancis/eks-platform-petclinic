variable "env" {
  type = string
}

variable "app" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "eks_node_sg_id" {
  type = string
}

variable "wireguard_sg_id" {
  type = string
}

variable "data_subnet_ids" {
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

variable "data_storage_kms_key_arn" {
  type = string
}

variable "extended_tags" {
  description = "Additional resource tags passed from the parent environment"
  type        = map(string)
  default     = {}
}