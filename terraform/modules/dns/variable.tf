variable "vpc_id" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "extended_tags" {
  description = "Additional resource tags passed from the parent environment"
  type        = map(string)
  default     = {}
}