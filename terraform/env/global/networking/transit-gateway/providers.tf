terraform {
  # Partial backend configuration: bucket, key, region, and other S3 backend
  # settings are NOT defined here. Instead, they're supplied at init time via
  # `terraform init -backend-config=state.conf` (or an equivalent per-environment
  # config file).
  backend "s3" {}

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.37.0"
    }
  }
}

# Default provider configuration
# Applies default tags to all resources created by this provider that support tagging
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      managed_by = "terraform"
    }
  }
}