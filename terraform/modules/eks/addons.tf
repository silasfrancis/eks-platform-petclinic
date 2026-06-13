# EKS Managed Add-ons
#
# Installs the core EKS-managed add-ons (VPC CNI, CoreDNS, kube-proxy, Pod
# Identity Agent, EBS CSI Driver), always pinned to the latest version
# compatible with the cluster's Kubernetes version at apply time, but with
# addon_version changes ignored afterward so AWS-driven version bumps don't
# cause unwanted diffs. VPC CNI and EBS CSI use IRSA roles for AWS API access;
# the others are pure cluster add-ons with no extra permissions.


# Look up the latest available version of each add-on for this cluster's k8s version
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

data "aws_eks_addon_version" "ebs_csi" {
  addon_name         = "aws-ebs-csi-driver"
  kubernetes_version = aws_eks_cluster.main_cluster.version
  most_recent        = true
}

# VPC CNI — pod networking. Uses IRSA for AWS API access and enables
# NetworkPolicy enforcement plus IP prefix delegation to increase pod density
# per node (with SNAT for external traffic)
resource "aws_eks_addon" "vpc_cni" {
  cluster_name = aws_eks_cluster.main_cluster.name
  addon_name   = "vpc-cni"
  addon_version = data.aws_eks_addon_version.vpc_cni.version
  service_account_role_arn = aws_iam_role.irsa["vpcCni"].arn
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"

  configuration_values = jsonencode({
    enableNetworkPolicy = "true"
    env = {
      ENABLE_PREFIX_DELEGATION = "true"
      WARM_PREFIX_TARGET       = "1"
      AWS_VPC_K8S_CNI_EXTERNALSNAT = "true"
    }
  })
  
  depends_on = [
    aws_eks_cluster.main_cluster,
<<<<<<< HEAD
=======
    aws_eks_node_group.karpenter_bootstrap,
>>>>>>> 50dced335248a395d93e0ace9ab7a818ffafb886
    aws_iam_role.irsa["vpcCni"]
  ]
  lifecycle {
    ignore_changes = [
      addon_version    
    ]
  }
}

# CoreDNS — in-cluster DNS resolution. Requires the bootstrap node group to
# exist since it needs a node to schedule onto
resource "aws_eks_addon" "coredns" {
  cluster_name                = aws_eks_cluster.main_cluster.name
  addon_name                  = "coredns"
  addon_version               = data.aws_eks_addon_version.coredns.version
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"

  depends_on = [
    aws_eks_cluster.main_cluster,
    aws_eks_node_group.karpenter_bootstrap
  ]

  lifecycle {
    ignore_changes = [addon_version]
  }
}

# kube-proxy — maintains network rules for Service routing on each node
resource "aws_eks_addon" "kube_proxy" {
  cluster_name                = aws_eks_cluster.main_cluster.name
  addon_name                  = "kube-proxy"
  addon_version               = data.aws_eks_addon_version.kube_proxy.version
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"

  depends_on = [
    aws_eks_cluster.main_cluster,
    aws_eks_node_group.karpenter_bootstrap
  ]
  lifecycle {
    ignore_changes = [addon_version]
  }
}

# EKS Pod Identity Agent — alternative to IRSA for assigning AWS permissions
# to pods via pod identity associations
resource "aws_eks_addon" "pod_identity" {
  cluster_name                = aws_eks_cluster.main_cluster.name
  addon_name                  = "eks-pod-identity-agent"
  addon_version               = data.aws_eks_addon_version.pod_identity.version
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"

  depends_on = [
    aws_eks_cluster.main_cluster,
    aws_eks_node_group.karpenter_bootstrap
  ]

  lifecycle {
    ignore_changes = [addon_version]
  }
}

# EBS CSI Driver — provisions/attaches EBS volumes for PersistentVolumes.
# Uses IRSA for the AWS API calls needed to manage volumes
resource "aws_eks_addon" "ebs_csi" {
  cluster_name             = aws_eks_cluster.main_cluster.name
  addon_name               = "aws-ebs-csi-driver"
  addon_version            = data.aws_eks_addon_version.ebs_csi.version
  service_account_role_arn = aws_iam_role.irsa["ebsCsi"].arn
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"

  depends_on = [
    aws_eks_cluster.main_cluster,
<<<<<<< HEAD
=======
    aws_eks_node_group.karpenter_bootstrap,
>>>>>>> 50dced335248a395d93e0ace9ab7a818ffafb886
    aws_iam_role.irsa["ebsCsi"]
  ]
  lifecycle {
    ignore_changes = [addon_version]
  }
}