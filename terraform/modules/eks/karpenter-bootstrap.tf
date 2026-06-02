resource "aws_eks_node_group" "karpenter_bootstrap" {
  cluster_name    = aws_eks_cluster.main_cluster.name
  node_group_name = "${var.app}-${var.env}-karpenter-bootstrap"
  node_role_arn   = aws_iam_role.node_role.arn
  subnet_ids      = var.private_subnets
  ami_type        = "CUSTOM"

  launch_template {
    id      = aws_launch_template.eks_nodes.id
    version = "$Default"
  }

  scaling_config {
    desired_size = 1
    max_size     = 1
    min_size     = 1
  }

  update_config {
    max_unavailable = 1
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
    create = "30m"
    update = "60m"
    delete = "30m"
  }

  tags = merge(
      {
        Name = "${var.app}-${var.env}-karpenter-bootstrap"
      },
      var.extended_tags
    )

  depends_on = [
    aws_iam_role.node_role
  ]

  # lifecycle {
  #   ignore_changes = [scaling_config[0].desired_size]
  # }
}

resource "aws_ec2_tag" "karpenter_subnets" {
  for_each = {
    for idx, subnet_id in var.private_subnets :
    idx => subnet_id
  }

  resource_id = each.value
  key         = "karpenter.sh/discovery"
  value       = aws_eks_cluster.main_cluster.name

  lifecycle {
    ignore_changes = [value]
  }
}

resource "aws_ec2_tag" "karpenter_sg" {
  resource_id = aws_security_group.eks_node.id
  key   = "karpenter.sh/discovery"
  value = aws_eks_cluster.main_cluster.name

  lifecycle {
    ignore_changes = [value]
  }
}