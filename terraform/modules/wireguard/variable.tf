variable "env" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "public_subnet_id" {
  type = string
}

variable "wireguard_sg_id" {
  type = string
}

variable "app" {
  type = string
}

variable "data_storage_kms_key_arn" {
  type = string
}

variable "platform_engineers_group_name" {
  type = string
}

variable "extended_tags" {
  description = "Additional resource tags passed from the parent environment"
  type        = map(string)
  default     = {}
}