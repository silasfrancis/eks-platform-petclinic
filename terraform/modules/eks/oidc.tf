# EKS OIDC Provider
#
# Registers the EKS cluster's OIDC issuer as an IAM identity provider, which
# is the foundation for IRSA (IAM Roles for Service Accounts) — without this,
# Kubernetes ServiceAccounts cannot assume IAM roles via
# sts:AssumeRoleWithWebIdentity.


# Fetches the TLS certificate for the cluster's OIDC issuer to obtain its
# thumbprint, required when registering the OIDC provider with IAM
data "tls_certificate" "eks" {
  url = aws_eks_cluster.main_cluster.identity[0].oidc[0].issuer
  depends_on = [ aws_eks_cluster.main_cluster ]
}

# Registers the cluster's OIDC issuer as a trusted identity provider, scoped
# to the "sts.amazonaws.com" audience used by IRSA
resource "aws_iam_openid_connect_provider" "eks" {
  url             = aws_eks_cluster.main_cluster.identity[0].oidc[0].issuer
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  depends_on = [ data.tls_certificate.eks ]
}