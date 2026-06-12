# VPC Module
#
# Generic networking module reused across environments (prod, dev, wireguard).
# Builds a VPC with up to three subnet tiers (public, private, data), each
# tier sized 1-N AZs via *_subnet_count, plus NAT gateways, route tables,
# an IGW, optional flow logs, and a locked-down default security group.
#
# CIDR layout: each environment gets a /16 from vpc_cidrs based on var.env
# (falls back to prod's 10.0.0.0/16 if var.env doesn't match). Within that
# /16, subnets are carved as /24s using the second octet as an offset:
#   public  subnets -> .1.0/24  .. .N.0/24
#   private subnets -> .11.0/24 .. .(10+N).0/24
#   data    subnets -> .21.0/24 .. .(20+N).0/24
# This keeps each tier in its own predictable range and leaves room to grow.


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