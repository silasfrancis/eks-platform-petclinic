# TRANSIT GATEWAY
#
# Central router connecting three VPCs:
#   wireguard (10.2.0.0/16) — VPN entry point
#   dev       (10.1.0.0/16) — dev VPC
#   prod      (10.0.0.0/16) — prod VPC
#
# Isolation model:
#   wireguard → dev    allowed
#   wireguard → prod   allowed
#   dev       → prod   blocked (explicit black-hole)
#   prod      → dev    blocked (explicit black-hole)
#
# Default TGW route tables are disabled and all routing is explicit.

locals {
  spoke_environments = {
    dev = {
      vpc_id          = var.dev_vpc_id
      subnet_ids      = var.dev_private_subnet_ids
      vpc_cidr        = var.dev_vpc_cidr
      route_table_ids = var.dev_private_route_table_ids
      blackhole_cidrs = [var.prod_vpc_cidr]
      # TARGET SPOKE PEERS ONLY: Explicitly route to WireGuard infrastructure.
      # Excludes 10.0.0.0/8 supernetting to protect local VPC DNS endpoints (10.1.0.2).
      peer_cidrs      = [var.wireguard_vpc_cidr, var.wireguard_client_cidr]
    }
    prod = {
      vpc_id          = var.prod_vpc_id
      subnet_ids      = var.prod_private_subnet_ids
      vpc_cidr        = var.prod_vpc_cidr
      route_table_ids = var.prod_private_route_table_ids
      blackhole_cidrs = [var.dev_vpc_cidr]
      # TARGET SPOKE PEERS ONLY: Explicitly route to WireGuard infrastructure.
      # Excludes 10.0.0.0/8 supernetting to protect local VPC DNS endpoints (10.0.0.2).
      peer_cidrs      = [var.wireguard_vpc_cidr, var.wireguard_client_cidr]
    }
  }

  # Creates a matrix of cross-VPC peer target routes for the Spoke VPC private route tables.
  # This map handles target routes explicitly without grabbing local network interfaces.
  explicit_spoke_routes = flatten([
    for env_key, env_data in local.spoke_environments : [
      for rt_id in env_data.route_table_ids : [
        for cidr in env_data.peer_cidrs : {
          key            = "${env_key}-${rt_id}-${cidr}"
          route_table_id = rt_id
          destination    = cidr
        }
      ]
    ]
  ])

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

  tags = merge({ Name = "platform-tgw" }, var.extended_tags)
}

# Route Tables

resource "aws_ec2_transit_gateway_route_table" "wireguard" {
  transit_gateway_id = aws_ec2_transit_gateway.main.id
  tags               = merge({ Name = "platform-wireguard-tgw-rt" }, var.extended_tags)
}

resource "aws_ec2_transit_gateway_route_table" "spokes" {
  for_each           = local.spoke_environments
  transit_gateway_id = aws_ec2_transit_gateway.main.id
  tags               = merge({ Name = "platform-${each.key}-tgw-rt" }, var.extended_tags)
}

# VPC Attachments

resource "aws_ec2_transit_gateway_vpc_attachment" "wireguard" {
  vpc_id             = var.wireguard_vpc_id
  subnet_ids         = var.wireguard_public_subnet_ids
  transit_gateway_id = aws_ec2_transit_gateway.main.id
  dns_support        = "enable"

  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false

  tags = merge({ Name = "platform-wireguard-tgw-attachment" }, var.extended_tags)
}

resource "aws_ec2_transit_gateway_vpc_attachment" "spokes" {
  for_each           = local.spoke_environments
  vpc_id             = each.value.vpc_id
  subnet_ids         = each.value.subnet_ids
  transit_gateway_id = aws_ec2_transit_gateway.main.id
  dns_support        = "enable"

  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false

  tags = merge({ Name = "platform-${each.key}-tgw-attachment" }, var.extended_tags)
}

# Route Table Associations
# Each attachment is associated with exactly one route table.

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
# WireGuard route table: learns dev + prod + itself.
# Spoke route tables: learn wireguard + themselves only.
# No cross-spoke propagation — dev/prod isolation enforced below.

resource "aws_ec2_transit_gateway_route_table_propagation" "wireguard_learns_wireguard" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.wireguard.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.wireguard.id
}

resource "aws_ec2_transit_gateway_route_table_propagation" "wireguard_learns_spokes" {
  for_each                       = local.spoke_environments
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.spokes[each.key].id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.wireguard.id
}

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
# Dev/prod isolation made explicit rather than relying on absence of propagation.

resource "aws_ec2_transit_gateway_route" "isolation_blackholes" {
  for_each = { for route in local.blackhole_routes : route.key => route }

  transit_gateway_route_table_id = each.value.route_table_id
  destination_cidr_block         = each.value.cidr
  blackhole                      = true
}

# Static Client Subnet Routes
#
# TGW propagation only advertises VPC subnet CIDRs — it has no knowledge of
# the WireGuard client subnet (var.wireguard_client_cidr) which exists only
# on the wg0 interface inside the EC2 kernel.
#
# These static routes explicitly teach each spoke TGW route table how to
# return traffic to VPN clients, enabling a clean routed model without NAT.

resource "aws_ec2_transit_gateway_route" "spokes_to_wireguard_clients" {
  for_each = local.spoke_environments

  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.spokes[each.key].id
  destination_cidr_block         = var.wireguard_client_cidr
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.wireguard.id
}

# VPC Spoke Routes → TGW
#
# Spoke VPC private route tables now route explicitly to peering resources only.
# This keeps local AWS VPC resolver endpoints (10.x.0.2) completely isolated from TGW loops.

resource "aws_route" "spokes_to_tgw_explicit" {
  for_each = { for route in local.explicit_spoke_routes : route.key => route }

  route_table_id         = each.value.route_table_id
  destination_cidr_block = each.value.destination
  transit_gateway_id     = aws_ec2_transit_gateway.main.id

  depends_on = [
    aws_ec2_transit_gateway_vpc_attachment.wireguard,
    aws_ec2_transit_gateway_vpc_attachment.spokes
  ]
}

# VPC WireGuard Entry Route → TGW
#
# Since the WireGuard entry point lives entirely outside the EKS networking domain,
# it utilizes a standard summary block (10.0.0.0/14 covers 10.0.x.x through 10.3.x.x)
# to point ingress VPN clients down to both internal spoke clusters via the TGW interface.

resource "aws_route" "wireguard_to_spokes" {
  for_each = toset(var.wireguard_public_route_table_ids)

  route_table_id         = each.value
  destination_cidr_block = "10.0.0.0/14"
  transit_gateway_id     = aws_ec2_transit_gateway.main.id

  depends_on = [
    aws_ec2_transit_gateway_vpc_attachment.wireguard,
    aws_ec2_transit_gateway_vpc_attachment.spokes
  ]
}