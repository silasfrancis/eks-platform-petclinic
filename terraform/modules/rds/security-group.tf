resource "aws_security_group" "rds" {
  description = "Security group for RDS instances"
  name = "${var.app}-${var.env}-rds-security_group"
  vpc_id = var.vpc_id
  tags = var.extended_tags

  lifecycle {
    ignore_changes = [
      tags,
      tags_all,
    ]
  }
}

resource "aws_vpc_security_group_ingress_rule" "rds_from_eks_nodes" {
    security_group_id = aws_security_group.rds.id 
    from_port = 3306
    to_port = 3306
    ip_protocol = "tcp"
    referenced_security_group_id = var.eks_node_sg_id
}

resource "aws_vpc_security_group_ingress_rule" "rds_from_wireguard_server" {
    security_group_id = aws_security_group.rds.id
    from_port = 3306
    to_port = 3306
    ip_protocol = "tcp"
    referenced_security_group_id = var.wireguard_sg_id
}

resource "aws_vpc_security_group_egress_rule" "rds_egress_rule" {
    security_group_id = aws_security_group.rds.id
    ip_protocol = "-1"
    cidr_ipv4 = "0.0.0.0/0"
}