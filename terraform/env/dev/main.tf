terraform {
  #   backend "s3" {
  #   bucket = "silas-main-silas-main"
  #   key = "main/terraform.tfstate"
  #   region = "us-east-2"
  #   use_lockfile = true
  #   encrypt = true
    
  # }

  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "6.35.1"
    }
  }
}

provider "aws" {
  region = "us-east-2"
}

locals {
  environment = "main"
  tag = "silas-main"
}

module "iam" {
    source = "../../aws_modules/iam"

    tags = "${local.tag}"
    secret_name = "node_js_app_secrets"
}

module "vpc" {
  source = "../../aws_modules/vpc"

  tags = "${local.tag}"
}

module "ec2" {
  source = "../../aws_modules/ec2"

  tags = "${local.tag}"
  ami = "ami-06e3c045d79fd65d9"
  instance_type = "t3.small"
  vpc_id = module.vpc.vpc_id
  private_subnet_id = module.vpc.subnets["private_subnet"]
  ec2_security_group_id = [module.vpc.security_group["ec2"]]
  iam_instance_profile = module.iam.iam_instance_profile
}

module "acm_cert" {
  source = "../../aws_modules/acm_cert"
}

module "s3_alb_logs"{
  source = "../../aws_modules/s3_alb_logs"

  bucket_name = "${local.tag}-silas-${local.environment}"
  bucket_prefix = "alb-logs"
  bucket_rule_id = "${local.tag}${local.environment}"
  bucket_exp_days = 60
}

module "elb" {
  source = "../../aws_modules/elb"

  tags = "${local.tag}"
  public_subnets = [
                        module.vpc.subnets["public_subnet_1"], 
                        module.vpc.subnets["public_subnet_2"]
                      ]
  security_groups = [module.vpc.security_group["alb"]]
  vpc_id = module.vpc.vpc_id
  ec2_instance_id = module.ec2.ec2_instance_id
  certificate_arn = module.acm_cert.certificate_arn
  alb_log_bucket_id = module.s3_alb_logs.alb_log_bucket
  alb_log_bucket_prefix = "alb-logs"
}

module "s3_tf_state" {
  source = "../../aws_modules/s3_tf_state"
  
  bucket_name = "${local.tag}-silas-${local.environment}"
  bucket_key = "${local.environment}/terraform.tfstate"
  bucket_tag_name = "${local.tag}"
  bucket_rule_id = "${local.tag}${local.environment}"
  bucket_exp_days = 60
}