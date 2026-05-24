variable "env" {
  type = string
}

variable "public_subnet_id" {
  type = string
}

variable "wireguard_sg_id" {
  type = string
}

variable "wireguard_server_instance_profile" {
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
