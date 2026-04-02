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

    helm = {
      source  = "hashicorp/helm"
      version = "3.1.1"
    }
  }
}

provider "aws" {
  alias  = "appregistry"
  region = var.aws_region
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = merge(
      {
        env        = var.environment
        app        = var.app
        managed_by = "terraform"
      },
      var.appregistry_application_tag != "" ? { awsApplication = var.appregistry_application_tag } : {}
    )
  }
}

provider "helm" {
  kubernetes = {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_ca_cert)
    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
      command     = "aws"
    }
  }
}