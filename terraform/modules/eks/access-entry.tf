# EKS Access Entry: Cluster Admin
#
# Grants the "EKSAdminRole" IAM role full cluster-admin access via the EKS
# Access Entries API (API_AND_CONFIG_MAP auth mode), avoiding the need to
# manage the aws-auth ConfigMap manually.


# IAM role to be granted cluster-admin access
data "aws_iam_role" "eks_admin" {
  name = "EKSAdminRole"
}

# Registers the role as a recognized principal for this cluster
resource "aws_eks_access_entry" "eks_admin" {
  cluster_name  = aws_eks_cluster.main_cluster.name
  principal_arn = data.aws_iam_role.eks_admin.arn
  type          = "STANDARD"

}

# Grants the role the AWS-managed cluster-admin policy, scoped to the whole
# cluster
resource "aws_eks_access_policy_association" "eks_admin" {
  cluster_name  = aws_eks_cluster.main_cluster.name
  principal_arn = data.aws_iam_role.eks_admin.arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.eks_admin]
}