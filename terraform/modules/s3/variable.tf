variable "env" {
  type = string
}

variable "app" {
  type = string
}

variable "data_storage_kms_key_arn" {
  type = string
}

variable "extended_tags" {
  description = "Additional resource tags passed from the parent environment"
  type        = map(string)
  default     = {}
}