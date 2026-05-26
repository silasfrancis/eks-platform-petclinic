variable "app" {
  type = string
}

variable "env" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "enable_wireguard" {
  description = "Whether to create WireGuard SG and rules (prod only)"
  type        = bool
  default     = false
}

variable "extended_tags" {
  description = "Additional resource tags passed from the parent environment"
  type        = map(string)
  default     = {}
}