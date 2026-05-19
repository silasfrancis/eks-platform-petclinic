resource "aws_iam_role" "rds_enhanced_monitoring" {
  count = local.is_prod ? 1 : 0

  name = "${var.env}-${var.app}-rds-enhanced-monitoring-role"

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

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  count = local.is_prod ? 1 : 0

  role       = aws_iam_role.rds_enhanced_monitoring[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}