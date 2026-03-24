terraform {
  #   backend "s3" {
  #     bucket       = ""${var.application_tag}-silas-${var.environment}""
  #     key          = "${var.environment}/terraform.tfstate"
  #     region       = "var.aws_region"
  #     use_lockfile = true
  #     encrypt      = true
  #   }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.37.0"
    }
  }
}

locals {
  service_accounts = [
    "config-server-sa",
    "customers-service-sa",
    "visits-service-sa",
    "vets-service-sa",
    "genai-service-sa",
    "db-migration-sa"
  ]
}

data "aws_availability_zones" "available" {
  state = "available"
}

module "app-registry" {
  source = "../../modules/app-registry"

  providers = {
    aws = aws.appregistry
  }

  env       = var.environment
  app       = var.app
  owner     = "silasfrancis"
  repo      = "https://github.com/silasfrancis/spring-boot-microservices"
  language  = "java"
  framework = "spring-boot"
}

module "kms" {
  source = "../../modules/kms"

  env = var.environment

  depends_on = [module.app-registry]
}

module "secret_manager" {
  source      = "../../modules/secret_manager"
  secret_name = "${var.environment}/springboot-microservices"

  depends_on = [module.app-registry]
}

module "s3" {
  source = "../../modules/s3"

  env             = var.environment
  bucket_name     = "${var.application_tag}-silas-${var.environment}"
  bucket_key      = "${var.environment}/terraform.tfstate"
  bucket_prefix   = "alb-logs"
  bucket_rule_id  = "${var.application_tag}${var.environment}"
  bucket_exp_days = 60
  bucket_tag_name = var.application_tag

  depends_on = [module.app-registry]
}

module "iam" {
  source = "../../modules/iam"

  env                    = var.environment
  app                    = var.app
  secret_name            = module.secret_manager.secret_name
  rds_export_bucket_arn  = module.s3.bucket_arn["rds_export_bucket_arn"]
  rds_export_kms_key_arn = module.kms.kms_key_arn["rds_data"]

  depends_on = [
    module.app-registry,
    module.secret_manager,
    module.s3,
    module.kms,
  ]
}

module "cloudwatch_logs" {
  source = "../../modules/cloudwatch_logs"

  env                = var.environment
  app                = var.app
  kms_infra_logs_arn = module.kms.kms_key_arn["infra_logs"]

  depends_on = [
    module.app-registry,
    module.kms,
  ]
}

module "vpc" {
  source = "../../modules/vpc"

  tags                     = var.application_tag
  app                      = var.app
  env                      = var.environment
  availability_zones       = data.aws_availability_zones.available.names
  vpc_flow_log_role_arn    = module.iam.roles["vpc_flow_logs_role"]
  vpc_flow_log_destination = module.cloudwatch_logs.logs_arn["vpc_flow_log_group_arn"]

  depends_on = [
    module.app-registry,
    module.iam,
    module.cloudwatch_logs,
  ]
}

module "ec2" {
  source = "../../modules/ec2"

  env                   = var.environment
  app                   = var.app
  ami                   = "ami-0b0b78dcacbab728f"
  instance_type         = "t3.micro"
  vpc_id                = module.vpc.vpc_id
  private_subnet_id     = module.vpc.subnets["private_subnet_1"]
  ec2_security_group_id = [module.vpc.security_group["ec2"]]
  iam_instance_profile  = module.iam.iam_instance_profile

  depends_on = [
    module.app-registry,
    module.vpc,
    module.iam,
  ]
}

module "eks" {
  source = "../../modules/eks"

  env                    = var.environment
  app                    = var.app
  k8_version             = "1.35"
  cluster_role_arn       = module.iam.roles["cluster_role"]
  node_role_arn          = module.iam.roles["worker_node_role"]
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
  jumphost_ec2_role_arn = module.iam.roles["jumphost_ec2_role"]

  depends_on = [
    module.app-registry,
    module.vpc,
    module.iam,
    module.kms,
  ]
}

module "rds" {
  source = "../../modules/rds"

  env                     = var.environment
  app                     = var.app
  private_subnet_ids      = [module.vpc.subnets["private_subnet_1"], module.vpc.subnets["private_subnet_2"]]
  mysql_version           = "8.0"
  db_instance_class       = "db.t3.medium"
  allocated_storage       = 20
  db_name                 = module.secret_manager.db_secrets["data_base"]
  db_username             = module.secret_manager.db_secrets["db_username"]
  db_password             = module.secret_manager.db_secrets["db_password"]
  rds_security_group_id   = [module.vpc.security_group["rds"]]
  rds_data_kms_arn        = module.kms.kms_key_arn["rds_data"]
  rds_monitoring_role_arn = module.iam.roles["rds_monitoring_role"]

  depends_on = [
    module.app-registry,
    module.vpc,
    module.secret_manager,
    module.kms,
    module.iam,
  ]
}

module "rds-s3-exporter" {
  source = "../../modules/rds-s3-exporter"

  env                          = var.environment
  app                          = var.app
  db_instance_identifier       = module.rds.db_identifier
  rds_export_bucket            = module.s3.bucket_name["rds_export_bucket_name"]
  rds_export_role_arn          = module.iam.roles["rds_export_role"]
  rds_export_lambda_role_arn   = module.iam.roles["rds_export_lambda_role"]
  slack_notify_lambda_role_arn = module.iam.roles["slack_notifier_lambda_role"]
  rds_export_kms_key_arn       = module.kms.kms_key_arn["infra_logs"]
  rds_export_kms_key_id        = module.kms.kms_key_id["rds_data"]
  slack_webhook_url            = module.secret_manager.slack_secrets["slack_aws_alert_webhook_url"]

  depends_on = [
    module.app-registry,
    module.rds,
    module.s3,
    module.iam,
    module.kms,
  ]
}

module "iam-oidc" {
  source   = "../../modules/iam-oidc"

  eks_oidc_provider_url = module.eks.oidc_provider_url

  depends_on = [
    module.app-registry,
    module.eks,
    module.secret_manager,
  ]
}


module "irsa" {
  source   = "../../modules/irsa"
  for_each = toset(local.service_accounts)

  env                   = var.environment
  app                   = var.app
  oidc_url              = module.iam-oidc.oidc_url_stripped
  oidc_arn              = module.iam-oidc.oidc_arn
  namespace             = var.eks_namespace
  service_account_name  = each.value
  secret_name           = module.secret_manager.secret_name

  depends_on = [
    module.app-registry,
    module.eks,
    module.secret_manager,
    module.iam-oidc,
  ]
}
