resource "aws_vpc_security_group_ingress_rule" "rds_from_eks" {
    security_group_id = var.rds_security_group_id
    from_port = 3306
    to_port = 3306
    ip_protocol = "tcp"
    referenced_security_group_id = var.cluster_sg_id
    tags = {
    resource = "vpc"
    }
}

resource "aws_vpc_security_group_ingress_rule" "rds_from_jumphost" {
    security_group_id = var.rds_security_group_id
    from_port = 3306
    to_port = 3306
    ip_protocol = "tcp"
    referenced_security_group_id = var.ec2_security_group_id
    tags = {
      resource = "vpc"
      }
}

resource "aws_vpc_security_group_egress_rule" "rds_egress_rule" {
    security_group_id = var.rds_security_group_id
    ip_protocol = "-1"
    cidr_ipv4 = "0.0.0.0/0"
    tags = {
      resource = "vpc"
      }
}