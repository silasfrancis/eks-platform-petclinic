# Karpenter Bootstrap Node Group
#
# A small, fixed-size (1 node) self-managed node group that runs ONLY
# Karpenter and other critical cluster add-ons (CoreDNS, kube-proxy, etc).
# All other workloads are scaled by Karpenter-managed nodes. The
# CriticalAddonsOnly taint keeps regular application pods off this node.
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
    desired_size = 2
    max_size     = 2
    min_size     = 1
  }

  update_config {
<<<<<<< HEAD
    max_unavailable = 1
=======
    max_unavailable = 1 
>>>>>>> 50dced335248a395d93e0ace9ab7a818ffafb886
  }

  capacity_type = "ON_DEMAND"

  # Repels normal workloads — only pods tolerating CriticalAddonsOnly
  # (Karpenter, CoreDNS, etc.) get scheduled here
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

<<<<<<< HEAD
  depends_on = [
    aws_iam_role.node_role
  ]

  # desired_size may be changed manually/by autoscaling outside Terraform 
  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }
=======
  # lifecycle {
  #   ignore_changes = [scaling_config[0].desired_size]
  # }
>>>>>>> 50dced335248a395d93e0ace9ab7a818ffafb886
}

# Tags the cluster's private subnets so Karpenter can auto-discover them
# for launching new nodes
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

# Tags the EKS node security group so Karpenter can auto-discover it and
# attach it to nodes it launches
resource "aws_ec2_tag" "karpenter_sg" {
  resource_id = aws_security_group.eks_node.id
  key   = "karpenter.sh/discovery"
  value = aws_eks_cluster.main_cluster.name

  lifecycle {
    ignore_changes = [value]
  }
}