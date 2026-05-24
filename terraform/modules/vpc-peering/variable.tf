variable "name" {
  type = string
}

variable "requester_vpc_id" {
  type = string
}

variable "accepter_vpc_id" {
  type = string
}

variable "requester_vpc_cidr" {
  type = string
}

variable "accepter_vpc_cidr" {
  type = string
}

variable "requester_route_table_ids" {
  type = list(string)
}

variable "accepter_route_table_ids" {
  type = list(string)
}