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
