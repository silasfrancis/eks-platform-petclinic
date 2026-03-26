variable "env" {
  type = string
}

variable "k8_version" {
    type = string
    default = "1.35"
  
}

variable "cluster_role_arn" {
  type = string
}

variable "node_role_arn" {
  type = string
}

variable "subnet_ids_for_cluster" {
  type = list(string)
}

variable "subnet_ids_node_group" {
  type = list(string)
}

variable "node_scaling_config" {
    type = object({
      desired_size = number
      max_size = number
      min_size = number
    })
  
}

variable "eks_security_group_id" {
    type = string
}

variable "ami_type" {
    type = string
}

variable "disk_size" {
    type = string
  
}

variable "instance_types" {
    type = list(string)
  
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