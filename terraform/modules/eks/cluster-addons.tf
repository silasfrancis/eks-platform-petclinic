data "aws_eks_addon_version" "vpc_cni" {
  addon_name         = "vpc-cni"
  kubernetes_version = aws_eks_cluster.main_cluster.version
  most_recent        = true
}

data "aws_eks_addon_version" "coredns" {
  addon_name         = "coredns"
  kubernetes_version = aws_eks_cluster.main_cluster.version
  most_recent        = true
}

data "aws_eks_addon_version" "kube_proxy" {
  addon_name         = "kube-proxy"
  kubernetes_version = aws_eks_cluster.main_cluster.version
  most_recent        = true
}

data "aws_eks_addon_version" "pod_identity" {
  addon_name         = "eks-pod-identity-agent"
  kubernetes_version = aws_eks_cluster.main_cluster.version
  most_recent        = true
}

resource "aws_eks_addon" "vpc_cni" {
  cluster_name = aws_eks_cluster.main_cluster.name
  addon_name   = "vpc-cni"

  addon_version = data.aws_eks_addon_version.vpc_cni.version

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"

  configuration_values = jsonencode({
    env = {
      ENABLE_PREFIX_DELEGATION = "true"
      WARM_PREFIX_TARGET       = "1"
      NETWORK_POLICY_ENFORCEMENT = "false"
      AWS_VPC_K8S_CNI_EXTERNALSNAT = "true"
    }
  })

  service_account_role_arn = aws_iam_role.vpc_cni.arn

  tags = {
    resource    = "eks-addon-vpc-cni"
  }

  depends_on = [aws_eks_cluster.main_cluster]

  lifecycle {
    ignore_changes = [
      addon_version    
    ]
  }
}

resource "aws_eks_addon" "coredns" {
  cluster_name                = aws_eks_cluster.main_cluster.name
  addon_name                  = "coredns"
  addon_version               = data.aws_eks_addon_version.coredns.version
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"

  depends_on = [
    aws_eks_cluster.main_cluster,
    aws_eks_node_group.cluster_node_group 
  ]

  lifecycle {
    ignore_changes = [addon_version]
  }
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name                = aws_eks_cluster.main_cluster.name
  addon_name                  = "kube-proxy"
  addon_version               = data.aws_eks_addon_version.kube_proxy.version
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"

  depends_on = [aws_eks_cluster.main_cluster]

  lifecycle {
    ignore_changes = [addon_version]
  }
}

resource "aws_eks_addon" "pod_identity" {
  cluster_name                = aws_eks_cluster.main_cluster.name
  addon_name                  = "eks-pod-identity-agent"
  addon_version               = data.aws_eks_addon_version.pod_identity.version
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"

  depends_on = [
    aws_eks_cluster.main_cluster,
    aws_eks_node_group.cluster_node_group
  ]

  lifecycle {
    ignore_changes = [addon_version]
  }
}

