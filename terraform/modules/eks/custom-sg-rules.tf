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

resource "aws_vpc_security_group_ingress_rule" "nlb_to_node" {
    description = "Allow NLB to reach node port for HTTP"
    security_group_id = aws_eks_cluster.main_cluster.vpc_config[0].cluster_security_group_id
    from_port = 30000
    to_port = 32767
    ip_protocol = "tcp"
    referenced_security_group_id = var.nlb_security_group_id
    tags = {
    resource = "vpc"
  }
}

resource "aws_vpc_security_group_ingress_rule" "nlb_to_nodes_healthcheck" {
    description = "Allow NLB to reach node port for Istio health check"
    security_group_id = aws_eks_cluster.main_cluster.vpc_config[0].cluster_security_group_id
    from_port = 32319
    to_port = 32319
    ip_protocol = "tcp"
    referenced_security_group_id = var.nlb_security_group_id
    tags = {
    resource = "vpc"
  }
}
    