resource "aws_vpc_peering_connection" "vpc" {
  # Requester VPC (prod)
  vpc_id = var.requester_vpc_id

  # Accepter VPC (dev)
  peer_vpc_id = var.accepter_vpc_id

  auto_accept = true

  tags = {
    Name = "${var.name}-peering"
  }
}

# Routes from requester (prod) to accepter (dev)
resource "aws_route" "requester_routes" {

  # - prod public route tables (WireGuard subnet access to dev VPC)
  # - prod private route tables (ArgoCD / internal services access to dev EKS)
  count = length(var.requester_route_table_ids)

  route_table_id            = var.requester_route_table_ids[count.index]
  destination_cidr_block    = var.accepter_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.vpc.id
}

# Routes from accepter (dev) back to requester (prod)
resource "aws_route" "accepter_routes" {

  # Includes dev private route tables so dev workloads
  # can return traffic back to prod through the peering connection
  count = length(var.accepter_route_table_ids)

  route_table_id            = var.accepter_route_table_ids[count.index]
  destination_cidr_block    = var.requester_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.vpc.id
}

# Enable private DNS resolution
# Required for resolving private EKS endpoints across VPC peering
resource "aws_vpc_peering_connection_options" "requester" {
  vpc_peering_connection_id = aws_vpc_peering_connection.vpc.id

  requester {
    allow_remote_vpc_dns_resolution = true
  }
}

resource "aws_vpc_peering_connection_options" "accepter" {
  vpc_peering_connection_id = aws_vpc_peering_connection.vpc.id

  accepter {
    allow_remote_vpc_dns_resolution = true
  }
}