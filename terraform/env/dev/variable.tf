variable "region" {
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