locals {
  buckets = {
    rds_export = {
      id           = aws_s3_bucket.rds_export.id
      rule_id      = var.bucket_rule_id
      exp_days     = var.bucket_exp_days
      versioning   = true
    }
    tf_state = {
      id           = aws_s3_bucket.tf_state_bucket.id
      rule_id      = var.bucket_rule_id
      exp_days     = var.bucket_exp_days
      versioning   = true
    }
    alb_logs = {
      id           = aws_s3_bucket.alb_logs.id
      rule_id      = var.bucket_rule_id
      exp_days     = var.bucket_exp_days
      versioning   = false   
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "this" {
  for_each = local.buckets

  bucket = each.value.id

  rule {
    id     = each.value.rule_id
    status = "Enabled"

    abort_incomplete_multipart_upload {
      days_after_initiation = each.value.exp_days
    }

    expiration {
      days = each.value.exp_days
    }
  }
}

resource "aws_s3_bucket_versioning" "this" {
  for_each = { for k, v in local.buckets : k => v if v.versioning }

  bucket = each.value.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  for_each = local.buckets

  bucket = each.value.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "this" {
  for_each = local.buckets

  bucket = each.value.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}