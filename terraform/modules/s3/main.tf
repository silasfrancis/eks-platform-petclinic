resource "aws_s3_bucket" "tf_state_bucket" {
  bucket = "${var.bucket_name}-tf-state"
  force_destroy = false
  lifecycle {
    prevent_destroy = true
  }
  tags = {
    resource = "s3"
  }
}

resource "aws_s3_bucket" "alb_logs" {
  bucket = "${var.bucket_name}-alb-logs"
  force_destroy = true
  tags = {
    resource = "s3"
  }
}

resource "aws_s3_bucket" "rds_export" {
  bucket        = "${var.bucket_name}-rds-export"
  force_destroy = false
  tags = {
    resource = "s3"
  }
}


resource "aws_s3_object" "tf_state_object" {
  bucket = aws_s3_bucket.tf_state_bucket.id
  key = var.bucket_key
  tags = {
    resource = "s3"
  }
}
