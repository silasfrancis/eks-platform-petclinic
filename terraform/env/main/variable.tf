variable "aws_region" {
  type = string
  default = "us-east-2"
}

variable "environment" {
  type = string
  default = "dev"
}

variable "app" {
  type = string
  default = "petclinic"
}

variable "application_tag" {
  type = string
  default = "petclinic-dev"
}

variable "app_namespace" {
  type = string
  default = "petclinic"
}

variable "alb_controller_namespace" {
  type = string
  default = "kube-system"
}

variable "appregistry_application_tag" {
  type    = string
  default = ""
}