resource "aws_iam_role" "cluster_role" {
  name = "${var.env}-${var.app}-cluster-role"
  assume_role_policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "eks.amazonaws.com"
            },
            "Action": [
                "sts:AssumeRole",
                "sts:TagSession"
            ]
        }
    ]
  })
  tags = {
    resource = "iam"
  }
}

resource "aws_iam_role" "node_role" {
  name = "${var.env}-${var.app}-node-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
        {
            Action = "sts:AssumeRole"
            Effect = "Allow"
            Sid    = ""
            Principal = {
                Service = "ec2.amazonaws.com"
            }
        }
    ]
  })
  tags = {
    resource = "iam"
  }
}

resource "aws_iam_role" "wireguard_server_role" {
  name = "${var.env}-${var.app}-wireguard-server-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
        {
            Action = "sts:AssumeRole"
            Effect = "Allow"
            Sid    = ""
            Principal = {
                Service = "ec2.amazonaws.com"
            }
        }
    ]
  })
  tags = {
    resource = "iam"
  }
}

resource "aws_iam_role" "rds_export_role" {
  name = "${var.env}-${var.app}-rds-snapshot-export-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "export.rds.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
  tags = {
    resource = "iam"
  }
}

resource "aws_iam_role" "vpc_flow_logs_role" {
  name = "${var.env}-${var.app}-vpc-flow-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
  tags = {
    resource = "iam"
  }
}

resource "aws_iam_role" "rds_enhanced_monitoring" {
  name = "${var.env}-${var.app}-rds-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { 
        Service = "monitoring.rds.amazonaws.com" 
      }
      Action    = "sts:AssumeRole"
    }]
  })
  tags = {
    resource = "iam"
  }
}

resource "aws_iam_role" "lambda_backup" {
  name = "${var.env}-${var.app}-lambda-backup-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
  tags = {
    resource = "iam"
  }
}

resource "aws_iam_role" "lambda_notification" {
  name = "${var.env}-${var.app}-lambda-notification-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
  tags = {
    resource = "iam"
  }
}