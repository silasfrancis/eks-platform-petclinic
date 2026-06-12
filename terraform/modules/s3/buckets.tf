# Application S3 Buckets
#
# Creates one S3 bucket per application data store: RDS backup exports
# (prod only), Loki log storage, and Velero cluster backups. Each bucket gets
# public access blocked, KMS encryption with the data storage key, per-bucket
# versioning, and a lifecycle rule that expires objects and aborts incomplete
# multipart uploads after exp_days.
#
# To add a new bucket: add an entry to all_app_buckets with name,
# force_destroy, exp_days, and versioning ("Enabled"/"Suspended"), and adjust
# the app_buckets filter if it needs environment-specific gating.


data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  # Suffix appended to each bucket name to keep it globally unique
  bucket_suffix = "${data.aws_caller_identity.current.account_id}-${data.aws_region.current.id}"

  # Master data configuration detailing unique traits for each application bucket
  all_app_buckets = {
    rds_backup = { name = "rds-backup",     force_destroy = false, exp_days = 30, versioning = "Enabled" }
    loki       = { name = "loki-logs",      force_destroy = true,  exp_days = 30, versioning = "Suspended" }
    velero     = { name = "velero-backups", force_destroy = false, exp_days = 30, versioning = "Enabled" }
  }

  # Dynamically filters the map: skip rds_backup unless var.env is exactly "prod"
  app_buckets = {
    for bucket_key, bucket_config in local.all_app_buckets : 
    bucket_key => bucket_config
    if bucket_key != "rds_backup" || var.env == "prod"
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
# All application buckets are private — no public access of any kind
resource "aws_s3_bucket_public_access_block" "this" {
  for_each = local.app_buckets

  bucket = aws_s3_bucket.this[each.key].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Server-Side Encryption
# All buckets encrypted with the shared data storage KMS key
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
# Versioning enabled for backup buckets (rds_backup, velero); suspended for
# Loki since log objects are short-lived and don't need version history
resource "aws_s3_bucket_versioning" "this" {
  for_each = local.app_buckets

  bucket = aws_s3_bucket.this[each.key].id

  versioning_configuration {
    status = each.value.versioning
  }
}

# Lifecycle Expiration Rules
# Expires objects and aborts incomplete multipart uploads after exp_days,
# per bucket
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