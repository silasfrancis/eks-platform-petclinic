resource "aws_vpc_security_group_ingress_rule" "eks_from_jumphost" {
    description = "Allow EKS access from jumphost"
    security_group_id = var.eks_security_group_id
    from_port = 443
    to_port = 443
    ip_protocol = "tcp"
    referenced_security_group_id = var.ec2_security_group_id
    tags = {
    resource = "vpc"
  }
}