variable "aws_region" {
  type = string
  default = "us-east-2"
}

variable "environment" {
  type = string
}

variable "app" {
  type = string
}

variable "application_tag" {
  type = string
}

variable "appregistry_application_tag" {
  type    = string
  default = ""
}