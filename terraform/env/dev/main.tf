terraform {
  #   backend "s3" {
  #     bucket       = "silas-dev-silas-dev"
  #     key          = "dev/terraform.tfstate"
  #     region       = "us-east-2"
  #     use_lockfile = true
  #     encrypt      = true
  #   }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.35.1"
    }
  }
}

provider "aws" {
  region = "us-east-2"
}

locals {
  environment = "dev"
  tag         = "silas-dev"
  namespace   = "microservices"

  service_accounts = [
    "config-server-sa",
    "customers-service-sa",
    "visits-service-sa",
    "vets-service-sa",
    "genai-service-sa",
  ]
}

variable "slack_webhook_url" {
  type = string
}

module "kms" {
  source = "../../aws_modules/kms"

  env = local.environment
}

module "secret_manager" {
  source      = "../../aws_modules/secret_manager"
  secret_name = "spring_boot_micro_services_secrets"
}

module "s3" {
  source = "../../aws_modules/s3"

  bucket_name     = "${local.tag}-silas-${local.environment}"
  bucket_key      = "${local.environment}/terraform.tfstate"
  bucket_prefix   = "alb-logs"
  bucket_rule_id  = "${local.tag}${local.environment}"
  bucket_exp_days = 60
  bucket_tag_name = local.tag
}

module "iam" {
  source = "../../aws_modules/iam"

  tags                   = local.tag
  env                    = local.environment
  secret_name            = module.secret_manager.secret_name
  rds_export_bucket_arn  = module.s3.bucket_arn["rds_export_bucket_arn"]
  rds_export_kms_key_arn = module.kms.kms_key_arn["rds_data"]
}

module "cloudwatch_logs" {
  source = "../../aws_modules/cloudwatch_logs"

  env                = local.environment
  kms_infra_logs_arn = module.kms.kms_key_arn["infra_logs"]
}

module "vpc" {
  source = "../../aws_modules/vpc"

  tags                     = local.tag
  env                      = local.environment
  vpc_flow_log_role_arn    = module.iam.roles["vpc_flow_logs_role"]
  vpc_flow_log_destination = module.cloudwatch_logs.logs_arn["vpc_flow_log_group_arn"]
}

module "ec2" {
  source = "../../aws_modules/ec2"

  tags                  = local.tag
  ami                   = "ami-0b0b78dcacbab728f"
  instance_type         = "t3.micro"
  vpc_id                = module.vpc.vpc_id
  private_subnet_id     = module.vpc.subnets["private_subnet"]
  ec2_security_group_id = [module.vpc.security_group["ec2"]]
  iam_instance_profile  = module.iam.iam_instance_profile
}

module "eks" {
  source = "../../aws_modules/eks"

  env                    = local.environment
  k8_version             = "1.35"
  cluster_role_arn       = module.iam.roles["eks_cluster_role"]
  node_role_arn          = module.iam.roles["eks_node_role"]
  subnet_ids_for_cluster = [module.vpc.subnets["private_subnet_1"], module.vpc.subnets["private_subnet_2"]]
  subnet_ids_node_group  = module.vpc.private_subnets
  node_scaling_config = {
    desired_size = 2
    max_size     = 3
    min_size     = 1
  }
  security_group_id     = [module.vpc.security_group["eks"]]
  ami_type              = "AL2023_ARM_64_STANDARD"
  disk_size             = "20"
  instance_types        = ["t4g.medium"]
  kms_eks_secrets_arn   = module.kms.kms_key_arn["eks_secrets"]
  kms_eks_nodes_ebs_arn = module.kms.kms_key_arn["eks_nodes_ebs"]
}

module "rds" {
  source = "../../aws_modules/rds"

  env                     = local.environment
  private_subnet_ids      = [module.vpc.subnets["private_subnet_1"], module.vpc.subnets["private_subnet_2"]]
  mysql_version           = "8.0"
  db_instance_class       = "db.t3.micro"
  allocated_storage       = 20
  db_name                 = module.secret_manager.db_secrets["data_base"]
  db_username             = module.secret_manager.db_secrets["db_username"]
  db_password             = module.secret_manager.db_secrets["db_password"]
  rds_security_group_id   = [module.vpc.security_group["rds"]]
  rds_data_kms_arn        = module.kms.kms_key_arn["rds_data"]
  rds_monitoring_role_arn = module.iam.roles["rds_monitoring_role"]
}

module "rds-s3-exporter" {
  source = "../../aws_modules/rds-s3-exporter"

  env                          = local.environment
  db_instance_identifier       = module.rds.db_identifier
  rds_export_bucket            = module.s3.bucket_name["rds_export_bucket_name"]
  rds_export_role_arn          = module.iam.roles["rds_export_role"]
  rds_export_lambda_role_arn   = module.iam.roles["rds_export_lambda_role"]
  slack_notify_lambda_role_arn = module.iam.roles["slack_notify_lambda_role"]
  rds_export_kms_key_arn       = module.kms.kms_key_arn["rds_export"]
  rds_export_kms_key_id        = module.kms.kms_key_id["rds_export"]
  slack_webhook_url            = var.slack_webhook_url
}

module "iam_oidc" {
  source   = "../../aws_modules/iam_oidc"
  for_each = toset(local.service_accounts)

  env                   = local.environment
  eks_oidc_provider_url = module.eks.oidc_provider_url
  namespace             = local.namespace
  service_account_name  = each.value
  secret_name           = module.secret_manager.secret_name
}