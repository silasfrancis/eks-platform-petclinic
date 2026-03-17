resource "aws_db_subnet_group" "main" {
  name       = "${var.env}-rds-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = { Name = "${var.env}-rds-subnet-group" }
}

resource "aws_db_parameter_group" "mysql" {
  name   = "${var.env}-mysql-params"
  family = "mysql8.0"

  parameter {
    name  = "slow_query_log"
    value = "1"
  }

  parameter {
    name  = "long_query_time"
    value = "2"
  }

  parameter {
    name  = "max_execution_time"
    value = "30000"  
  }

  parameter {
    name  = "log_output"
    value = "FILE"
  }
}

resource "aws_db_instance" "main" {
  identifier        = "${var.env}-mysql"
  engine            = "mysql"
  engine_version    = var.mysql_version        
  instance_class    = var.db_instance_class   
  allocated_storage = var.allocated_storage    
  storage_type      = "gp3"

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password  

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = var.rds_security_group_id
  parameter_group_name   = aws_db_parameter_group.mysql.name

  storage_encrypted = true
  kms_key_id        = var.rds_data_kms_arn

  multi_az = true

  backup_retention_period   = 30        
  backup_window             = "02:00-03:00"
  maintenance_window        = "Sun:04:00-Sun:05:00"
  copy_tags_to_snapshot     = true
  delete_automated_backups  = false

  skip_final_snapshot       = false
  final_snapshot_identifier = "${var.env}-mysql-final-snapshot"

  monitoring_interval             = 60   
  monitoring_role_arn             = var.rds_monitoring_role_arn
  enabled_cloudwatch_logs_exports = ["audit", "error", "general", "slowquery"]
  performance_insights_enabled    = true
  performance_insights_kms_key_id = var.rds_data_kms_arn
  performance_insights_retention_period = 7

  deletion_protection = true
  publicly_accessible = false

  auto_minor_version_upgrade = true

  tags = { Name = "${var.env}-mysql" }

  lifecycle {
    ignore_changes = [password]  
  }
}

resource "aws_db_snapshot" "pre_deploy" {
  db_instance_identifier = aws_db_instance.main.identifier
  db_snapshot_identifier = "${var.env}-mysql-pre-deploy-${formatdate("YYYY-MM-DD", timestamp())}"

  tags = { Purpose = "pre-deployment snapshot" }

  lifecycle {
    ignore_changes = [db_snapshot_identifier] 
  }
}

# data "aws_db_snapshot" "latest_db_snapshot" {
#   db_instance_identifier = aws_db_instance.main.identifier
#   snapshot_type          = "automated"
#   most_recent            = true
# }

# resource "aws_rds_export_task" "latest" {
#   count = var.run_snapshot_export ? 1 : 0
  
#   export_task_identifier = "${var.env}-mysql-export-${formatdate("YYYYMMDDhhmmss", timestamp())}"
#   source_arn             = data.aws_db_snapshot.latest_db_snapshot.db_snapshot_arn
#   s3_bucket_name         = var.rds_export_s3_bucket
#   iam_role_arn           = var.rds_export_role_arn
#   kms_key_id             = var.rds_export_kms_key_arn
#   s3_prefix              = "${var.env}/automated/"

#   lifecycle {
#     ignore_changes = [export_task_identifier]
#     create_before_destroy = false
#   }
# }