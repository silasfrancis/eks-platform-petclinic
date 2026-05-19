variable "env" {
 type = string 
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