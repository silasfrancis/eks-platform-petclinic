resource "aws_eks_access_entry" "jumphost_entry" {
  cluster_name  = aws_eks_cluster.main_cluster.name
  principal_arn = var.jumphost_ec2_role_arn
  type          = "STANDARD"

  depends_on = [aws_eks_cluster.main_cluster]
}

resource "aws_eks_access_policy_association" "jumphost_entry" {
  cluster_name  = aws_eks_cluster.main_cluster.name
  principal_arn = var.jumphost_ec2_role_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.jumphost_entry]
}

data "aws_iam_role" "eks_admin" {
  name = "EKSAdminRole"
}

resource "aws_eks_access_entry" "eks_admin" {
  cluster_name  = aws_eks_cluster.main_cluster.name
  principal_arn = data.aws_iam_role.eks_admin.arn
  type          = "STANDARD"

  depends_on = [aws_eks_cluster.main_cluster]
}

resource "aws_eks_access_policy_association" "eks_admin" {
  cluster_name  = aws_eks_cluster.main_cluster.name
  principal_arn = data.aws_iam_role.eks_admin.arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.eks_admin]
}