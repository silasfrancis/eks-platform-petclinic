data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  # Environments to bootstrap
  environments = toset(["global", "dev", "prod"])
  bucket_suffix = "${data.aws_caller_identity.current.account_id}-${data.aws_region.current.name}"
}

# Core State Buckets (Creates both dev and prod buckets)
resource "aws_s3_bucket" "tf_state_bucket" {
  for_each = local.environments

  bucket        = "${each.value}-tfstate-${local.bucket_suffix}"
  force_destroy = false

  tags = {
    resource    = "s3"
    environment = each.value
  }

  lifecycle {
    prevent_destroy = true
  }
}

# State Bucket Versioning
resource "aws_s3_bucket_versioning" "tf_state" {
  for_each = local.environments
  bucket   = aws_s3_bucket.tf_state_bucket[each.value].id

  versioning_configuration {
    status = "Enabled"
  }
}

# Public Access Block
resource "aws_s3_bucket_public_access_block" "tf_state" {
  for_each = local.environments
  bucket   = aws_s3_bucket.tf_state_bucket[each.value].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Server-Side Encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "tf_state" {
  for_each = local.environments
  bucket   = aws_s3_bucket.tf_state_bucket[each.value].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Lifecycle Rules
resource "aws_s3_bucket_lifecycle_configuration" "tf_state" {
  for_each = local.environments
  bucket   = aws_s3_bucket.tf_state_bucket[each.value].id

  rule {
    id     = "cleanup-incomplete-multipart-uploads"
    status = "Enabled"

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}