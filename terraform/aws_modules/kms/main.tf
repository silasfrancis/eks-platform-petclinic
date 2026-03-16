resource "aws_kms_key" "rds_export_key" {
  description = "KMS key for RDS snapshot exports"
}