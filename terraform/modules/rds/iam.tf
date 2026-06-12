# RDS Enhanced Monitoring IAM Role
#
# IAM role allowing the RDS monitoring service to push enhanced monitoring
# metrics (OS-level CPU, memory, disk I/O, etc.) to CloudWatch. Only created
# in prod (count = local.is_prod ? 1 : 0), matching the monitoring_interval
# setting on the DB instance which is disabled (0) in dev.


# Role assumable by the RDS monitoring service principal
resource "aws_iam_role" "rds_enhanced_monitoring" {
  count = local.is_prod ? 1 : 0

  name = "${var.app}-${var.env}-rds-enhanced-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    resource = "iam"
  }
}

# Attach the AWS-managed policy granting permissions to publish enhanced
# monitoring metrics to CloudWatch
resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  count = local.is_prod ? 1 : 0

  role       = aws_iam_role.rds_enhanced_monitoring[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}