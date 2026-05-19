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

variable "cluster_role_arn" {
  type = string
}

variable "node_role_arn" {
  type = string
}

variable "private_subnets" {
  type = list(string)
}

variable "eks_node_sg_id" {
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

variable "wireguard_server_security_group_id" {
  type = string
}

variable "nlb_external_security_group_id" {
  type = string
}

