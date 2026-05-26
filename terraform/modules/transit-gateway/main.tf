# TRANSIT GATEWAY
#
# Central router connecting three VPCs:
#   wireguard (10.2.0.0/16) — VPN entry point
#   dev       (10.1.0.0/16) — dev EKS cluster
#   prod      (10.0.0.0/16) — prod EKS cluster
#
# Isolation model:
#   wireguard → dev    allowed
#   wireguard → prod   allowed
#   dev       → prod   blocked (explicit black-hole)
#   prod      → dev    blocked (explicit black-hole)
#
# Default TGW route tables are disabled and all routing is explicit.

locals {
  # Configuration map to drive loops dynamically.
  # To add new spoke environments (e.g., staging), simply append a new entry block here.
  spoke_environments = {
    dev = {
      vpc_id          = var.dev_vpc_id
      subnet_ids      = var.dev_private_subnet_ids
      vpc_cidr        = var.dev_vpc_cidr
      route_table_ids = var.dev_private_route_table_ids
      blackhole_cidrs = [var.prod_vpc_cidr]
    }
    prod = {
      vpc_id          = var.prod_vpc_id
      subnet_ids      = var.prod_private_subnet_ids
      vpc_cidr        = var.prod_vpc_cidr
      route_table_ids = var.prod_private_route_table_ids
      blackhole_cidrs = [var.dev_vpc_cidr]
    }
  }

  # Flattens all variable input arrays into a unified collection of VPC route table targets
  all_vpc_route_tables = concat(
    var.wireguard_public_route_table_ids,
    flatten([for env in local.spoke_environments : env.route_table_ids])
  )

  # Breaks down the nested blackhole map layers to create clear targets for the routing resource loop
  blackhole_routes = flatten([
    for env_key, env_data in local.spoke_environments : [
      for idx, cidr in env_data.blackhole_cidrs : {
        key            = "${env_key}-blackhole-${idx}"
        route_table_id = aws_ec2_transit_gateway_route_table.spokes[env_key].id
        cidr           = cidr
      }
    ]
  ])
}

resource "aws_ec2_transit_gateway" "main" {
  description                     = "platform-tgw"
  default_route_table_association = "disable"
  default_route_table_propagation = "disable"
  dns_support                     = "enable"

  tags = merge(
    { Name = "platform-tgw" },
    var.extended_tags
  )
}

# Route Tables

resource "aws_ec2_transit_gateway_route_table" "wireguard" {
  transit_gateway_id = aws_ec2_transit_gateway.main.id
  tags = merge(
    { Name = "platform-wireguard-tgw-rt" },
    var.extended_tags
  )
}

resource "aws_ec2_transit_gateway_route_table" "spokes" {
  for_each           = local.spoke_environments
  transit_gateway_id = aws_ec2_transit_gateway.main.id
  tags = merge(
    { Name = "platform-${each.key}-tgw-rt" },
    var.extended_tags
  )
}

# VPC Attachments
# Default TGW route table association and propagation
# are disabled on every attachment so routing remains explicit.

resource "aws_ec2_transit_gateway_vpc_attachment" "wireguard" {
  vpc_id             = var.wireguard_vpc_id
  subnet_ids         = var.wireguard_public_subnet_ids
  transit_gateway_id = aws_ec2_transit_gateway.main.id
  dns_support        = "enable"

  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false

  tags = merge(
    { Name = "platform-wireguard-tgw-attachment" },
    var.extended_tags
  )
}

resource "aws_ec2_transit_gateway_vpc_attachment" "spokes" {
  for_each           = local.spoke_environments
  vpc_id             = each.value.vpc_id
  subnet_ids         = each.value.subnet_ids
  transit_gateway_id = aws_ec2_transit_gateway.main.id
  dns_support        = "enable"

  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false

  tags = merge(
    { Name = "platform-${each.key}-tgw-attachment" },
    var.extended_tags
  )
}

# Route Table Associations
# Each attachment is associated with exactly one route table.
# The associated route table is consulted when traffic arrives from that attachment, and its routes determine where the traffic can go.

resource "aws_ec2_transit_gateway_route_table_association" "wireguard" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.wireguard.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.wireguard.id
}

resource "aws_ec2_transit_gateway_route_table_association" "spokes" {
  for_each                       = local.spoke_environments
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.spokes[each.key].id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.spokes[each.key].id
}

# Route Propagations
# Propagation injects attachment CIDRs into route tables automatically 
# and only propagates what each domain is allowed to reach.

# WireGuard route table: learns dev + prod + itself
resource "aws_ec2_transit_gateway_route_table_propagation" "wireguard_learns_wireguard" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.wireguard.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.wireguard.id
}

resource "aws_ec2_transit_gateway_route_table_propagation" "wireguard_learns_spokes" {
  for_each                       = local.spoke_environments
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.spokes[each.key].id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.wireguard.id
}

# Dev and Prod route tables: learn wireguard + themselves only
# No cross spoke propagation — dev cannot reach prod, prod cannot reach dev
resource "aws_ec2_transit_gateway_route_table_propagation" "spokes_learn_wireguard" {
  for_each                       = local.spoke_environments
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.wireguard.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.spokes[each.key].id
}

resource "aws_ec2_transit_gateway_route_table_propagation" "spokes_learn_self" {
  for_each                       = local.spoke_environments
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.spokes[each.key].id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.spokes[each.key].id
}

# Explicit Black-Hole Routes
# Makes dev <-> prod isolation explicit rather than relying on the absence of a propagated route.

resource "aws_ec2_transit_gateway_route" "isolation_blackholes" {
  for_each = { for route in local.blackhole_routes : route.key => route }

  transit_gateway_route_table_id = each.value.route_table_id
  destination_cidr_block         = each.value.cidr
  blackhole                      = true
}

# VPC Routes → TGW
#
# Point all internal RFC1918 traffic to the Transit Gateway.
#
# All platform VPCs currently use 10.x.x.x RFC1918 ranges.
# The 10.0.0.0/8 supernet allows a single TGW route entry
# instead of creating one route per VPC CIDR.
#
# More specific local VPC routes automatically take precedence,
# so subnet-to-subnet traffic inside the same VPC never
# traverses the Transit Gateway.
#
# If future VPCs use other RFC1918 ranges (172.16/12 or
# 192.168/16), additional TGW routes will be required.

resource "aws_route" "vpc_to_tgw" {
  for_each = toset(local.all_vpc_route_tables)

  route_table_id         = each.value
  destination_cidr_block = "10.0.0.0/8"
  transit_gateway_id     = aws_ec2_transit_gateway.main.id

  depends_on = [
    aws_ec2_transit_gateway_vpc_attachment.wireguard,
    aws_ec2_transit_gateway_vpc_attachment.spokes
  ]
}