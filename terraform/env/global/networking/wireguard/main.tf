# Availability Zones
data "aws_availability_zones" "available" {
  state = "available"
}

#Wireguard VPC
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

# Wireguard sever (EC2 instance) in prod VPC
module "wireguard_server" {
  source = "../../../../modules/wireguard"
  
  vpc_id = module.vpc.vpc_id
  public_subnet_id  = module.vpc.public_subnet_ids[0]
  platform_engineers_group_name = "platform"
}
