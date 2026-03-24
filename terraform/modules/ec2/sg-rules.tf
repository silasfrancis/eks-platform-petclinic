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