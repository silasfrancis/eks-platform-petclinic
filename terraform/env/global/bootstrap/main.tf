# Bootstrap: Terraform State Backend Resources
#
# Creates the S3 buckets used as remote state backends for every environment
# in this platform (global, dev, prod). This is the one piece of infrastructure
# that must exist *before* any other Terraform layer can run, since those
# layers configure their S3 backend to point at the buckets created here.
#
# Run once per AWS account, typically with local state (or a separate
# bootstrap-only backend) before any other module is applied.


# Account ID and region of the caller, used to build a globally-unique bucket suffix
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  # Environments to bootstrap
  environments = toset(["global", "dev", "prod"])

  # Suffix appended to each bucket name to keep it globally unique
  # e.g. dev-tfstate-<account_id>-<aws_region>
  bucket_suffix = "${data.aws_caller_identity.current.account_id}-${data.aws_region.current.name}"
}

# Core State Buckets (Creates both dev and prod buckets)
# One bucket per environment, used as the S3 backend for each environment's Terraform state
resource "aws_s3_bucket" "tf_state_bucket" {
  for_each = local.environments

  bucket        = "${each.value}-tfstate-${local.bucket_suffix}"
  force_destroy = false

  tags = {
    environment = each.value
  }

  # Protects state buckets from accidental deletion via terraform destroy
  lifecycle {
    prevent_destroy = true
  }
}

# State Bucket Versioning
# Enables versioning so prior state file versions can be recovered if state is corrupted or accidentally overwritten
resource "aws_s3_bucket_versioning" "tf_state" {
  for_each = local.environments
  bucket   = aws_s3_bucket.tf_state_bucket[each.value].id

  versioning_configuration {
    status = "Enabled"
  }
}

# Public Access Block
# Ensures state buckets (which may contain sensitive values) can never be made public
resource "aws_s3_bucket_public_access_block" "tf_state" {
  for_each = local.environments
  bucket   = aws_s3_bucket.tf_state_bucket[each.value].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Server-Side Encryption
# Encrypts state files at rest using AES256
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
# Automatically cleans up incomplete multipart uploads after 7 days to avoid storage cost creep
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