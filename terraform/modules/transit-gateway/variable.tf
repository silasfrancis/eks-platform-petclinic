variable "wireguard_public_route_table_ids" {
  type = list(string)
}

variable "dev_private_route_table_ids" {
  type = list(string)
}

variable "prod_private_route_table_ids" {
  type = list(string)
}

variable "wireguard_vpc_id" {
  type = string
}

variable "dev_vpc_id" {
  type = string
}

variable "prod_vpc_id" {
  type = string
}

variable "wireguard_public_subnet_ids" {
  type = list(string)
}

variable "dev_private_subnet_ids" {
  type = list(string)
}

variable "prod_private_subnet_ids" {
  type = list(string)
}

variable "dev_vpc_cidr" {
  type = string
}

variable "prod_vpc_cidr" {
  type = string
}

variable "extended_tags" {
  description = "Additional resource tags passed from the parent environment"
  type        = map(string)
  default     = {}
}