resource "aws_s3_bucket" "tf_state_bucket" {
  bucket = "${data.aws_caller_identity.current.account_id}-${var.env}-tfstate"
  force_destroy = false

  tags = {
    resource = "s3"
  }
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket" "rds_export" {
  bucket_prefix = "${var.env}-rds-export"
  force_destroy = true
  tags = {
    resource = "s3"
  }
}

resource "aws_s3_bucket" "loki" {
  bucket_prefix = "${var.env}-${var.app}-loki-logs"
  tags = {
    resource = "s3"
  }
}

resource "aws_s3_bucket" "velero" {
  bucket_prefix = "${var.env}-velero-backups"

  tags = {
    resource = "s3"
  }
}