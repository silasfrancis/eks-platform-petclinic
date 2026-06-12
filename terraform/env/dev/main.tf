# Dev Environment Root Module
#
# Provisions the dev infrastructure resources for the eks-platform-petclinic
# platform: KMS keys, Secrets Manager lookups, S3 buckets, VPC/networking,
# NLB security groups, the EKS cluster, private Route53 hosted zone, IRSA roles, and
# RDS. Sized down relative to prod (single NAT gateway, no flow logs,
# db.t3.micro, LTR backup disabled).

# Data Sources

# Availability Zones
# Fetches all AZs available in the target region for use in subnet distribution
data "aws_availability_zones" "available" {
  state = "available"
}

# Remote State for global/app-registry outputs (App registry metadata)
# Provides shared application tags applied across all environments
data "terraform_remote_state" "app-registry" {
  backend = "s3"

  config = {
    bucket = var.global_remote_state_bucket
    region = var.aws_region
    key    = var.global_app_registry_remote_state_key
  }
}

# Remote State for Wireguard Server (Security group IDs for NLB rules and EKS control plane access)
# Provides the WireGuard VPC CIDR for cross-VPC ingress rules (NLB, EKS, RDS)
data "terraform_remote_state" "wireguard_server" {
  backend = "s3"

  config = {
    bucket = var.global_remote_state_bucket
    region = var.aws_region
    key    = var.wireguard_server_remote_state_key
  }
}


# Locals

locals {
  # Resource tags for all resources in this environment, merged with global application tags from remote state
  extended_tags = merge(
    {
      env        = var.environment
      app        = var.app
      managed_by = "terraform"
    }, 
    data.terraform_remote_state.app-registry.outputs.application_tag
  )
}

# Modules

# KMS
# Keys for encryption (EKS, RDS, S3, EBS, CloudWatch)
module "kms" {
  source = "../../modules/kms"

  env = var.environment
  app = var.app
  extended_tags = local.extended_tags
}

# Secrets Manager 
# Reads pre-created secrets for RDS credentials and Slack webhook
# Secrets must be populated in AWS before terraform apply
module "secret_manager" {
  source = "../../modules/secret_manager"

  env = var.environment
}

# S3 
# Tfstate, Loki log storage, Velero backup storage, RDS export bucket
# KMS key required for bucket encryption
module "s3" {
  source = "../../modules/s3"

  env                      = var.environment
  app                      = var.app
  data_storage_kms_key_arn = module.kms.kms_key_arn["data_storage"]
  extended_tags = local.extended_tags
}

# VPC 
# Networking layer (subnets, NAT, IGW, Route-tables,flow logs)
module "vpc" {
  source = "../../modules/vpc"

  env                      = var.environment
  vpc_name_prefix           = var.app
  availability_zones       = data.aws_availability_zones.available.names
  public_subnet_count       = 2
  private_subnet_count      = 2
  data_subnet_count         = 2
  nat_gateway_count         = 1
  enable_flow_logs          = false
  infra_common_kms_key_arn = module.kms.kms_key_arn["infra_common"]
  extended_tags = local.extended_tags
}

# NLB
# Security groups for the NLB created by via Kubernetes Service of type LoadBalancer for isitio gateways
module "nlb" {
  source = "../../modules/nlb"

  env = var.environment
  app = var.app
  vpc_id = module.vpc.vpc_id
  wireguard_vpc_cidr = data.terraform_remote_state.wireguard_server.outputs.vpc_cidr_block
  extended_tags = local.extended_tags
}

# EKS
# EKS control plane + bootstrap node group (runs Karpenter only)
module "eks" {
  source = "../../modules/eks"

  env                                = var.environment
  app                                = var.app
  cluster_version                    = "1.35"
  vpc_id                             = module.vpc.vpc_id
  private_subnets                    = module.vpc.private_subnet_ids
  nlb_external_sg_id                = module.nlb.nlb_external_sg_id
  nlb_internal_sg_id                = module.nlb.nlb_internal_sg_id
  wireguard_vpc_cidr                 = data.terraform_remote_state.wireguard_server.outputs.vpc_cidr_block
  eks_secrets_kms_key_arn          = module.kms.kms_key_arn["eks_secrets"]
  data_storage_kms_key_arn         = module.kms.kms_key_arn["data_storage"]
  infra_common_kms_key_arn        = module.kms.kms_key_arn["infra_common"]
  extended_tags = local.extended_tags

}

# DNS (Route53 Private Hosted Zone) 
# Private hosted zone for internal dashboard DNS
# Grafana, ArgoCD, Prometheus, Goldilocks — VPN access only
# VPC must exist (zone is associated with VPC)
# EKS must exist (cluster_name used for zone tagging)
module "dns" {
  source = "../../modules/dns"

  vpc_id       = module.vpc.vpc_id
  cluster_name = module.eks.cluster_name
}

# IRSA (IAM Roles for Service Accounts)
# Per-component IAM roles bound to EKS service accounts via OIDC
# One role per platform component: Karpenter, Loki, Velero, ESO, ExternalDNS etc
# EKS OIDC provider must exist — created by EKS module
module "irsa" {
  source = "../../modules/irsa"

  oidc_arn                        = module.eks.oidc_arn
  oidc_url                        = module.eks.oidc_url_stripped
  cluster_name                    = module.eks.cluster_name
  app_secrets_arn                 = [module.secret_manager.secret_arns["petclinic"]]
  platform_monitoring_secrets_arn = [module.secret_manager.secret_arns["monitoring"]]
  platform_dns_secrets_arn        = [module.secret_manager.secret_arns["dns"]]
  platform_security_secrets_arn   = [module.secret_manager.secret_arns["monitoring"], module.secret_manager.secret_arns["dns"]]
  argocd_secrets_arn              = [module.secret_manager.secret_arns["argocd"]]
  route53_private_zone_arn        = [module.dns.zone_arn]
  loki_bucket_arn                 = module.s3.bucket_arns["loki"]
  velero_bucket_arn               = module.s3.bucket_arns["velero"]
  data_storage_kms_key_arn        = module.kms.kms_key_arn["data_storage"]
  extended_tags = local.extended_tags
}

# RDS
# MySQL database for petclinic microservices
# Credentials read from Secrets Manager
# EKS node SG added to RDS ingress rules via module
module "rds" {
  source = "../../modules/rds"

  env                                = var.environment
  app                                = var.app
  vpc_id                             = module.vpc.vpc_id
  data_subnet_ids                    = module.vpc.data_subnet_ids
  mysql_version                      = "8.0"
  db_instance_class                  = "db.t3.micro"
  allocated_storage                  = 20
  db_name                            = module.secret_manager.db_credentials["database"]
  db_username                        = module.secret_manager.db_credentials["username"]
  db_password                        = module.secret_manager.db_credentials["password"]
  eks_node_sg_id                     = module.eks.eks_node_sg_id
  wireguard_vpc_cidr                 = data.terraform_remote_state.wireguard_server.outputs.vpc_cidr_block
  data_storage_kms_key_arn           = module.kms.kms_key_arn["data_storage"]
  extended_tags = local.extended_tags
}

# RDS LTR (Long-term Retention) Automated Backup
# Automated backup of RDS snapshot exports to S3
# Uses Envent bridge, SQS and DLQ for orchestration, and Lambda for execution
# Cloudwatch Alarms for monitoring and alerting on DLQ messages (backup failures) with SNS topic for notifications to slack via Lambda subscription
# Daily Summary reports for backups to Slack via webhook URL stored in Secrets Manager
# Not enabled in the dev environment

module "rds_ltr_backup" {
  source = "../../modules/rds-ltr-backup"

  enable_rds_ltr_backup        = false
  env                          = var.environment
  app                          = var.app
  db_instance_identifier       = module.rds.db_identifier
  rds_backup_bucket            = module.s3.bucket_names["rds_backup"]
  rds_backup_bucket_arn        = module.s3.bucket_arns["rds_backup"]
  infra_common_kms_key_arn     = module.kms.kms_key_arn["infra_common"]
  data_storage_kms_key_arn     = module.kms.kms_key_arn["data_storage"]
  slack_webhook            = module.secret_manager.slack_webhook_url
  extended_tags = local.extended_tags
}
