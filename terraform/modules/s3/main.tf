resource "aws_s3_bucket" "tf_state_bucket" {
  bucket = "${var.env}-${var.app}-tf-state"
  force_destroy = false

  tags = {
    resource = "s3"
  }
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket" "rds_export" {
  bucket        = "${var.env}-${var.app}-rds-export"
  force_destroy = true
  tags = {
    resource = "s3"
  }
}

resource "aws_s3_bucket" "loki" {
  bucket = "${var.env}-${var.app}-loki-logs"
  tags = {
    resource = "s3"
  }
}

resource "aws_s3_bucket" "velero" {
  bucket = "${var.env}-${var.app}-velero-backups"

  tags = {
    resource = "s3"
  }
}