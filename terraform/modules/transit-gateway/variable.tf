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

variable "wireguard_vpc_cidr" {
  type = string
}

variable "wireguard_client_cidr" {
  description = "CIDR block assigned to WireGuard VPN clients on the wg0 interface"
  type        = string
  default     = "10.2.2.0/24"
}

variable "extended_tags" {
  description = "Additional resource tags passed from the parent environment"
  type        = map(string)
  default     = {}
}