variable "bucket_name" {
  type = string
}

variable "bucket_key" {
    type = string
  
}

variable "bucket_rule_id" {
  type = string
}

variable "bucket_exp_days" {
  type = number
  default = 60
}

variable "bucket_tag_name" {
  type = string
}

variable "env" {
  type = string
}
