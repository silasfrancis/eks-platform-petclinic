terraform {
  backend "s3" {} # partial configuration - state details are being read from a state.conf file at runtime

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.37.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      env        = "networking"
      managed_by = "terraform"
    }
  }
}
