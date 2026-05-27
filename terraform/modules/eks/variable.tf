variable "env" {
  type = string
}

variable "app" {
  type = string
}

variable "cluster_version" {
    type = string
    default = "1.35"
  
}

variable "vpc_id" {
  type = string
}

variable "private_subnets" {
  type = list(string)
}

variable "nlb_external_sg_id" {
    type = string
}

variable "nlb_internal_sg_id" {
    type = string
}

variable "wireguard_sg_id" {
  type = string
}

variable "eks_secrets_kms_key_arn" {
  type = string
}

variable "data_storage_kms_key_arn" {
  type = string
}

variable "infra_common_kms_key_arn" {
  type = string
}

variable "extended_tags" {
  description = "Additional resource tags passed from the parent environment"
  type        = map(string)
  default     = {}
}