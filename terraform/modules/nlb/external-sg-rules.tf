resource "aws_vpc_security_group_ingress_rule" "allow_http_external" {
  description       = "Allow HTTP traffic from internet"
  security_group_id = var.nlb_external_sg_id
  from_port = 80
  to_port = 80
  ip_protocol = "tcp"
  cidr_ipv4 = "0.0.0.0/0"
  tags = {
    resource = "vpc"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_https_external" {
  description       = "Allow HTTPS traffic from internet"
  security_group_id = var.nlb_external_sg_id
  from_port = 443
  to_port = 443
  ip_protocol = "tcp"
  cidr_ipv4 = "0.0.0.0/0"
    tags = {
    resource = "vpc"
  }
}

resource "aws_vpc_security_group_egress_rule" "nlb_egress_external" {
  description       = "Allow all outbound traffic to internet"
  security_group_id = var.nlb_external_sg_id
  ip_protocol = "-1"
  cidr_ipv4 = "0.0.0.0/0"
    tags = {
    resource = "vpc"
  }
}