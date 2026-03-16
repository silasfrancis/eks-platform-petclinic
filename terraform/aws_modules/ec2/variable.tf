variable "tags" {
  type = string
}

variable "ami" {
  type = string
}

variable "instance_type" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_id" {
  type = string
}

variable "ec2_security_group_id" {
  type = list(string)
}

variable "iam_instance_profile" {
  type = string
}