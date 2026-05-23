locals {
  # VPC CIDR blocks for each environment
  vpc_cidrs = {
    dev  = "10.1.0.0/16"
    prod = "10.0.0.0/16"
  }

  # Look up the current env's CIDR. Fall back to prod (10.0.0.0/16) if not found.
  chosen_cidr = lookup(local.vpc_cidrs, var.env, "10.0.0.0/16")

  # Split the chosen CIDR to get the first two octets (e.g., "10.1" or "10.0")
  network_prefix = join(".", slice(split(".", local.chosen_cidr), 0, 2))
  
  # First 2 availability zones for subnets 
  target_azs     = slice(var.availability_zones, 0, 2)
}

resource "aws_vpc" "main_vpc" {
  cidr_block = local.chosen_cidr

  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name     = "${var.app}-${var.env}-main-vpc"
    resource = "vpc"
  }
}