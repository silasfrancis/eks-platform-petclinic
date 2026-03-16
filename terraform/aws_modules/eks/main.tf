resource "aws_eks_cluster" "main_cluster" {
  name     = "${var.env}-eks-cluster"
  version  = var.k8_version
  role_arn = var.cluster_role_arn

  vpc_config {
    subnet_ids              = var.subnet_ids_for_cluster
    security_group_ids      = var.security_group_id
    endpoint_private_access = true
    endpoint_public_access  = false 
    }

  encryption_config {
    resources = ["secrets"]
    provider {
      key_arn = var.kms_eks_secrets_arn 
    }
  }

  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

}

resource "aws_eks_node_group" "cluster_node_group" {
  cluster_name = aws_eks_cluster.main_cluster.name
  node_group_name = "${var.env}-node-group"
  node_role_arn = var.node_role_arn
  subnet_ids = var.subnet_ids_node_group
  scaling_config {
    desired_size = var.node_scaling_config.desired_size
    max_size = var.node_scaling_config.max_size
    min_size = var.node_scaling_config.min_size
  }
  disk_size = var.disk_size
  instance_types = var.instance_types
}