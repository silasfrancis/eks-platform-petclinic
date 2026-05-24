variable "aws_region" {
  type    = string
  default = "us-east-2"
}

variable "environment" {
  type = string
}

variable "prod_remote_state_bucket" {
  type        = string
  description = "The name of the prod S3 state bucket"
}

variable "prod_remote_state_key" {
  type        = string
  description = "The key for the prod remote state file in S3"
}

variable "dev_remote_state_bucket" {
  type        = string
  description = "The name of the dev S3 state bucket"
}

variable "dev_remote_state_key" {
  type        = string
  description = "The key for the dev remote state file in S3"
}