# WireGuard VPN Server
#
# Stands up a dedicated VPC and EC2-based WireGuard VPN server, used as the
# entry point for platform engineers to securely access internal EKS
# resources and cluster APIs in the prod/dev VPCs via the Transit Gateway.

# Availability Zones
data "aws_availability_zones" "available" {
  state = "available"
}

# WireGuard VPC
# Lightweight VPC with a single public subnet only — no private/data subnets
# or NAT gateways needed since this VPC only hosts the VPN server
module "vpc" {
  source = "../../../../modules/vpc"

  env                      = var.environment
  vpc_name_prefix           = "wireguard-server"
  availability_zones       = data.aws_availability_zones.available.names
  public_subnet_count       = 1
  private_subnet_count      = 0
  data_subnet_count         = 0
  nat_gateway_count         = 0
  enable_flow_logs          = false
}

# WireGuard server (EC2 instance) in the WireGuard VPC
# Bootstraps the VPN server and grants access to the "platform" IAM group
# (platform engineers connect to this server to reach internal resources)
module "wireguard_server" {
  source = "../../../../modules/wireguard"
  
  vpc_id = module.vpc.vpc_id
  public_subnet_id  = module.vpc.public_subnet_ids[0]
  platform_engineers_group_name = "platform"
}