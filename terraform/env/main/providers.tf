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