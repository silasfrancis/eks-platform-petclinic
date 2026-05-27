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
  description = "KMS key ARN for encrypting common infrastructure resources (e.g. VPC flow logs) not required for dev or wireguard vpc's"
  type = string
  default     = null
}

variable "availability_zones" {
  type = list(string)
}

variable "extended_tags" {
  description = "Additional resource tags passed from the parent environment"
  type        = map(string)
  default     = {}
}