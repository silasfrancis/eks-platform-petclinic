resource "aws_vpc_security_group_ingress_rule" "eks_ingress_rule_alb_http" {
    security_group_id = aws_security_group.eks.id
    from_port = 80
    to_port = 80
    ip_protocol = "tcp"
    referenced_security_group_id = aws_security_group.alb.id
    tags = {
    resource = "EKS"
    env = var.env
    app = var.application
  }
  depends_on = [ aws_security_group.eks, aws_security_group.alb ]
}

resource "aws_vpc_security_group_ingress_rule" "eks_ingress_rule_alb_https" {
    security_group_id = aws_security_group.eks.id
    from_port = 443
    to_port = 443
    ip_protocol = "tcp"
    referenced_security_group_id = aws_security_group.alb.id
    tags = {
    resource = "EKS"
    env = var.env
    app = var.application
  }
  depends_on = [ aws_security_group.eks, aws_security_group.alb ]
}

resource "aws_vpc_security_group_ingress_rule" "eks_ingress_rule_jump_host" {
    security_group_id = aws_security_group.eks.id
    from_port = 443
    to_port = 443
    ip_protocol = "tcp"
    referenced_security_group_id = aws_security_group.ec2.id
    tags = {
    resource = "EKS"
    env = var.env
    app = var.application
  }
  depends_on = [ aws_security_group.eks, aws_security_group.ec2 ]
}

resource "aws_vpc_security_group_egress_rule" "ec2_egress_rule" {
  security_group_id = aws_security_group.ec2.id
  ip_protocol = "-1"
  cidr_ipv4 = "0.0.0.0/0"
  tags = {
    resource = "EKS"
    env = var.env
    app = var.application
  }
  depends_on = [ aws_security_group.ec2 ]
}