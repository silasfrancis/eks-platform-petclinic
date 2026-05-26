# Remote State for prod emvironment 
data "terraform_remote_state" "prod_state" {
  backend = "s3"

  config = {
    bucket = var.prod_remote_state_bucket
    region = var.aws_region
    key    = var.prod_remote_state_key
  }
}

# Remote State for dev environment
data "terraform_remote_state" "dev_state" {
  backend = "s3"

  config = {
    bucket = var.dev_remote_state_bucket
    region = var.aws_region
    key    = var.dev_remote_state_key
  }
}

# VPC Peering Connections (prod -> dev)
module "vpc-peering" {
  source = "../../../modules/vpc-peering"
  name = "prod-dev"

  requester_vpc_id   = data.terraform_remote_state.prod_state.outputs.vpc_id
  accepter_vpc_id    = data.terraform_remote_state.dev_state.outputs.vpc_id

  requester_vpc_cidr = data.terraform_remote_state.prod_state.outputs.vpc_cidr_block
  accepter_vpc_cidr  = data.terraform_remote_state.dev_state.outputs.vpc_cidr_block

  requester_route_table_ids = data.terraform_remote_state.prod_state.outputs.all_route_table_ids
  accepter_route_table_ids  = data.terraform_remote_state.dev_state.outputs.all_route_table_ids
}

# Wireguard sever (EC2 instance) in prod VPC
module "wireguard" {
  source = "../../../modules/wireguard"

  env = "prod"
  app = "wireguard"
  public_subnet_id  = data.terraform_remote_state.prod_state.outputs.public_subnet_ids[0]
  wireguard_sg_id = data.terraform_remote_state.prod_state.outputs.wireguard_sg_id
  data_storage_kms_key_arn = data.terraform_remote_state.prod_state.outputs.kms_key_arn["data_storage"]
  platform_engineers_group_name = "platform"
}