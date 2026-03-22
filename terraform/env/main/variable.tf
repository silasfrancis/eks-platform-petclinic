variable "region" {
  type = string
  default = "us-east-2"
}

variable "environment" {
  type = string
  default = "main"
}

variable "app" {
  type = string
  default = "petclinic"
}

variable "application_tag" {
  type = string
  default = "petclinic-main"
}

variable "eks_namespace" {
  type = string
  default = "petclinic"
}

variable "slack_webhook_url" {
  type = string
}

variable "appregistry_application_tag" {
  type    = string
  default = ""
}