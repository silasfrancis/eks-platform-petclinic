variable "env" {
  type = string
}

variable "instance_type" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "public_subnet_id" {
  type = string
}

variable "wireguard_server_security_group_id" {
  type = string
}

variable "rds_security_group_id" {
  type = string
}

variable "wireguard_server_instance_profile" {
  type = string
}

variable "app" {
  type = string
}

variable "platform_engineers_group_name" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "region" {
  type = string
}