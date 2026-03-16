resource "aws_vpc" "main_vpc" {
cidr_block = "10.0.0.0/16"
tags = {
    "Name" = var.tags
}
  
}

data "aws_availability_zones" "available"{
    state = "available"
}