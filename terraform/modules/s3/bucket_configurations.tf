locals {
  buckets = {
    rds_export = {
      id           = aws_s3_bucket.rds_export.id
      exp_days     = 30
      versioning   = true
    }
    loki = {
      id           = aws_s3_bucket.loki.id
      exp_days     = 30
      versioning   = false
    }
    tf_state = {
      id           = aws_s3_bucket.tf_state_bucket.id
      exp_days     = 30
      versioning   = true
    }
    
    velero = {
      id           = aws_s3_bucket.velero.id
      exp_days     = 30
      versioning   = true
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "this" {
  for_each = local.buckets

  bucket = each.value.id

  rule {
    id     = "autoclean-${each.key}-${each.value.exp_days}-days"
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
  for_each = local.buckets

  bucket = each.value.id

  versioning_configuration {
    status = each.value.versioning ? "Enabled" : "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  for_each = local.buckets

  bucket = each.value.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.data_storage_kms_key_arn
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