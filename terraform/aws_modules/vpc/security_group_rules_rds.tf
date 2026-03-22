resource "aws_vpc_security_group_ingress_rule" "rds_ingress_rule_eks" {
    security_group_id = aws_security_group.rds.id
    from_port = 3306
    to_port = 3306
    ip_protocol = "tcp"
    referenced_security_group_id = aws_security_group.eks.id
    tags = {
    resource = "RDS"
    env = var.env
    app = var.application
    }
    depends_on = [ aws_security_group.rds ]
}

resource "aws_vpc_security_group_ingress_rule" "rds_ingress_rule_jump_host" {
    security_group_id = aws_security_group.rds.id
    from_port = 3306
    to_port = 3306
    ip_protocol = "tcp"
    referenced_security_group_id = aws_security_group.ec2.id
    tags = {
    resource = "RDS"
    env = var.env
    app = var.application
    }
    depends_on = [ aws_security_group.rds ]
}

resource "aws_vpc_security_group_egress_rule" "rds_egress_rule" {
  security_group_id = aws_security_group.rds.id
  ip_protocol = "-1"
  cidr_ipv4 = "0.0.0.0/0"
  tags = {
    resource = "RDS"
    env = var.env
    app = var.application
    }
  depends_on = [ aws_security_group.rds ]
}