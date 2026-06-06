# Remote State for Wireguard Server
data "terraform_remote_state" "wireguard_server" {
  backend = "s3"

  config = {
    bucket = var.global_remote_state_bucket
    region = var.aws_region
    key    = var.wireguard_server_remote_state_key
  }
}

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

# Transit Gateway
module "transit_gateway" {
  source = "../../../../modules/transit-gateway"

  wireguard_public_route_table_ids = data.terraform_remote_state.wireguard_server.outputs.public_route_table_ids
  # dev_private_route_table_ids = data.terraform_remote_state.dev_state.outputs.private_route_table_ids
  prod_private_route_table_ids = data.terraform_remote_state.prod_state.outputs.private_route_table_ids
  wireguard_vpc_id = data.terraform_remote_state.wireguard_server.outputs.vpc_id
  # dev_vpc_id = data.terraform_remote_state.dev_state.outputs.vpc_id
  prod_vpc_id = data.terraform_remote_state.prod_state.outputs.vpc_id
  wireguard_public_subnet_ids = data.terraform_remote_state.wireguard_server.outputs.public_subnet_ids
  # dev_private_subnet_ids = data.terraform_remote_state.dev_state.outputs.private_subnet_ids
  prod_private_subnet_ids = data.terraform_remote_state.prod_state.outputs.private_subnet_ids
  # dev_vpc_cidr = data.terraform_remote_state.dev_state.outputs.vpc_cidr_block
  prod_vpc_cidr = data.terraform_remote_state.prod_state.outputs.vpc_cidr_block
  wireguard_vpc_cidr = data.terraform_remote_state.wireguard_server.outputs.vpc_cidr_block
  wireguard_client_cidr = "10.2.2.0/24"
}