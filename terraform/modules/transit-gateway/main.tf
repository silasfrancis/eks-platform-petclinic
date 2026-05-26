resource "aws_ec2_transit_gateway" "main" {
  description = "platform-tgw"

  default_route_table_association = false
  default_route_table_propagation = false

  dns_support = "enable"

  tags = {
    Name = "platform-tgw"
  }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "dev" {
  vpc_id     = var.dev_vpc_id
  subnet_ids = var.dev_private_subnets

  transit_gateway_id = aws_ec2_transit_gateway.main.id
}

resource "aws_ec2_transit_gateway_vpc_attachment" "main" {
  vpc_id     = var.dev_vpc_id
  subnet_ids = var.dev_private_subnets

  transit_gateway_id = aws_ec2_transit_gateway.main.id
}

resource "aws_ec2_transit_gateway_vpc_attachment" "wireguard" {
  vpc_id     = var.dev_vpc_id
  subnet_ids = var.dev_private_subnets

  transit_gateway_id = aws_ec2_transit_gateway.main.id
}

resource "aws_ec2_transit_gateway_route_table" "dev" {}
resource "aws_ec2_transit_gateway_route_table" "prod" {}
resource "aws_ec2_transit_gateway_route_table" "shared" {}

resource "aws_ec2_transit_gateway_route_table_association" "dev" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.dev.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.dev.id
}

resource "aws_ec2_transit_gateway_route_table_association" "prod" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.dev.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.dev.id
}

resource "aws_ec2_transit_gateway_route_table_propagation" "dev_wireguard" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.wireguard.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.dev.id
}

resource "aws_ec2_transit_gateway_route_table_propagation" "prod_wireguard" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.wireguard.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.prod.id
}

resource "aws_ec2_transit_gateway_route" "dev_default" {
  destination_cidr_block = "10.10.0.0/16"
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.dev.id
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.dev.id
}