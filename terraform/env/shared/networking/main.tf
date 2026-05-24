data "terraform_remote_state" "prod_vpc" {
  backend = "s3"

  config = {
    bucket = "your-tf-state"
    key    = "prod/vpc/terraform.tfstate"
    region = "us-east-1"
  }
}

data "terraform_remote_state" "dev_vpc" {
  backend = "s3"

  config = {
    bucket = "your-tf-state"
    key    = "dev/vpc/terraform.tfstate"
    region = "us-east-1"
  }
}

module "prod_to_dev_peering" {
  source = "../../../modules/vpc-peering"

  name = "prod-dev"

  requester_vpc_id   = data.terraform_remote_state.prod_vpc.outputs.vpc_id
  accepter_vpc_id    = data.terraform_remote_state.dev_vpc.outputs.vpc_id

  requester_vpc_cidr = data.terraform_remote_state.prod_vpc.outputs.vpc_cidr
  accepter_vpc_cidr  = data.terraform_remote_state.dev_vpc.outputs.vpc_cidr

  requester_route_table_ids =
    data.terraform_remote_state.prod_vpc.outputs.private_route_table_ids

  accepter_route_table_ids =
    data.terraform_remote_state.dev_vpc.outputs.private_route_table_ids
}