# TRANSIT GATEWAY
#
# Central router connecting:
# - WireGuard VPC
# - Dev VPC
# - Prod VPC
#
# Default TGW route table behavior is disabled so all
# routing and segmentation is explicitly controlled.

resource "aws_ec2_transit_gateway" "main" {
  description = "platform-tgw"

  default_route_table_association = "disable"
  default_route_table_propagation = "disable"

  dns_support = "enable"

  tags = merge(
    {
      Name = "platform-tgw"
    },
    var.extended_tags
  )
}

# TGW ROUTE TABLES
#
# Each route table defines what destinations are reachable
# from a specific routing domain.
#
# shared:
#   Used by WireGuard/access VPC
#
# dev:
#   Dev can only reach:
#   - itself
#   - wireguard
#
# prod:
#   Prod can only reach:
#   - itself
#   - wireguard

resource "aws_ec2_transit_gateway_route_table" "shared" {
  transit_gateway_id = aws_ec2_transit_gateway.main.id

  tags = merge(
    {
      Name = "platform-shared-tgw-route-table"
    },
    var.extended_tags
  )
}

resource "aws_ec2_transit_gateway_route_table" "dev" {
  transit_gateway_id = aws_ec2_transit_gateway.main.id

  tags = merge(
    {
      Name = "platform-dev-tgw-route-table"
    },
    var.extended_tags
  )
}

resource "aws_ec2_transit_gateway_route_table" "prod" {
  transit_gateway_id = aws_ec2_transit_gateway.main.id

  tags = merge(
    {
      Name = "platform-prod-tgw-route-table"
    },
    var.extended_tags
  )
}

# VPC ATTACHMENTS
#
# Connects VPCs into the Transit Gateway.
#
# Dev/Prod use private subnets.
# WireGuard uses public subnet because it is the VPN ingress.

resource "aws_ec2_transit_gateway_vpc_attachment" "dev" {
  vpc_id             = var.dev_vpc_id
  subnet_ids         = var.dev_private_subnet_ids
  transit_gateway_id = aws_ec2_transit_gateway.main.id

  dns_support = "enable"

  tags = merge(
    {
      Name = "platform-dev-tgw-attachment"
    },
    var.extended_tags
  )
}

resource "aws_ec2_transit_gateway_vpc_attachment" "prod" {
  vpc_id             = var.prod_vpc_id
  subnet_ids         = var.prod_private_subnet_ids
  transit_gateway_id = aws_ec2_transit_gateway.main.id

  dns_support = "enable"

  tags = merge(
    {
      Name = "platform-prod-tgw-attachment"
    },
    var.extended_tags
  )
}

resource "aws_ec2_transit_gateway_vpc_attachment" "wireguard" {
  vpc_id             = var.wireguard_vpc_id
  subnet_ids         = var.wireguard_public_subnet_ids
  transit_gateway_id = aws_ec2_transit_gateway.main.id

  dns_support = "enable"

  tags = merge(
    {
      Name = "platform-wireguard-tgw-attachment"
    },
    var.extended_tags
  )
}

###########################################################
# TGW ROUTE TABLE ASSOCIATIONS
#
# Determines which TGW route table an attachment uses when traffic ARRIVES from that attachment.

resource "aws_ec2_transit_gateway_route_table_association" "shared" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.wireguard.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.shared.id
}

resource "aws_ec2_transit_gateway_route_table_association" "dev" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.dev.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.dev.id
}

resource "aws_ec2_transit_gateway_route_table_association" "prod" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.prod.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.prod.id
}


# TGW ROUTE PROPAGATION
#
# Propagation automatically injects attachment CIDRs into route tables.

# SHARED/WIREGUARD ROUTE TABLE
#
# WireGuard can reach:
# - dev
# - prod
# - itself

resource "aws_ec2_transit_gateway_route_table_propagation" "shared_self" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.wireguard.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.shared.id
}

resource "aws_ec2_transit_gateway_route_table_propagation" "shared_dev" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.dev.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.shared.id
}

resource "aws_ec2_transit_gateway_route_table_propagation" "shared_prod" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.prod.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.shared.id
}

# DEV ROUTE TABLE
#
# Dev can reach:
# - dev
# - wireguard
#
# Dev CANNOT reach prod because no prod route propagates.

resource "aws_ec2_transit_gateway_route_table_propagation" "dev_self" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.dev.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.dev.id
}

resource "aws_ec2_transit_gateway_route_table_propagation" "dev_wireguard" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.wireguard.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.dev.id
}

# PROD ROUTE TABLE
#
# Prod can reach:
# - prod
# - wireguard
#
# Prod CANNOT reach dev because no dev route propagates.

resource "aws_ec2_transit_gateway_route_table_propagation" "prod_self" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.prod.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.prod.id
}

resource "aws_ec2_transit_gateway_route_table_propagation" "prod_wireguard" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.wireguard.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.prod.id
}

# VPC ROUTES -> TGW
#
# Send all RFC1918 internal traffic into TGW.
#
# More specific local VPC CIDR routes automatically win,
# so local subnet traffic never leaves the VPC.

resource "aws_route" "dev_private_to_tgw" {
  for_each = toset(var.dev_private_route_table_ids)

  route_table_id         = each.value
  destination_cidr_block = "10.0.0.0/8"

  transit_gateway_id = aws_ec2_transit_gateway.main.id
}

resource "aws_route" "prod_private_to_tgw" {
  for_each = toset(var.prod_private_route_table_ids)

  route_table_id         = each.value
  destination_cidr_block = "10.0.0.0/8"

  transit_gateway_id = aws_ec2_transit_gateway.main.id
}

resource "aws_route" "wireguard_public_to_tgw" {
  for_each = toset(var.wireguard_public_route_table_ids)

  route_table_id         = each.value
  destination_cidr_block = "10.0.0.0/8"

  transit_gateway_id = aws_ec2_transit_gateway.main.id
}