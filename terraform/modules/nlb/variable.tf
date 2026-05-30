variable "app" {
  type = string
}

variable "env" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "wireguard_vpc_cidr" {
  type = string
}

variable "extended_tags" {
  description = "Additional resource tags passed from the parent environment"
  type        = map(string)
  default     = {}
}