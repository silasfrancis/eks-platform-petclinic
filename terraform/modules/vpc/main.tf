locals {
  # VPC CIDR blocks for each environment
  vpc_cidrs = {
    dev       = "10.1.0.0/16"
    prod      = "10.0.0.0/16"
    wireguard = "10.2.0.0/16"
  }

  # Look up the current env's CIDR. Fall back to prod (10.0.0.0/16) if not found.
  chosen_cidr = lookup(local.vpc_cidrs, var.env, "10.0.0.0/16")

  # Split the chosen CIDR to get the first two octets (e.g., "10.1" or "10.0")
  network_prefix = join(".", slice(split(".", local.chosen_cidr), 0, 2))
  
  # AZ selection
  public_azs  = slice(var.availability_zones, 0, var.public_subnet_count)
  private_azs = slice(var.availability_zones, 0, var.private_subnet_count)
  data_azs    = slice(var.availability_zones, 0, var.data_subnet_count)
  nat_azs     = slice(var.availability_zones, 0, var.nat_gateway_count)
}

resource "aws_vpc" "vpc" {
  cidr_block = local.chosen_cidr

  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(
    {
      Name = "${var.vpc_name_prefix}-${var.env}"
    },
    var.extended_tags
  )
}
