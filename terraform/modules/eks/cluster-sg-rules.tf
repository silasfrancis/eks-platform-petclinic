resource "aws_vpc_security_group_ingress_rule" "eks_from_wireguard_server" {
    description = "Allow EKS control plane access from wireguard server"
    security_group_id = aws_eks_cluster.main_cluster.vpc_config[0].cluster_security_group_id
    from_port = 443
    to_port = 443
    ip_protocol = "tcp"
    referenced_security_group_id = var.wireguard_sg_id
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