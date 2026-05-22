data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

resource "aws_s3_bucket" "tf_state_bucket" {
  bucket = "${var.env}-tfstate-${data.aws_caller_identity.current.account_id}-${data.aws_region.current.id}"
  force_destroy = false

  tags = {
    resource = "s3"
  }
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket" "rds-backup" {
  bucket_prefix = "${var.app}-${var.env}-rds-backup"
  force_destroy = true
  tags = {
    resource = "s3"
  }
}

resource "aws_s3_bucket" "loki" {
  bucket_prefix = "${var.app}-${var.env}-loki-logs"
  tags = {
    resource = "s3"
  }
}

resource "aws_s3_bucket" "velero" {
  bucket_prefix = "${var.app}-${var.env}-velero-backups"

  tags = {
    resource = "s3"
  }
}