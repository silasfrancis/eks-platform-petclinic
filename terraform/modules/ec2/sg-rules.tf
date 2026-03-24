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
  security_group_id            = aws_security_group.ec2.id
  referenced_security_group_id = aws_security_group.rds.id
  from_port                    = 3306
  to_port                      = 3306
  ip_protocol                  = "tcp"
  description                  = "Allow outbound MySQL to RDS"
  tags = { 
    resource = "vpc" 
  }
}