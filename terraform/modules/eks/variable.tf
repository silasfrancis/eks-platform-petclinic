variable "env" {
  type = string
}

variable "cluster_version" {
    type = string
    default = "1.35"
  
}

variable "cluster_role_arn" {
  type = string
}

variable "node_role_arn" {
  type = string
}

variable "private_subnets" {
  type = list(string)
}

variable "eks_node_sg_id" {
    type = string
}

variable "ami_type" {
    type = string
}

variable "disk_size" {
    type = string
  
}

variable "instance_type" {
    type = string
  
}

variable "kms_eks_secrets_arn" {
  type = string
}

variable "kms_eks_nodes_ebs_arn" {
  type = string
}

variable "app" {
  type = string
}

variable "jumphost_ec2_role_arn" {
  type = string
}

variable "ec2_security_group_id" {
  type = string
}

variable "nlb_security_group_id" {
  type = string
}

variable "app" {
  type = string
}

