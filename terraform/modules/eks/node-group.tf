resource "aws_eks_node_group" "cluster_node_group" {
  cluster_name    = aws_eks_cluster.main_cluster.name
  node_group_name = "${var.env}-${var.app}-node-group"
  node_role_arn   = var.node_role_arn
  subnet_ids      = var.subnet_ids_node_group
  ami_type        = "CUSTOM"

  launch_template {
    id      = aws_launch_template.eks_nodes.id
    version = aws_launch_template.eks_nodes.default_version
  }

  scaling_config {
    desired_size = var.node_scaling_config.desired_size
    max_size     = var.node_scaling_config.max_size
    min_size     = var.node_scaling_config.min_size
  }

  update_config {
    max_unavailable_percentage = 33
  }

  capacity_type = "ON_DEMAND"

  tags = {
    resource = "eks"
    "k8s.io/cluster-autoscaler/enabled"                              = "true"
    "k8s.io/cluster-autoscaler/${aws_eks_cluster.main_cluster.name}" = "owned"
  }

  timeouts {
    create = "20m"
    update = "20m"
    delete = "20m"
  }

  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }
}