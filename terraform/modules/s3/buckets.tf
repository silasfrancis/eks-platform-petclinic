data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  bucket_suffix = "${data.aws_caller_identity.current.account_id}-${data.aws_region.current.name}"

  # Pure data configuration detailing unique traits for each application bucket
  app_buckets = {
    rds_backup = { name = "rds-backup",     force_destroy = false,  exp_days = 30, versioning = "Enabled" }
    loki       = { name = "loki-logs",      force_destroy = true,  exp_days = 30, versioning = "Suspended" }
    velero     = { name = "velero-backups", force_destroy = false, exp_days = 30, versioning = "Enabled" }
  }
}

# Buckets
resource "aws_s3_bucket" "this" {
  for_each = local.app_buckets

  bucket        = "${var.env}-${each.value.name}-${local.bucket_suffix}"
  force_destroy = each.value.force_destroy

  tags = var.extended_tags

}

# Public Access Blocks
resource "aws_s3_bucket_public_access_block" "this" {
  for_each = local.app_buckets

  bucket = aws_s3_bucket.this[each.key].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Server-Side Encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  for_each = local.app_buckets

  bucket = aws_s3_bucket.this[each.key].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.data_storage_kms_key_arn
    }
  }
}

# Bucket Versioning Config
resource "aws_s3_bucket_versioning" "this" {
  for_each = local.app_buckets

  bucket = aws_s3_bucket.this[each.key].id

  versioning_configuration {
    status = each.value.versioning
  }
}

# Lifecycle Expiration Rules
resource "aws_s3_bucket_lifecycle_configuration" "this" {
  for_each = local.app_buckets

  bucket = aws_s3_bucket.this[each.key].id

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