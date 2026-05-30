resource "aws_db_subnet_group" "main" {
  name       = "${var.app}-${var.env}-rds-subnet-group"
  subnet_ids = var.data_subnet_ids

  tags = var.extended_tags
}

resource "aws_db_parameter_group" "mysql" {
  name   = "${var.app}-${var.env}-mysql-params"
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
  
  tags = {
    resource = "rds"
  }
}

locals {
  is_prod = var.env == "production"

  # Backup retention — 7 days prod, 1 day dev
  backup_retention = local.is_prod ? 7 : 1

  # Performance Insights retention for 7 days is free tier
  pi_retention = 7

  # Enhanced monitoring interval
  # 60s prod for full OS metrics, 0 disables it in dev to avoid IAM role requirement
  monitoring_interval = local.is_prod ? 60 : 0
}

resource "aws_db_instance" "main" {
  identifier     = "${var.app}-${var.env}-mysql"
  engine         = "mysql"
  engine_version = var.mysql_version

  instance_class    = var.db_instance_class
  allocated_storage = var.allocated_storage
  storage_type      = "gp3"

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  parameter_group_name   = aws_db_parameter_group.mysql.name

  storage_encrypted = true
  kms_key_id        = var.data_storage_kms_key_arn

  # Multi-AZ only in prod
  multi_az = local.is_prod

  # Backup retention — 1 day dev, 7 days prod
  backup_retention_period  = local.backup_retention
  backup_window            = "02:00-03:00"
  maintenance_window       = "Sun:04:00-Sun:05:00"
  copy_tags_to_snapshot    = true
  delete_automated_backups = false

  # Always take a final snapshot before destroy in prod
  skip_final_snapshot       = !local.is_prod
  final_snapshot_identifier = local.is_prod ? "${var.app}-${var.env}-mysql-final-snapshot" : null

  # Enhanced monitoring — disabled in dev and enabled in prod for OS-level metrics (CPU steal, memory, disk I/O)
  monitoring_interval = local.monitoring_interval
  monitoring_role_arn = local.is_prod ? aws_iam_role.rds_enhanced_monitoring[0].arn : null

  enabled_cloudwatch_logs_exports = ["error", "slowquery"]

  # Performance Insights — free at 7 days, enable in both environments
  performance_insights_enabled          = local.is_prod 
  performance_insights_kms_key_id       = local.is_prod ? var.data_storage_kms_key_arn : null
  performance_insights_retention_period = local.is_prod ? local.pi_retention : 0

  deletion_protection = local.is_prod

  publicly_accessible        = false
  auto_minor_version_upgrade = true

  tags = var.extended_tags

  lifecycle {
    ignore_changes = [password]
  }
}

resource "aws_db_snapshot" "pre_deploy" {
  db_instance_identifier = aws_db_instance.main.identifier
  db_snapshot_identifier = "${var.app}-${var.env}-mysql-pre-deploy-${formatdate("YYYY-MM-DD", timestamp())}"

  tags = var.extended_tags

  lifecycle {
    ignore_changes = [db_snapshot_identifier] 
  }
}
