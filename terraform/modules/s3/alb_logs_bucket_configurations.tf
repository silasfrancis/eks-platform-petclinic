resource "aws_s3_bucket_lifecycle_configuration" "s3_bucket_config" {
    bucket = aws_s3_bucket.alb_logs.id
    rule {
      id = var.bucket_rule_id
      status = "Enabled"
      abort_incomplete_multipart_upload {
        days_after_initiation = var.bucket_exp_days
      }
      expiration {
        days = var.bucket_exp_days
      }
    }
  
}

resource "aws_s3_bucket_versioning" "bucket_versioning_config" {
  bucket = aws_s3_bucket.alb_logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "s3_server_side_config" {
    bucket = aws_s3_bucket.alb_logs.id
    rule {
        apply_server_side_encryption_by_default {
            sse_algorithm = "AES256"
        }
    }  
}

resource "aws_s3_bucket_public_access_block" "example" {
  bucket = aws_s3_bucket.alb_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}