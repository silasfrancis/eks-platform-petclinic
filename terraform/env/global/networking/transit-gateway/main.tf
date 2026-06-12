# Transit Gateway: WireGuard <-> Prod/Dev VPC connectivity
#
# Creates a Transit Gateway connecting the WireGuard VPN VPC to the prod and
# dev VPCs. This is what allows a client connected to the VPN to reach
# internal EKS resources (workloads, dashboards) and the EKS cluster API
# endpoint in both environments, without exposing them publicly.

# Remote State for Wireguard Server
# Provides the WireGuard VPC ID, CIDR, and public subnet/route table IDs used to attach it to the Transit Gateway
data "terraform_remote_state" "wireguard_server" {
  backend = "s3"

  config = {
    bucket = var.global_remote_state_bucket
    region = var.aws_region
    key    = var.wireguard_server_remote_state_key
  }
}

# Remote State for prod emvironment 
# Provides the prod VPC ID, CIDR, and private route table/subnet IDs used to attach prod to the Transit Gateway
data "terraform_remote_state" "prod_state" {
  backend = "s3"

  config = {
    bucket = var.prod_remote_state_bucket
    region = var.aws_region
    key    = var.prod_remote_state_key
  }
}

# Remote State for dev environment
# Provides the dev VPC ID, CIDR, and private route table/subnet IDs used to attach dev to the Transit Gateway
data "terraform_remote_state" "dev_state" {
  backend = "s3"

  config = {
    bucket = var.dev_remote_state_bucket
    region = var.aws_region
    key    = var.dev_remote_state_key
  }
}

# Transit Gateway
# Attaches the WireGuard, prod, and dev VPCs to a shared TGW so VPN clients can
# reach EKS workloads, dashboards, and the cluster API in both environments
module "transit_gateway" {
  source = "../../../../modules/transit-gateway"

  wireguard_public_route_table_ids = data.terraform_remote_state.wireguard_server.outputs.public_route_table_ids
  dev_private_route_table_ids = data.terraform_remote_state.dev_state.outputs.private_route_table_ids
  prod_private_route_table_ids = data.terraform_remote_state.prod_state.outputs.private_route_table_ids
  wireguard_vpc_id = data.terraform_remote_state.wireguard_server.outputs.vpc_id
  dev_vpc_id = data.terraform_remote_state.dev_state.outputs.vpc_id
  prod_vpc_id = data.terraform_remote_state.prod_state.outputs.vpc_id
  wireguard_public_subnet_ids = data.terraform_remote_state.wireguard_server.outputs.public_subnet_ids
  dev_private_subnet_ids = data.terraform_remote_state.dev_state.outputs.private_subnet_ids
  prod_private_subnet_ids = data.terraform_remote_state.prod_state.outputs.private_subnet_ids
  dev_vpc_cidr = data.terraform_remote_state.dev_state.outputs.vpc_cidr_block
  prod_vpc_cidr = data.terraform_remote_state.prod_state.outputs.vpc_cidr_block
  wireguard_vpc_cidr = data.terraform_remote_state.wireguard_server.outputs.vpc_cidr_block
  # CIDR block assigned to WireGuard client peers, used for TGW routes so client traffic reaches prod/dev
  wireguard_client_cidr = "10.2.2.0/24"
}