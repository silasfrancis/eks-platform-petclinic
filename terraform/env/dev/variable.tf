variable "aws_region" {
  type    = string
  default = "us-east-2"
}

variable "environment" {
  type = string
}

variable "app" {
  type = string
}

variable "global_remote_state_bucket" {
  type = string
}

variable "global_app_registry_remote_state_key" {
  type = string
}

variable "wireguard_server_remote_state_key" {
  type = string
}