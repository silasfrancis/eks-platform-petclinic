# Remote State for prod VPC
data "terraform_remote_state" "prod_vpc" {
  backend = "s3"

  config = {
    bucket = var.prod_remote_state_bucket
    region = var.aws_region
    key    = var.prod_remote_state_key
  }
}

# Remote State for dev VPC
data "terraform_remote_state" "dev_vpc" {
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

  requester_vpc_id   = data.terraform_remote_state.prod_vpc.outputs.vpc_id
  accepter_vpc_id    = data.terraform_remote_state.dev_vpc.outputs.vpc_id

  requester_vpc_cidr = data.terraform_remote_state.prod_vpc.outputs.vpc_cidr_block
  accepter_vpc_cidr  = data.terraform_remote_state.dev_vpc.outputs.vpc_cidr_block

  requester_route_table_ids = data.terraform_remote_state.prod_vpc.outputs.all_route_table_ids
  accepter_route_table_ids  = data.terraform_remote_state.dev_vpc.outputs.all_route_table_ids
}