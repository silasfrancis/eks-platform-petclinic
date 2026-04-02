resource "aws_vpc_security_group_ingress_rule" "wireguard_ingress_rule" {
  description = "Allow inbound traffic from WireGuard to EC2"
  security_group_id = var.ec2_security_group_id
  from_port = 51820
  to_port = 51820
  ip_protocol = "udp"
  cidr_ipv4 = "0.0.0.0/0"
  tags = {
  resource = "vpc"
  }
}

resource "aws_vpc_security_group_egress_rule" "ec2_egress_rule" {
  description = "Allow outbound traffic from EC2 to the internet"
  security_group_id = var.ec2_security_group_id
  from_port = 443
  to_port = 443
  ip_protocol = "tcp"
  cidr_ipv4   = "0.0.0.0/0"
  tags = {
  resource = "vpc"
  }
}
resource "aws_vpc_security_group_egress_rule" "ec2_to_rds" {
  description = "Allow outbound traffic from EC2 to RDS"
  security_group_id = var.ec2_security_group_id
  from_port = 3306
  to_port = 3306
  ip_protocol = "tcp"
  cidr_ipv4   = "0.0.0.0/0"
  tags = { 
    resource = "vpc" 
  }
}