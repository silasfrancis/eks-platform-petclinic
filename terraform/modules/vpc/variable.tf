variable "env" {
 type = string 
}

variable "vpc_name_prefix" {
  type = string
}

variable "public_subnet_count" {
  type = number
}

variable "private_subnet_count" {
  type = number
}

variable "data_subnet_count" {
  type = number
}

variable "nat_gateway_count" {
  type = number
}

variable "enable_flow_logs" {
  type = bool
}

variable "infra_common_kms_key_arn" {
  type = string
}

variable "vpc_flow_log_role_arn" {
  type = string
}

variable "vpc_flow_log_destination" {
  type = string
}

variable "app" {
  type = string
}

variable "availability_zones" {
  type = list(string)
}

variable "extended_tags" {
  description = "Additional resource tags passed from the parent environment"
  type        = map(string)
  default     = {}
}