# Availability Zones
data "aws_availability_zones" "available" {
  state = "available"
}

# Remote State for global/resource-level outputs (App registry metadata)
data "terraform_remote_state" "global_resources" {
  backend = "s3"

  config = {
    bucket = var.global_remote_state_bucket
    region = var.aws_region
    key    = var.global_resources_remote_state_key
  }
}

locals {
  # Resource tags for all resources in this environment, merged with global application tags from remote state
  extended_tags = merge(
    {
      env        = var.environment
      app        = var.app
      managed_by = "terraform"
    },
    data.terraform_remote_state.global_resources.outputs.application_tag
  )
}

# KMS
# Keys for encryption (EKS, RDS, S3, EBS, CloudWatch)
module "kms" {
  source = "../../modules/kms"

  env = var.environment
  app = var.app
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
}

# IAM
# IAM roles for EC2, EKS, RDS, Lambda, and VPC flow logs
module "iam" {
  source = "../../modules/iam"

  env                      = var.environment
  app                      = var.app
  rds_export_bucket_arn    = module.s3.bucket_arn["rds_export_bucket_arn"]
  data_storage_kms_key_arn = module.kms.kms_key_arn["data_storage"]
}

# CloudWatch Logs
# Log groups for EKS and VPC flow logs
module "cloudwatch_logs" {
  source = "../../modules/cloudwatch_logs"

  env                      = var.environment
  app                      = var.app
  infra_common_kms_key_arn = module.kms.kms_key_arn["infra_common"]
}

# VPC 
# Networking layer (subnets, security groups, NAT, flow logs)
module "vpc" {
  source = "../../modules/vpc"

  app                      = var.app
  env                      = var.environment
  availability_zones       = data.aws_availability_zones.available.names
  vpc_flow_log_role_arn    = module.iam.roles["vpc_flow_logs_role"]
  vpc_flow_log_destination = module.cloudwatch_logs.logs_arn["vpc_flow_log_group_arn"]
}

# EC2 (WireGuard Server) 
# Public EC2 instance for WireGuard VPN
# Configured via Ansible over SSM after Terraform — no SSH port needed
# KMS dependency added — EBS root volume is encrypted
module "ec2" {
  source = "../../modules/ec2"

  env                                = var.environment
  app                                = var.app
  public_subnet_id                   = module.vpc.public_subnets[0]
  wireguard_server_security_group_id = module.vpc.security_group["wireguard_server"]
  wireguard_server_instance_profile  = module.iam.wireguard_server_instance_profile
  data_storage_kms_key_arn           = module.kms.kms_key_arn["data_storage"] # EBS volume encryption
  platform_engineers_group_name      = "platform"
}

# EKS
# EKS control plane + bootstrap node group (runs Karpenter only)
# VPC, IAM roles and KMS keys must exist first
module "eks" {
  source = "../../modules/eks"

  env                                = var.environment
  app                                = var.app
  cluster_version                    = "1.35"
  cluster_role_arn                   = module.iam.roles["cluster_role"]
  node_role_arn                      = module.iam.roles["node_role"]
  private_subnets                    = module.vpc.private_subnets
  eks_node_sg_id                     = module.vpc.security_group["eks_node"]
  wireguard_server_security_group_id = module.vpc.security_group["wireguard_server"]
  nlb_external_security_group_id     = module.vpc.security_group["nlb_external"]
  eks_secrets_kms_key_arn            = module.kms.kms_key_arn["eks_secrets"]
  data_storage_kms_key_arn           = module.kms.kms_key_arn["data_storage"]
}

# DNS (Route53 Private Hosted Zone) 
# Private hosted zone for internal dashboard DNS
# Grafana, ArgoCD, Prometheus, Loki — VPN access only
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
# Removed module.iam-oidc reference — OIDC provider is part of module.eks
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
  loki_bucket_arn                 = module.s3.bucket_arn["loki_bucket_arn"]
  velero_bucket_arn               = module.s3.bucket_arn["velero_bucket_arn"]
  data_storage_kms_key_arn        = module.kms.kms_key_arn["data_storage"]
}

# RDS
# MySQL database for petclinic microservices
# Credentials read from Secrets Manager — never hardcoded
# EKS node SG added to RDS ingress rules via module
module "rds" {
  source = "../../modules/rds"

  env                                = var.environment
  app                                = var.app
  private_subnets                    = module.vpc.private_subnets
  mysql_version                      = "8.0"
  db_instance_class                  = "db.t3.medium"
  allocated_storage                  = 20
  db_name                            = module.secret_manager.db_credentials["database"]
  db_username                        = module.secret_manager.db_credentials["username"]
  db_password                        = module.secret_manager.db_credentials["password"]
  rds_security_group_id              = module.vpc.security_group["rds"]
  eks_node_sg_id                     = module.vpc.security_group["eks_node"]
  wireguard_server_security_group_id = module.vpc.security_group["wireguard_server"]
  data_storage_kms_key_arn           = module.kms.kms_key_arn["data_storage"]
  rds_monitoring_role_arn            = module.iam.roles["rds_monitoring_role"]
}

# RDS Automated Backup
# Lambda-based scheduled export of RDS snapshots to S3
# with Slack notifications for backup failures
module "rds-automated-backup" {
  source = "../../modules/rds-automated-backup"

  env                          = var.environment
  app                          = var.app
  db_instance_identifier       = module.rds.db_identifier
  rds_export_bucket            = module.s3.bucket_name["rds_export_bucket_name"]
  rds_export_role_arn          = module.iam.roles["rds_export_role"]
  lambda_backup_role_arn       = module.iam.roles["lambda_backup_role"]
  lambda_notification_role_arn = module.iam.roles["lambda_notification_role"]
  infra_common_kms_key_arn     = module.kms.kms_key_arn["infra_common"]
  data_storage_kms_key_arn     = module.kms.kms_key_arn["data_storage"]
  slack_webhook_url            = module.secret_manager.slack_webhook_url
}

# NLB Security Group Rules
# Manages ingress/egress rules on the NLB security groups
module "nlb" {
  source = "../../modules/nlb"

  nlb_external_sg_id                 = module.vpc.security_group["nlb_external"]
  nlb_internal_sg_id                 = module.vpc.security_group["nlb_internal"]
  wireguard_server_security_group_id = module.vpc.security_group["wireguard_server"]
}