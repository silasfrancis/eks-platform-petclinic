resource "aws_eks_node_group" "karpenter_bootstrap" {
  cluster_name    = aws_eks_cluster.main_cluster.name
  node_group_name = "${var.env}-${var.app}-karpenter-bootstrap"
  node_role_arn   = var.node_role_arn
  subnet_ids      = var.subnet_ids_node_group
  ami_type        = "CUSTOM"

  launch_template {
    id      = aws_launch_template.eks_nodes.id
    version = aws_launch_template.eks_nodes.default_version
  }

  scaling_config {
    desired_size = 1
    max_size     = 1
    min_size     = 1
  }

  capacity_type = "ON_DEMAND"

  taint {
    key    = "CriticalAddonsOnly"
    value  = "true"
    effect = "NO_SCHEDULE"
  }

  labels = {
    "node-type" = "karpenter-bootstrap"
  }

  timeouts {
    create = "20m"
    update = "20m"
    delete = "20m"
  }

  tags = {
    resource = "eks"
  }

  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }
}