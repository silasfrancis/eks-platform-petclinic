# resource "aws_eks_access_entry" "admin" {
#   cluster_name  = aws_eks_cluster.main_cluster.name
#   principal_arn = var.jumphost_ec2_role_arn
#   type          = "STANDARD"

#   depends_on = [aws_eks_cluster.main_cluster]
# }

# resource "aws_eks_access_policy_association" "admin" {
#   cluster_name  = aws_eks_cluster.main_cluster.name
#   principal_arn = var.jumphost_ec2_role_arn
#   policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

#   access_scope {
#     type = "cluster"
#   }

#   depends_on = [aws_eks_access_entry.admin]
# }