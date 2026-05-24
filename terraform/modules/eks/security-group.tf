resource "aws_security_group" "eks_node" {
  description = "Security group for EKS Nodes"
  name = "${var.app}-${var.env}-eks-security_group"
  vpc_id = aws_vpc.main_vpc.id
  tags = {  
    resource = "vpc"
  }

  lifecycle {
    ignore_changes = [
      tags,
      tags_all,
    ]
  }
}

resource "aws_vpc_security_group_ingress_rule" "eks_from_wireguard_server" {
    description = "Allow EKS control plane access from wireguard server"
    security_group_id = aws_eks_cluster.main_cluster.vpc_config[0].cluster_security_group_id
    from_port = 443
    to_port = 443
    ip_protocol = "tcp"
    referenced_security_group_id = var.wireguard_server_security_group_id
    tags = {
    resource = "vpc"
  }
}

resource "aws_vpc_security_group_ingress_rule" "control_plane_to_nodes" {
  description       = "Allow Cluster Control Plane to communicate with pods"
  security_group_id = var.eks_node_sg_id
  ip_protocol       = "-1" 
  referenced_security_group_id = aws_eks_cluster.main_cluster.vpc_config[0].cluster_security_group_id
}

resource "aws_vpc_security_group_ingress_rule" "nodes_internal" {
  description       = "Allow nodes to communicate with each other"
  security_group_id = var.eks_node_sg_id
  ip_protocol       = "-1" 
  referenced_security_group_id = var.eks_node_sg_id
}

resource "aws_vpc_security_group_ingress_rule" "external_nlb_to_node" {
  description       = "Allow External NLB to reach node port for HTTP"
  security_group_id = var.eks_node_sg_id
  
  from_port         = 30000
  to_port           = 32767
  ip_protocol       = "tcp"
  referenced_security_group_id = var.nlb_external_security_group_id
}

resource "aws_vpc_security_group_ingress_rule" "nlb_to_nodes_healthcheck" {
  description       = "Allow NLB to reach node port for Istio health check"
  security_group_id = var.eks_node_sg_id 
  
  from_port         = 32319
  to_port           = 32319
  ip_protocol       = "tcp"
  referenced_security_group_id = var.nlb_external_security_group_id
}

resource "aws_vpc_security_group_egress_rule" "nodes_to_internet" {
  description       = "Allow nodes to reach AWS APIs and Internet"
  security_group_id = var.eks_node_sg_id
  
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
  
  tags = {
    Name = "node-egress-all"
  }
}