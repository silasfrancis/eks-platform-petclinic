resource "aws_db_snapshot" "pre_deploy" {
  db_instance_identifier = aws_db_instance.main.identifier
  db_snapshot_identifier = "${var.env}-mysql-pre-deploy-${formatdate("YYYY-MM-DD", timestamp())}"

  tags = { Purpose = "pre-deployment snapshot" }

  lifecycle {
    ignore_changes = [db_snapshot_identifier] 
  }
}

data "aws_db_snapshot" "latest_db_snapshot" {
  db_instance_identifier = aws_db_instance.main.identifier
  snapshot_type          = "automated"
  most_recent            = true
}

resource "aws_rds_export_task" "latest" {
  count = var.run_snapshot_export ? 1 : 0
  
  export_task_identifier = "${var.env}-mysql-export-${formatdate("YYYYMMDDhhmmss", timestamp())}"
  source_arn             = data.aws_db_snapshot.latest_db_snapshot.db_snapshot_arn
  s3_bucket_name         = var.rds_export_s3_bucket
  iam_role_arn           = var.rds_export_role_arn
  kms_key_id             = var.rds_export_kms_key_arn
  s3_prefix              = "${var.env}/automated/"

  lifecycle {
    ignore_changes = [export_task_identifier]
    create_before_destroy = false
  }
}