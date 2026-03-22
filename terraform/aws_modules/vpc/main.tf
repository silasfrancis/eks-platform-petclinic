resource "aws_vpc" "main_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    env = var.env
    app = var.application
  }
}

resource "aws_flow_log" "main_vpc_flow_log" {
  iam_role_arn    = var.vpc_flow_log_role_arn
  log_destination = var.vpc_flow_log_destination
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.main_vpc.id
  tags = {
    env = var.env
    app = var.application
  }
}

data "aws_availability_zones" "available"{
    state = "available"
}